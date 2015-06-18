
resource "aws_vpc" "main" {
    cidr_block = "10.2.0.0/16"
    enable_dns_hostnames = true

    tags {
        Name = "${var.user}-shard-vpc"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "main" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.2.0.0/24"
    availability_zone = "us-east-1a"

    tags {
        Name = "${var.user}-single-subnet"
    }
}

resource "aws_route_table" "r" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    tags {
        Name = "${var.user}-dsi-routing"
    }
}

resource "aws_route_table_association" "a" {
    subnet_id = "${aws_subnet.main.id}"
    route_table_id = "${aws_route_table.r.id}"
}

resource "aws_security_group" "dsi-default" {
    name = "${var.user}-shard-default"
    description = "${var.user} config for single cluster"
    vpc_id = "${aws_vpc.main.id}"
    
    # SSH access from anywhere
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # mongodb access from VPC
    ingress {
        from_port = 27017
        to_port = 27019
        protocol = "tcp"
        cidr_blocks = ["10.2.0.0/16"]
    }

    # allow all egress
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_instance" "member" {
    # Amazon Linux AMI 2015.03 (HVM), SSD Volume Type - ami-1ecae776
    ami = "ami-1ecae776"

    instance_type = "${var.secondary_type}"

    count = "${var.count}"

    subnet_id = "${aws_subnet.main.id}"
    private_ip = "${lookup(var.instance_ips, count.index)}"

    connection {
        # The default username for our AMI
        user = "ec2-user"

        # The path to your keyfile
        key_file = "${var.key_path}"
    }

    security_groups = ["${aws_security_group.dsi-default.id}"]
    availability_zone = "us-east-1a"
    placement_group = "${var.user}-dsi-single-perf"
    tenancy = "dedicated"

    key_name = "${var.key_name}"
    tags = {
        Name = "${var.user}-single-member-${count.index}"
        owner = "${var.owner}"
        expire-on = "2015-07-15"
    }

    ephemeral_block_device {
        device_name = "/dev/sdc"
        virtual_name = "ephemeral0"
        # delete_on_termination = true
    }
    ephemeral_block_device {
        device_name = "/dev/sdd"
        virtual_name = "ephemeral1"
        # delete_on_termination = true
    }

    associate_public_ip_address = 1

    # We run a remote provisioner on the instance after creating it.
    provisioner "remote-exec" {
        inline = [
            "sudo yum -y update",
            "sudo yum -y install tmux git wget sysstat dstat perf",
            "wget --no-check-certificate https://raw.githubusercontent.com/rzh/dotfiles/no_ycm/bootstrap.sh -O - | sh",
            "curl https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${var.mongoversion}.tgz | tar zxv; mv mongodb-linux-x86_64-${var.mongoversion} ${var.mongoversion}",
            "mkdir bin",
            "ln -s ~/${var.mongoversion}/bin/mongo ~/bin/mongo",
            "dev=/dev/xvdc; sudo umount $dev; sudo mkfs.ext4 -F $dev; sudo mount $dev",
            "sudo chmod 777 /media/ephemeral0",
            "sudo chown ec2-user /media/ephemeral0",
#            "sudo umount /dev/xvdd; sudo mkswap /dev/xvdd; sudo swapon /dev/xvdd",
            "dev=/dev/xvdd; dpath=/media/ephemeral1; sudo mkdir -p $dpath; sudo umount $dev; sudo mkfs.ext4 -F $dev; sudo mount $dev $dpath; ",
            "sudo chmod 777 /media/ephemeral1",
            "sudo chown ec2-user /media/ephemeral1",
            "ln -s /media/ephemeral0 ~/data",
            "ln -s /media/ephemeral1 ~/journal",
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled", 
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/defrag",
            "echo f | sudo tee /sys/class/net/eth0/queues/rx-0/rps_cpus",
            "echo f0 | sudo tee /sys/class/net/eth0/queues/tx-0/xps_cpus",
            "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmHUZLsuGvNUlCiaZ83jS9f49S0plAtCH19Z2iATOYPH1XE2T8ULcHdFX2GkYiaEqI+fCf1J1opif45sW/5yeDtIp4BfRAdOu2tOvkKvzlnGZndnLzFKuFfBPcysKyrGxkqBvdupOdUROiSIMwPcFgEzyLHk3pQ8lzURiJNtplQ82g3aDi4wneLDK+zuIVCl+QdP/jCc0kpYyrsWKSbxi0YrdpG3E25Q4Rn9uom58c66/3h6MVlk22w7/lMYXWc5fXmyMLwyv4KndH2u3lV45UAb6cuJ6vn6wowiD9N9J1GS57m8jAKaQC1ZVgcZBbDXMR8fbGdc9AH044JVtXe3lT shardtest@test.mongo' | tee -a ~/.ssh/authorized_keys",
            "rm -rf ~/.vim/bundle/YouCompleteMe/",
            "rm *.tgz",
            "rm *.rpm",
            "ls"
        ]
    }

    #provisioner "local-exec" {
    #    command = "echo ${join('\n', aws_instance.shardmember.*.public_ip)} >> pub_ip.txt; echo ${join('\n', aws_instance.shardmember.*.private_ip)} >> pri_ip.txt;"
    #}
}

