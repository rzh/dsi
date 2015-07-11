#!/bin/bash

source setting.sh

sed -i -- "s/%%P1%%/\"$SSHUSER@$p1\"/g" *.json
sed -i -- "s/%%MS_PRIVATE_IP%%/$ms_private_ip/g" *.json
sed -i -- "s/%%CLIENT%%/\"$SSHUSER@$mc\"/g" *.json
