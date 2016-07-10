#!/bin/bash
#
# Uhost Installer
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

export LANG="en_US.UTF-8"

if [ $(id -u) -ne 0 ]
then 
  echo "Need to run this as root, or use sudo"
  exit 1;
fi

QUICK=false
OPTIONS=chef

while getopts e:n:q:o: option
do
  case "${option}"
  in
    e) ENV=${OPTARG};;
    n) HOSTNAME=${OPTARG};;
    q) QUICK=true;;
    o) OPTIONS=${OPTARG};;
  esac
done

if [ "$OPTIONS" = "" ]; then
  echo "Need to have at least 1 option set"
  exit 1;
fi

OPTIONS=${OPTIONS//,/$'\n'}

if [ "$QUICK" = false ]; then
  echo "Updating packages"
  apt=`command -v apt-get`
  aptpackages="git ntp build-essential openssl"
  yum=`command -v yum`
  yumpackages="git-core ntp make automake gcc gcc-c++ openssl"

  if [ -n "$apt" ]; then
    apt-get update
    apt-get -y install $aptpackages
  elif [ -n "$yum" ]; then
    yum -y install $yumpackages
  else
    echo "Err: no path to apt-get or yum" >&2;
    exit 1;
  fi
fi

CHEFCLIENT=/usr/bin/chef-client
BERKSHELF=/usr/bin/berks

if [ ! -x "$CHEFCLIENT" ] || [ ! -x "$BERKSHELF" ]; then
  echo "Downloading and installing chef-dk 0.11.2"
  wget -nv https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.11.2-1_amd64.deb
  dpkg -i chefdk_0.11.2-1_amd64.deb
fi

if [ ! -x "$CHEFCLIENT" ]; then
  echo "$CHEFCLIENT not installed"
  exit 1;
fi 

if [ ! -x "$BERKSHELF" ]; then
  echo "$BERKSHELF not installed"
  exit 1;
fi 

UHOSTSERVERDIR='./uhostserver'

if [ ! -d $UHOSTSERVERDIR ]; then
  mkdir $UHOSTSERVERDIR
fi
cd $UHOSTSERVERDIR

if [ ! -d .chef ]; then
  mkdir .chef
fi

cat > .chef/knife.rb <<EOL
log_level                :info
log_location             STDOUT
EOL

if [ $HTTP_PROXY ]; then
  cat >> .chef/knife.rb <<EOL
http_proxy "$HTTP_PROXY"
https_proxy "$HTTPS_PROXY"
EOL
fi

if [ ! -d data_bags/users ]; then
  mkdir -p data_bags/users
fi

cat > data_bags/users/uhost.json <<EOL
{
  "id": "uhost",
  "shell": "/bin/bash",
  "groups": ["uhost", "wheel"],
  "comment": "uhost <uhost@getuhost.org>" 
}
EOL

country="CA"
state="British Columbia"
company=""
city="Vancouver"
organiztion=""
email=""

# Generate a passphrase
export PASSPHRASE=$(head -c 500 /dev/urandom | LC_CTYPE=C tr -dc "a-z0-9A-Z" | head -c 128; echo)

# Certificate details; replace items in angle brackets with your own info
subj="
C=$country
ST=$state
O=$company
localityName=$city
commonName=*.$HOSTNAME
organizationalUnitName=$organization
emailAddress=$email
"

encrypted_data_bag_secret="./encrypted_data_bag_secret"

if [ ! -f encrypted_data_bag_secret ]; then
  openssl rand -base64 512 | tr -d '\r\n' > $encrypted_data_bag_secret
  chmod 600 $encrypted_data_bag_secret
fi

if [ ! -f ${HOSTNAME}.key ] || [ ! -f ${HOSTNAME}.crt ]; then
  openssl genrsa -out ${HOSTNAME}.key -passout env:PASSPHRASE 2048
  openssl req -new -subj "$(echo -n "$subj" | tr "\n" "/")" -key "${HOSTNAME}.key" -out "${HOSTNAME}.csr" -passin env:PASSPHRASE
  cp ${HOSTNAME}.key ${HOSTNAME}.key.org
  openssl rsa -in ${HOSTNAME}.key.org -out ${HOSTNAME}.key -passin env:PASSPHRASE
  openssl x509 -req -days 3650 -in "${HOSTNAME}.csr" -signkey "${HOSTNAME}.key" -out "${HOSTNAME}.crt"
fi

CERT=`cat ${HOSTNAME}.crt | sed 's/$/\\\\n/' | tr -d '\n'`
KEY=`cat ${HOSTNAME}.key | sed 's/$/\\\\n/' | tr -d '\n'`

if [ ! -d unencrypted/certificates ]; then
  mkdir -p unencrypted/certificates
fi

cat <<EOT > unencrypted/certificates/${HOSTNAME}.json
{
  "id": "$HOSTNAME",
  "key": "$KEY",
  "cert": "$CERT"
}
EOT

if [ ! -d data_bags/certificates ]; then
  knife data bag create certificates -z
fi
knife data bag from file certificates unencrypted/certificates/${HOSTNAME}.json --secret-file $encrypted_data_bag_secret -z


cat > chef11server.json <<EOL
{
  "name": "$HOSTNAME",
  "description": "Install uhostserver on $HOSTNAME",
  "run_list":[
    "recipe[uhostchef11server::default]"
  ],
  "chef11server": {
    "nginx": {
      "certificate": "$HOSTNAME"
    }
  }
}
EOL

cat > uhostappserver.json <<EOL
{
  "name": "$HOSTNAME",
  "description": "Install uhostserver on $HOSTNAME",
  "run_list":[
    "recipe[uhostapi::default]"
  ],
  "uhostappserver": {
    "nginx": {
      "certificate": "$HOSTNAME"
    }
  }
}
EOL

COOKBOOKPATHS="root + '/berks-cookbooks'"

cat > uhost.rb <<EOL
root = File.absolute_path(File.dirname(__FILE__))
file_cache_path root
cookbook_path $COOKBOOKPATHS
encrypted_data_bag_secret root + '/encrypted_data_bag_secret'
verify_api_cert true
EOL

if [ $HTTP_PROXY ]; then
  cat >> uhost.rb <<EOL
http_proxy "$HTTP_PROXY"
https_proxy "$HTTPS_PROXY"
EOL
fi

for opt in $OPTIONS; do
  case "${opt}"
  in
    chef) 
      echo "Installing Chef"
      if [ "$ENV" = "dev" ]; then
        UHOSTCHEF11SERVER='path: "/cookbooks/uhostchef11server"'
      else
        UHOSTCHEF11SERVER='git: "https://github.com/uhost/uhostchef11server.git"'
      fi

      cat << EOF | sudo tee Berksfile > /dev/null
source "https://supermarket.chef.io"
cookbook "uhostchef11server", $UHOSTCHEF11SERVER
EOF

      berks vendor

      $CHEFCLIENT -z -c uhost.rb -N $HOSTNAME -j chef11server.json 
      ;;
    api) 
      echo "Installing API"
      if [ "$ENV" = "dev" ]; then
        UHOSTAPI='path: "/cookbooks/uhostapi"'
      else
        UHOSTAPI='git: "https://github.com/uhost/uhostapi.git"'
      fi

      cat << EOF | sudo tee Berksfile > /dev/null
source "https://supermarket.chef.io"
cookbook "uhostapi", $UHOSTAPI
EOF

      berks vendor

      $CHEFCLIENT -z -c uhost.rb -N $HOSTNAME -j uhostappserver.json 
      ;; 
  esac
done



