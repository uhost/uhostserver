# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.hostname = "localtest.getuhost.org"

  config.vm.box = "ubuntu/trusty64"

  config.vm.network :private_network, ip: "33.33.33.10"

  config.vm.boot_timeout = 1200

  config.vm.synced_folder "../uhostchef11server", "/cookbooks/uhostchef11server"

  config.vm.provision "shell" do |s|
    s.path = "installserver.sh"
    s.args   = ["-e", "dev", "-n", "localtest.getuhost.org"]
  end

end
