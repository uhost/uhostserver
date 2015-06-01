# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

unless Vagrant.has_plugin?('vagrant-aws')
  system('vagrant plugin install vagrant-aws') || exit!
  exit system('vagrant', *ARGV)
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "#{ENV['HTTP_PROXY']}"
    config.proxy.https    = "#{ENV['HTTPS_PROXY']}"
    config.proxy.no_proxy = "localhost,127.0.0.1,.getuhost.org"
  end

  config.vm.hostname = "localtest.getuhost.org"

  config.vm.synced_folder "../uhostchef11server", "/cookbooks/uhostchef11server"

  config.vm.provision "shell" do |s|
    s.path = "installserver.sh"
    s.args   = ["-e", "dev", "-n", "localtest.getuhost.org"]
  end

  config.vm.define "local" do |local|
    local.vm.box = "ubuntu/trusty64"
    local.vm.network :private_network, ip: "33.33.33.10"
    local.vm.boot_timeout = 1200
    local.vm.provider "virtualbox" do |v|
      v.memory = 4096
      v.cpus = 2
    end
  end

  config.vm.define "aws" do |aws|
    aws.vm.box = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
  end

  config.vm.provider "aws" do |ec2, override|
    ec2.access_key_id = "#{ENV['AWS_ACCESS_KEY_ID']}"
    ec2.secret_access_key = "#{ENV['AWS_SECRET_ACCESS_KEY']}"
    ec2.keypair_name = "#{ENV['AWS_SSH_KEY_ID']}"
    ec2.subnet_id = "subnet-2ae12073"
    ec2.security_groups = ["sg-68e9c90d"]
    ec2.region = "us-west-2"
    ec2.instance_type = "m3.large"

    ec2.ami = "ami-67526757"

    override.ssh.username = "ubuntu"
    override.ssh.private_key_path = "#{ENV['AWS_SSH_KEY']}"
  end
end
