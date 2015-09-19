#!/bin/bash
#
# Uhost UnInstaller
# https://github.com/uhost/uhostserver/
#
# version: 0.4.0
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

HOSTNAME=""

while getopts h: option
do
  case "${option}"
  in
    h) HOSTNAME=${OPTARG};;
  esac
done

if [ -z "$HOSTNAME" ]; then
  echo "uninstall.sh -h <name>"
  exit 1;
fi

VPC_NAME=${HOSTNAME}-vpc

vpcId=`aws ec2 describe-vpcs --filter Name=tag:Name,Values=${VPC_NAME} --query 'Vpcs[0].VpcId' --output text`
echo "vpcId: $vpcId"
if [ -z "$vpcId" ]; then
  echo "Can't find VPC: $VPC_NAME"
  exit 1;
fi

cidrBlock=`aws ec2 describe-vpcs --vpc-ids $vpcId --query 'Vpcs[0].CidrBlock' --output text`
echo "cidrBlock: $cidrBlock"

instanceIds=`aws ec2 describe-instances --filter Name=vpc-id,Values=${vpcId} --query 'Reservations[].Instances[].InstanceId' --output text`
echo "instanceIds: $instanceIds"
for instanceId in $instanceIds
do
  echo "Terminating Instance: $instanceId"
  aws ec2 terminate-instances --instance-ids $instanceId
done

if [ ! -z "$instanceIds" ]; then
  instancesRunning=`aws ec2 describe-instances --instance-ids ${instanceIds/,/ } --query 'Reservations[].Instances[].State.Name' --output text`
  echo "instancesRunning: $instancesRunning"
  while [ "${instancesRunning/running}" != "$instancesRunning" ] || [ "${instancesRunning/shutting-down}" != "$instancesRunning" ]
  do
    sleep 5
    instancesRunning=`aws ec2 describe-instances --instance-ids ${instanceIds/,/ } --query 'Reservations[].Instances[].State.Name' --output text`
    echo "instancesRunning: $instancesRunning"
  done
fi

KEY_NAME=${HOSTNAME}-key
keyFingerprint=`aws ec2 describe-key-pairs --filter Name=key-name,Values=$KEY_NAME --query 'KeyPairs[0].KeyFingerprint' --output text`
echo "keyFingerprint: $keyFingerprint"
if [ ! -z "$keyFingerprint" ] && [ "$keyFingerprint" != "None" ]; then
  echo "Deleting Key: $keyFingerprint"
  aws ec2 delete-key-pair --key-name $KEY_NAME
fi

internetGateway=`aws ec2 describe-internet-gateways --filter Name=attachment.vpc-id,Values=${vpcId} --query 'InternetGateways[0].InternetGatewayId' --output text`
echo "internetGateway: $internetGateway"
if [ ! -z "$internetGateway" ] && [ "$internetGateway" != "None" ]; then
  echo "Deleting Internet Gateway: $internetGateway"
  aws ec2 detach-internet-gateway --internet-gateway-id $internetGateway --vpc-id ${vpcId}
  aws ec2 delete-internet-gateway --internet-gateway-id $internetGateway
fi

vpcSubnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='$vpcId'].[SubnetId][]" --output text)
echo "vpcSubnets: $vpcSubnets"

for subnetId in $vpcSubnets
do
  echo "Deleting Subnet: $subnetId"
  aws ec2 delete-subnet --subnet-id "$subnetId"
done

ROUTETABLE_NAME=${VPC_NAME}-routetable
routeTables=`aws ec2 describe-route-tables --filter Name=tag:Name,Values=$ROUTETABLE_NAME --query "RouteTables[?VpcId=='$vpcId'].[RouteTableId][]" --output text`
echo "routeTables: $routeTables"

for routeTableId in $routeTables
do
  echo "Deleting Route Table: $routeTableId"
  aws ec2 delete-route-table --route-table-id $routeTableId
done

SECURITY_GROUP_NAME=${HOSTNAME}-security-group
groupId=`aws ec2 describe-security-groups --filter Name=group-name,Values=${SECURITY_GROUP_NAME} --query 'SecurityGroups[0].GroupId' --output text`
echo "groupId: $groupId"
if [ ! -z "$groupId" ] && [ "$groupId" != "None" ]; then
  echo "Deleting Security Group: $groupId"
  aws ec2 delete-security-group --group-id $groupId
fi

if [ ! -z "$vpcId" ]; then
  echo "Deleting VPC: $vpcId"
  aws ec2 delete-vpc --vpc-id $vpcId
fi



