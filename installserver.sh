#!/bin/bash
#
# Uhost Installer
#
# version: 0.3.0
#
# Authors and License
#

export LANG="en_US.UTF-8"

if [ $(id -u) -ne 0 ]
then 
  echo "Need to run this as root, or use sudo"
  exit 1;
fi

QUICK=false

while getopts e:n:q: option
do
  case "${option}"
  in
    e) ENV=${OPTARG};;
    n) HOSTNAME=${OPTARG};;
    q) QUICK=true
  esac
done

if [ "$QUICK" = false ]; then
  echo "Updating packages"
  apt=`command -v apt-get`
  aptpackages="git ntp build-essential"
  yum=`command -v yum`
  yumpackages="git-core ntp make automake gcc gcc-c++"

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
  echo "Downloading and installing chef $CHEFVERSION"
  wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.6.0-1_amd64.deb
  dpkg -i chefdk_0.6.0-1_amd64.deb
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

COOKBOOKPATHS="root + '/berks-cookbooks'"

if [ ! -d data_bags ]; then
  mkdir -p data_bags/users
fi

cd data_bags/users

cat > uhost.json <<EOL
{
  "id": "uhost",
  "gid": "uhost",
  "shell": "/bin/bash",
  "groups": ["uhost", "wheel"],
  "comment": "uhost <uhost@getuhost.org>" 
}
EOL

cd ../..

cat > uhost.rb <<EOL
root = File.absolute_path(File.dirname(__FILE__))
file_cache_path root
cookbook_path $COOKBOOKPATHS
verify_api_cert true
EOL

if [ $HTTP_PROXY ]; then
  cat >> uhost.rb <<EOL
http_proxy "$HTTP_PROXY"
https_proxy "$HTTPS_PROXY"
EOL
fi

$CHEFCLIENT -z -c uhost.rb -o "recipe[uhostchef11server]" -N $HOSTNAME


