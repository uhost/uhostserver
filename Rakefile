require 'rake'
require 'rspec/core/rake_task'

hosts = [
  ENV['TARGET_HOST']
]

task :spec => 'spec:all'

namespace :spec do
  task :all => hosts.map {|h| 'spec:' + h.split('.')[0] }
  hosts.each do |host|
    puts host
    short_name = host.split('.')[0]

    desc "Run serverspec to #{host}"
    RSpec::Core::RakeTask.new(short_name) do |t|
      t.pattern = "spec/base/*_spec.rb"
    end
  end
end
