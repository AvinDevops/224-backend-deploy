#!/bin/bash
component=$1
environment=$2
app_version=$3
dnf install ansible -y 
pip3.9 install boto3 botocore
ansible-pull -i localhost, -U https://github.com/AvinDevops/220-expense-ansible-roles-tf.git main.yaml -e component=$component -e env=$environment -e appVersion=$app_version