resource "aws_instance" "master" {
    # Amazon Linux AMI 2015.03 (HVM), SSD Volume Type - ami-1ecae776
    ami = "ami-1ecae776"

    instance_type = "${var.primary_type}"

    subnet_id = "${aws_subnet.main.id}"
    private_ip = "${lookup(var.instance_ips, concat("master", count.index))}"
    count = "${var.mastercount}"

    connection {
        # The default username for our AMI
        user = "ec2-user"

        # The path to your keyfile
        key_file = "${var.key_path}"
    }

    security_groups = ["${aws_security_group.shard-default.id}"]
    availability_zone = "us-east-1a"
    placement_group = "${var.user}-shard-perf"
    tenancy = "dedicated"

    key_name = "${var.key_name}"
    tags = {
        Name = "${var.user}-shard-master-${count.index}"
        owner = "${var.owner}"
        expire-on = "2015-07-15"
    }

#    ephemeral_block_device. {
#        device_name = "/dev/sdc"
#        virtual_name = "ephemeral0"
#        delete_on_termination = true
#    }
#    ephemeral_block_device. {
#        device_name = "/dev/sdd"
#        virtual_name = "ephemeral1"
#        delete_on_termination = true
#    }

    associate_public_ip_address = 1

    # We run a remote provisioner on the instance after creating it.
    provisioner "remote-exec" {
        inline = [
#            "sudo yum -y update",
            "sudo yum -y install tmux git wget sysstat dstat perf",
            "wget --no-check-certificate https://raw.githubusercontent.com/rzh/dotfiles/no_ycm/bootstrap.sh -O - | sh",
            "curl https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${var.mongoversion}.tgz | tar zxv; mv mongodb-linux-x86_64-${var.mongoversion} ${var.mongoversion}",
            "mkdir bin",
            "ln -s ~/${var.mongoversion}/bin/mongo ~/bin/mongo",
            "wget --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jdk/7u71-b14/jdk-7u71-linux-x64.rpm; sudo rpm -i jdk-7u71-linux-x64.rpm;",
            "sudo /usr/sbin/alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_71/bin/java 20000",
            "wget --no-check-certificate http://central.maven.org/maven2/org/mongodb/mongo-java-driver/2.12.5/mongo-java-driver-2.12.5.jar",
            "wget --no-check-certificate http://central.maven.org/maven2/org/mongodb/mongo-java-driver/2.13.0/mongo-java-driver-2.13.0.jar",
            "echo 'export CLASSPATH=~/mongo-java-driver-2.12.5.jar:$CLASSPATH' >> ~/.bashrc",
            "git clone https://github.com/rzh/sysbench-mongodb.git",
            "git clone -b shard-test https://github.com/rzh/YCSB.git",
            "curl https://raw.githubusercontent.com/rzh/utils/master/mongodb/scripts/install_maven.sh | sudo bash",
#            "dev=/dev/xvdc; sudo umount $dev; sudo mkfs.ext4 -F $dev; sudo mount $dev",
#            "dev=/dev/xvdd; dpath=/media/ephemeral1; sudo mkdir -p $dpath; sudo umount $dev; sudo mkfs.ext4 -F $dev; sudo mount $dev $dpath",
#            "sudo chmod 777 /media/ephemeral0",
#            "sudo chown ec2-user /media/ephemeral0",
#            "ln -s /media/ephemeral0 ~/data",
#            "sudo chmod 777 /media/ephemeral1",
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled", 
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/defrag", 
            "echo f | sudo tee /sys/class/net/eth0/queues/rx-0/rps_cpus",
            "echo f0 | sudo tee /sys/class/net/eth0/queues/tx-0/xps_cpus",
            "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmHUZLsuGvNUlCiaZ83jS9f49S0plAtCH19Z2iATOYPH1XE2T8ULcHdFX2GkYiaEqI+fCf1J1opif45sW/5yeDtIp4BfRAdOu2tOvkKvzlnGZndnLzFKuFfBPcysKyrGxkqBvdupOdUROiSIMwPcFgEzyLHk3pQ8lzURiJNtplQ82g3aDi4wneLDK+zuIVCl+QdP/jCc0kpYyrsWKSbxi0YrdpG3E25Q4Rn9uom58c66/3h6MVlk22w7/lMYXWc5fXmyMLwyv4KndH2u3lV45UAb6cuJ6vn6wowiD9N9J1GS57m8jAKaQC1ZVgcZBbDXMR8fbGdc9AH044JVtXe3lT shardtest@test.mongo' | tee -a ~/.ssh/authorized_keys",
            "printf  '-----BEGIN RSA PRIVATE KEY-----\n MIIEowIBAAKCAQEAph1GS7LhrzVJQommfN40vX+PUtKZQLQh9fWdogEzmDx9VxNk\n /FC3B3RV9hpGImhKiPnwn9SdaKYn+ObFv+cng7SKeAX0QHTrtrTr5Cr85ZxmZ3Zy\n 8xSrhXwT3MrCsqxsZKgb3bqTnVETokiDMD3BYBM8ix5N6UPJc1EYiTbaZUPNoN2g\n 4uMJ3iwyvs7iFQpfkHT/4wnNJKWMq7Fikm8YtGK3aRtxNuUOEZ/bqJufHOuv94ej\n FZZNtsO/5TGF1nOX15sjC8Mr+Cp3R9rt5VeOVAG+nLier5+sKMIg/TfSdRkue5vI\n wCmkAtWVYHGQWw1zEfH2xnXPQB9OOCVbV3t5UwIDAQABAoIBAGYbQIZvYkIsYue/\n bNL8UzbYHeUvBny7PNTPMSHP00MUi4bmqQBfLOIsJFquM8YajRY9bCcSrd8Royhf\n 0dXv5F4Ur7ivEEA+nlUkSItr0R/iTx/xsx6v6e6XIi5pg9wIGGiW3OoiMXJVz9fE\n 8r7IdwDzUhfBfOqRfFah1o8hZIUxdmznHODMyCGhoAHukLNmht9z3sU0O6HxUHPC\n OiNfInc+HWig1UzOMIPh1l/I9tvTZFHSAG3SrJvy3zVBm2V4XxnhnVW+fY/GtWY/\n VfOvbB/M9bk7srIZMoLeSZjnUPNGWfGlTlgMH4I05NgaooaSsDoWwYAkTPTBLmVw\n 0ebkiUECgYEA2SwL4I7STM5kGtxlVdDLtchjDdhFdi8akeEVUZjWwe25k9x7G3Ob\n W2SGwnsZwtFKthETC+Bqn0k4U0rausuljn85Q1a8FJyd9/8l6yQOdPMrtuAWAiRx\n LirILpFn4sHyiH9h3Mel0xX/zAr3mVUlStlVyC25ZMKe4CsxAmJuWWsCgYEAw9BR\n 4TjHmcOWkM7SqpRfPJER+3DBo9Bfn8hhkF4SArLUbJZsiw6idFwYs+VlcztFDuoZ\n 4Sd5pyqrTkBMQ+r7JwvdcXD7EnzyxyOQgc7Z0E1VF7y6VA+rOMy70ZWSGrFzyfQy\n zeqRv7OJdSncHlBg20v192R2RstmIEaPYqTWUbkCgYEAhBGcO3i/fYP6LrefTJvI\n dokha/b87w1gPBzEqTWoTJE0TS5FE4GvldnBdh4EoYxDwgsKKSvVy35sqYKZGAXm\n bY0DFud1Q5enHXzl42SvAgIrsHAAEld1GN1dlaxJoAXQZ6AHtIsZVhBH2h9FSdMU\n 9brLxwu/df5BPhQmHswbTXcCgYA8opeYTILShJRtRv5JQCS1lp6g4+uylGXoDp7X\n m6msGEBbV8FI1kFMEvC7VD+0DRh3Y9qbtCOhtj7RvmtfZLZdAvmRlVDKCtMLA2JO\n MAWW0TuWXCS+vxNgRVWrsstJZMXcNbg9t3Nmj2vzUgENigpUHhOOhhdyGK4JNJBW\n FYEgUQKBgCcmUA2QgxDxiOzGZ3JvegdeKZ+Sr+lPlA8Do8VKtn8XH68vjxhLl/CG\n Mny7srfZ8MdLPt3A9ZdIRA83dbiHdBBaLZj4SvJfpU9V9pzcDy2VR+jaK3+lZATW\n lQPeXD36QbptKPlMsxFF1B2AgYnRtQLkqV+M/tyYTj9/ygbce+F+\n -----END RSA PRIVATE KEY-----\n' | tee -a ~/.ssh/id_rsa",
            "chmod 400 ~/.ssh/id_rsa",
            "rm -rf ~/.vim/bundle/YouCompleteMe/",
            "rm *.tgz",
            "rm *.rpm",
            "ls"
        ]
    }
}

