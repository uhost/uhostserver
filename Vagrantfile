# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.hostname = "uhostserver.getuhost.org"

  config.vm.box = "chef/ubuntu-12.04"

  config.vm.network :private_network, ip: "33.33.33.10"

  config.vm.boot_timeout = 1200

  config.vm.synced_folder "../uhostchef11server", "/cookbooks/uhostchef11server"

  config.vm.provision "shell" do |s|
    s.path = "installserver.sh"
    s.args   = ["-e", "dev", "-n", "uhostserver.getuhost.org"]
  end

  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "http://172.28.128.1:3128/"
    config.proxy.https    = "http://172.28.128.1:3128/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
  end
end
