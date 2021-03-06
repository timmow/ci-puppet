# -*- mode: ruby -*-
# vi: set ft=ruby :

if Vagrant::VERSION < "1.1.0"
  $stderr.puts "WARNING: Using old Vagrantfile format! Please upgrade to Vagrant >1.1.\n"
  Vagrant::Config.run do |config|
    vagrant_config(config, 1)
  end
else
  Vagrant.configure("2") do |config|
    vagrant_config(config, 2)
  end
end

def vagrant_config(config, version)
  nodes = {
    'ci-master-1' => {:ip => '172.16.11.10'},
    'ci-slave-1'  => {:ip => '172.16.11.11'},
    'ci-slave-2'  => {:ip => '172.16.11.12'},
    'ci-management-1' => {:ip => '172.16.11.13'},
    'transition-logs-1' => {:ip => '172.16.11.20',
                            :extra_disks => [
                              { :name => 'sdb', :size => '524288'},
                              { :name => 'sdc', :size => '524288'},
                              { :name => 'sdd', :size => '524288'}
                            ]

    },
  }
  node_defaults = {
    :domain => 'internal',
    :memory => 384,
  }

  config.vm.box     = "puppet-precise64"
  config.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-1204-x64.box"

  config.vm.provision :shell, :path => 'tools/bootstrap'
  config.vm.provision :puppet do |puppet|
    puppet.manifest_file  = "site.pp"
    puppet.manifests_path = "manifests"
    puppet.module_path    = [ "modules", "vendor/modules" ]
    puppet.options = [
      "--verbose", "--summarize",
      "--reports", "store",
      "--hiera_config", "/vagrant/hiera_development.yaml",
      "--environment", "development",
    ]
  end

  nodes.each do |node_name, node_opts|
    config.vm.define node_name do |node|
      node_opts = node_defaults.merge(node_opts)
      fqdn = "#{node_name}.#{node_opts[:domain]}"

      if version < 2
        node.vm.host_name = fqdn
      else
        node.vm.hostname = fqdn
      end

      if node_opts[:ip]
        if version < 2
          node.vm.network(:hostonly, node_opts[:ip], :netmask => "255.255.255.0")
        else
          node.vm.network(:private_network, :ip => node_opts[:ip])
        end
      end

      modifyvm_args = ['modifyvm', :id]
      modifyvm_args << "--name" << fqdn
      if node_opts[:memory]
        modifyvm_args << "--memory" << node_opts[:memory]
      end
      # Isolate guests from host networking.
      modifyvm_args << "--natdnsproxy1" << "on"
      modifyvm_args << "--natdnshostresolver1" << "on"
      if version < 2
        node.vm.customize(modifyvm_args)
      else
        node.vm.provider(:virtualbox)  do |vb|
          vb.customize(modifyvm_args)
          # Add extra disks if specified
          if node_opts.has_key?(:extra_disks) and !node_opts[:extra_disks].nil?
            disk_num = 0
            for disk in node_opts[:extra_disks] do
              disk_num += 1
              disk_name = disk[:name]
              disk_size = disk[:size]
              file_to_disk =  "#{node_name}_extra_disk_#{disk_name}_controller_#{disk_num}.vdi"
              vb.customize(['createhd', '--filename', file_to_disk, '--size', disk_size,  "--format", "vdi"])
              vb.customize(['storageattach', :id, '--storagectl','SATA Controller', '--port', disk_num, '--device', 0, '--type', 'hdd', '--medium', file_to_disk])
            end
          end
        end
      end
    end
  end
end