resource "aws_instance" "configserver" {
    # Amazon Linux AMI 2015.03 (HVM), SSD Volume Type - ami-1ecae776
    ami = "ami-1ecae776"

    instance_type = "${var.configserver_type}"

    # config server fixed at 3
    count = "${var.configcount}"

    subnet_id = "${aws_subnet.main.id}"
    private_ip = "${lookup(var.instance_ips, concat("config", count.index))}"

    connection {
        # The default username for our AMI
        user = "ec2-user"

        # The path to your keyfile
        key_file = "${var.key_path}"
    }

    security_groups = ["${aws_security_group.shard-default.id}"]
    availability_zone = "us-east-1a"

    key_name = "${var.key_name}"
    tags = {
        Name = "${var.user}-shard-config-${count.index}"
        owner = "${var.owner}"
        expire-on = "2015-07-15"
    }

    associate_public_ip_address = 1

    # We run a remote provisioner on the instance after creating it.
    provisioner "remote-exec" {
        inline = [
            "sudo yum -y update",
            "sudo yum -y install tmux git wget sysstat dstat perf",
            "wget --no-check-certificate https://raw.githubusercontent.com/rzh/dotfiles/no_ycm/bootstrap.sh -O - | sh",
            "curl https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${var.mongoversion}.tgz | tar zxv; mv mongodb-linux-x86_64-${var.mongoversion} ${var.mongoversion}",
            "mkdir bin",
            "ln -s ~/${var.mongoversion}/bin/mongo ~/bin/mongo",
#            "curl https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.6.7.tgz | tar zxv ; mv mongodb-linux-x86_64-2.6.7 2.6.7",
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled", 
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/defrag",
            "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmHUZLsuGvNUlCiaZ83jS9f49S0plAtCH19Z2iATOYPH1XE2T8ULcHdFX2GkYiaEqI+fCf1J1opif45sW/5yeDtIp4BfRAdOu2tOvkKvzlnGZndnLzFKuFfBPcysKyrGxkqBvdupOdUROiSIMwPcFgEzyLHk3pQ8lzURiJNtplQ82g3aDi4wneLDK+zuIVCl+QdP/jCc0kpYyrsWKSbxi0YrdpG3E25Q4Rn9uom58c66/3h6MVlk22w7/lMYXWc5fXmyMLwyv4KndH2u3lV45UAb6cuJ6vn6wowiD9N9J1GS57m8jAKaQC1ZVgcZBbDXMR8fbGdc9AH044JVtXe3lT shardtest@test.mongo' | tee -a ~/.ssh/authorized_keys",
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled", 
            "echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/defrag", 
            "echo f | sudo tee /sys/class/net/eth0/queues/rx-0/rps_cpus",
            "echo f0 | sudo tee /sys/class/net/eth0/queues/tx-0/xps_cpus",
            "rm -rf ~/.vim/bundle/YouCompleteMe/",
            "rm *.tgz",
            "rm *.rpm",
            "ls"
        ]
    }
}

