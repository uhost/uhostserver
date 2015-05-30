#!/bin/bash
#
# Authors and License
#

if [ $(id -u) -ne 0 ]
then 
  echo "Need to run this as root, or use sudo"
  exit 1;
fi

while getopts e:n: option
do
  case "${option}"
  in
    e) ENV=${OPTARG};;
    n) HOSTNAME=${OPTARG};;
  esac
done

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

CHEFCLIENT=/usr/bin/chef-client
BERKSHELF=/usr/bin/berks

if [ ! -x "$CHEFCLIENT" ] && [ ! -x "$BERKSHELF" ]; then
  echo "Downloading and installing chef $CHEFVERSION"
  wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.6.0-1_amd64.deb
  dpkg -i chefdk_0.6.0-1_amd64.deb
fi

if ! test -f "$CHEFCLIENT"; then
  echo "$CHEFCLIENT not installed"
  exit 1;
fi 

if ! test -f "$BERKSHELF"; then
  echo "$BERKSHELF not installed"
  exit 1;
fi 

echo "Downloading and installing berkshelf"

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

cookbook "7-zip", "=1.0.2"
cookbook "apt", "=2.6.1"
cookbook "ark", "=0.9.0"
cookbook "bluepill", "=2.3.1"
cookbook "build-essential", "=2.1.3"
cookbook "chef_handler", "=1.1.6"
cookbook "hostname", "=0.3.0"
cookbook "hostsfile", "=2.4.4"
cookbook "mongodb", "=0.16.2"
cookbook "nginx", "=2.7.4"
cookbook "nodejs", "=2.2.0"
cookbook "ohai", "=2.0.1"
cookbook "python", "=1.4.6"
cookbook "redisio", "=2.3.0"
cookbook "rsyslog", "=1.13.0"
cookbook "runit", "=1.5.12"
cookbook "uhostchef11server", $UHOSTCHEF11SERVER
cookbook "ulimit", "=0.3.3"
cookbook "users", "=1.7.0"
cookbook "windows", "=1.36.1"
cookbook "yum", "=3.5.2"
cookbook "yum-epel", "=0.6.0"
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

exit;

$CHEFCLIENT -z -c uhost.rb -o "recipe[uhostchef11server]" -N $HOSTNAME


