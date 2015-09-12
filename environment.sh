#!/bin/bash
#
# Uhost Environment
# https://github.com/uhost/uhostserver/
#
# version: 0.3.0
#
# License & Authors
#
# Author:: Mark Allen (mark@markcallen.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

path_to_aws=$(which aws)
if [ ! -x "$path_to_aws" ] ; then
   echo "Can't find AWS CLI, check that its in your path"
   exit 1;
fi

: ${AWS_ACCESS_KEY_ID:?"Need to set AWS_ACCESS_KEY_ID"}
: ${AWS_SECRET_ACCESS_KEY:?"Need to set AWS_SECRET_ACCESS_KEY"}
: ${AWS_DEFAULT_REGION:?"Need to set AWS_DEFAULT_REGION"}

HOSTNAME=""

PWD=`pwd`

while getopts h: option
do
  case "${option}"
  in
    h) HOSTNAME=${OPTARG};;
  esac
done

if [ -z "$HOSTNAME" ]; then
  echo "$0 -h <name>"
  exit 1;
fi

VPC_NAME=${HOSTNAME}-vpc

vpcId=`aws ec2 describe-vpcs --filter Name=tag:Name,Values=${VPC_NAME} --query 'Vpcs[0].VpcId' --output text`
echo "Found vpcId: $vpcId"
if [ -z "$vpcId" ]; then
  echo "Can't find VPC: $VPC_NAME"
  exit 1;
fi

KEY_NAME=${HOSTNAME}-key
keyName=`aws ec2 describe-key-pairs --filter Name=key-name,Values=$KEY_NAME --query 'KeyPairs[0].KeyName' --output text`
if [ ! -z "$keyName" ] && [ "$keyName" != "None" ]; then
  AWS_SSH_KEY_ID=$keyName
fi

vpcSubnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='$vpcId'].[SubnetId][]" --output text)

for subnetId in $vpcSubnets
do
  AWS_SUBNET_ID=$subnetId
done

SECURITY_GROUP_NAME=${HOSTNAME}-security-group
groupId=`aws ec2 describe-security-groups --filter Name=group-name,Values=${SECURITY_GROUP_NAME} --query 'SecurityGroups[0].GroupId' --output text`
if [ ! -z "$groupId" ] && [ "$groupId" != "None" ]; then
  AWS_SECURITY_GROUP_ID=$groupId
fi

echo export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
echo export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
echo export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
echo export AWS_SSH_KEY_ID=${AWS_SSH_KEY_ID}
echo export AWS_SSH_KEY=${PWD}/${AWS_SSH_KEY_ID}.pem
echo export AWS_SECURITY_GROUP_ID=${AWS_SECURITY_GROUP_ID}
echo export AWS_SUBNET_ID=${AWS_SUBNET_ID}



