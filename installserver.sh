#!/bin/sh
#
# Authors and License
#

CHEFSOLO=/usr/bin/chef-solo

aptpackages='git'
yumpackages='git'
apt=`command -v apt-get`
yum=`command -v yum`

if [ -n "$apt" ]; then
    apt-get update
    apt-get -y install $package
elif [ -n "$yum" ]; then
    yum -y install $package
else
    echo "Err: no path to apt-get or yum" >&2;
    exit 1;
fi


if ! test -f "$CHEFSOLO"; then
  # Download and install chef
  curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi

