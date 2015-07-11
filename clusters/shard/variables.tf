variable "count" {
    default = 3
}

variable "configcount" {
    default = 3
}

variable "mastercount" {
    default = 2
}

variable "mongoversion" {
    default = "3.0.1"
}

variable "user" {
    default = "CHANGEME"
}

variable "owner" {
    default = "CHANGEME"
}

variable "secondary_type" {
    default = "m3.2xlarge"
}

variable "configserver_type" {
    default = "m3.xlarge"
}

variable "primary_type" {
    default = "m3.2xlarge"
}

variable "instance_ips" {
    default = {
        "0" = "10.2.2.100"
        "1" = "10.2.2.101"
        "2" = "10.2.2.102"
        "3" = "10.2.2.103"
        "4" = "10.2.2.104"
        "5" = "10.2.2.105"
        "6" = "10.2.2.106"
        "7" = "10.2.2.107"
        "8" = "10.2.2.108"
        "9" = "10.2.2.109"
        "10" = "10.2.2.110"
        "11" = "10.2.2.111"
        "12" = "10.2.2.112"
        "13" = "10.2.2.113"
        "14" = "10.2.2.114"
        "15" = "10.2.2.115"
        "16" = "10.2.2.116"
        "17" = "10.2.2.117"
        "18" = "10.2.2.118"
        "19" = "10.2.2.119"
        "20" = "10.2.2.120"
        "21" = "10.2.2.121"
        "22" = "10.2.2.122"
        "23" = "10.2.2.123"
        "24" = "10.2.2.124"
        "25" = "10.2.2.125"
        "26" = "10.2.2.126"
        "27" = "10.2.2.127"
        "28" = "10.2.2.128"
        "29" = "10.2.2.129"
        "30" = "10.2.2.130"
        "31" = "10.2.2.131"
        "32" = "10.2.2.132"
        "33" = "10.2.2.133"
        "34" = "10.2.2.134"
        "35" = "10.2.2.135"
        "36" = "10.2.2.136"
        "37" = "10.2.2.137"
        "38" = "10.2.2.138"
        "39" = "10.2.2.139"
        "40" = "10.2.2.140"
        "41" = "10.2.2.141"
        "42" = "10.2.2.142"
        "43" = "10.2.2.143"
        "44" = "10.2.2.144"
        "45" = "10.2.2.145"
        "46" = "10.2.2.146"
        "47" = "10.2.2.147"
        "48" = "10.2.2.148"
        "49" = "10.2.2.149"
        "50" = "10.2.2.150"
        "51" = "10.2.2.151"
        "52" = "10.2.2.152"
        "53" = "10.2.2.153"
        "54" = "10.2.2.154"
        "55" = "10.2.2.155"
        "56" = "10.2.2.156"
        "57" = "10.2.2.157"
        "58" = "10.2.2.158"
        "59" = "10.2.2.159"
        "master0" = "10.2.2.98"
        "master1" = "10.2.2.99"
        "config0" = "10.2.2.81"
        "config1" = "10.2.2.82"
        "config2" = "10.2.2.83"
    }
}
