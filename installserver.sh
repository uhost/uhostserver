#!/bin/sh
#
# Authors and License
#

if [ $(id -u) -ne 0 ]
then 
  echo "Need to run this as root, or use sudo"
  exit 1;
fi

CHEFCLIENT=/usr/bin/chef-client

while getopts e:n: option
do
  case "${option}"
  in
    e) ENV=${OPTARG};;
    n) HOSTNAME=${OPTARG};;
  esac
done

if ! test -f "$CHEFCLIENT"; then
  # Download and install chef
  wget -qO- https://www.opscode.com/chef/install.sh | sudo bash
fi

if ! test -f "$CHEFCLIENT"; then
  echo "$CHEFCLIENT not installed"
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

if [ ! -d cookbooks_repo ]; then
  mkdir cookbooks_repo
fi

cd cookbooks_repo
for COOKBOOK in hostsfile apt nginx bluepill rsyslog build-essential hostname ohai runit yum yum-epel users
do
  if [ -d $COOKBOOK ]; then
    rm -rf $COOKBOOK
  fi
  knife cookbook site download $COOKBOOK
  tar zxf $COOKBOOK-[0-9]*.tar.gz
done

COOKBOOKPATHS="root + '/cookbooks_repo'"
if [ "$ENV" = "dev" ]
then
  COOKBOOKPATHS="[$COOKBOOKPATHS, '/cookbooks']"
else
  apt=`command -v apt-get`
  aptpackages="git"
  yum=`command -v yum`
  yumpackages="git-core"

  if [ -n "$apt" ]; then
    apt-get update
    apt-get -y install $aptpackages
  elif [ -n "$yum" ]; then
    yum -y install $yumpackages
  else
    echo "Err: no path to apt-get or yum" >&2;
    exit 1;
  fi

  if [ -d "uhostchef11server" ]; then
    cd uhostchef11server
    git pull
    cd ..
  else
    git clone https://github.com/uhost/uhostchef11server.git
  fi

fi

cd ..

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
  "comment": "uhost <uhost@getuhost.com>" 
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


