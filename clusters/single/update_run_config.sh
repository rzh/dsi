#!/bin/bash

source setting.sh

sed -i -- "s/%%P1%%/\"$SSHUSER@$p1\"/g" *.json
sed -i -- "s/%%I1%%/$i1/g" *.json
sed -i -- "s/%%CLIENT%%/\"$SSHUSER@$mc\"/g" *.json
