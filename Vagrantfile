require 'socket'

hostname = Socket.gethostname
localmachineip = IPSocket.getaddress(Socket.gethostname)
puts %Q{ This machine has the IP '#{localmachineip} and host name '#{hostname}'}

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

deployment_type = 'origin'
rhsm_pool = 'Employee SKU'
sync_type = ENV['SYNC_TYPE'] || ''

REQUIRED_PLUGINS = %w(vagrant-hostmanager)
SUGGESTED_PLUGINS = %w(vagrant-sshfs landrush vagrant-cachier)

def message(name)
  "#{name} plugin is not installed, run `vagrant plugin install #{name}` to install it."
end

SUGGESTED_PLUGINS.each { |plugin| print("note: " + message(plugin) + "\n") unless Vagrant.has_plugin?(plugin) }

errors = []

# Validate and collect error message if plugin is not installed
REQUIRED_PLUGINS.each { |plugin| errors << message(plugin) unless Vagrant.has_plugin?(plugin) }
unless errors.empty?
  msg = errors.size > 1 ? "Errors: \n* #{errors.join("\n* ")}" : "Error: #{errors.first}"
  fail Vagrant::Errors::VagrantError.new, msg
end

if sync_type == ''
  if Vagrant.has_plugin?('vagrant-sshfs')
    sync_type = 'sshfs'
  else
    sync_type = 'rsync'
  end
end


#box_name = 'centos/7'
box = 'boeboe/centos7-vbguest'
box_version = '5.2.6'

NETWORK_BASE = '192.168.50'
INTEGRATION_START_SEGMENT = 20

def quote_labels(labels)
    # Quoting logic for ansible host_vars has changed in Vagrant 2.0
    # See: https://github.com/hashicorp/vagrant/commit/ac75e409a3470897d56a0841a575e981d60e2e3d
    if Vagrant::VERSION.to_i >= 2
      return '{' + labels.map{|k, v| "\"#{k}\": \"#{v}\""}.join(', ') + '}'
    else
      return '"{' + labels.map{|k, v| "'#{k}': '#{v}'"}.join(', ') + '}"'
    end
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :machine
  end

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.ignore_private_ip = false
#  config.hostmanager.incoverride_box_urllude_offline = true

  if Vagrant.has_plugin?('landrush')
    config.landrush.enabled = true
    config.landrush.tld = 'example.com'
    config.landrush.guest_redirect_dns = false
  end

  # Configure eth0 via script, will disable NetworkManager and enable legacy network daemon:
  config.vm.provision "shell", path: "provision/setup.sh", args: [NETWORK_BASE]

  config.vm.provider "virtualbox" do |v, override|
    #v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate//vagrant","1"]
    override.vm.box = box
    override.vm.box_version = box_version
    provider_name = 'virtualbox'
  end

  config.vm.provider "libvirt" do |libvirt, override|
    libvirt.driver = 'kvm'
    override.vm.box = box
    override.vm.box_version = box_version
    provider_name = 'libvirt'
  end

  # Suppress the default sync in both CentOS base and CentOS Atomic Host
  config.vm.synced_folder '.', '/vagrant', disabled: false
  config.vm.synced_folder '.', '/home/vagrant/sync', disabled: false

  config.vm.define "master1" do |master1|
    master1.vm.provider :virtualbox do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end
    master1.vm.network :private_network, ip: "#{NETWORK_BASE}.#{INTEGRATION_START_SEGMENT}"
    master1.vm.hostname = "master1.example.com"
    master1.hostmanager.aliases = %w(master1)
  end

  config.vm.define "node1" do |node1|
    node1.vm.provider :virtualbox do |vb|
      vb.memory = 2048
      vb.cpus = 1
    end
    node1.vm.network :private_network, ip: "#{NETWORK_BASE}.#{INTEGRATION_START_SEGMENT + 1}"
    node1.vm.hostname = "node1.example.com"
    node1.hostmanager.aliases = %w(node1)
  end

  config.vm.define "node2" do |node2|
    node2.vm.provider :virtualbox do |vb|
      vb.memory = 2048
      vb.cpus = 1
    end
    node2.vm.network :private_network, ip: "#{NETWORK_BASE}.#{INTEGRATION_START_SEGMENT + 2}"
    node2.vm.hostname = "node2.example.com"
    node2.hostmanager.aliases = %w(node2)
  end

  config.vm.define "node3" do |node3|
    node3.vm.provider :virtualbox do |vb|
      vb.memory = 2048
      vb.cpus = 1
    end
    node3.vm.network :private_network, ip: "#{NETWORK_BASE}.#{INTEGRATION_START_SEGMENT + 3}"
    node3.vm.hostname = "node3.example.com"
    node3.hostmanager.aliases = %w(node3)
  end

  config.vm.define "admin1" do |admin1|
    admin1.vm.provider :virtualbox do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    admin1.vm.network :private_network, ip: "#{NETWORK_BASE}.#{INTEGRATION_START_SEGMENT + 4}"
    admin1.vm.hostname = "admin1.example.com"
    admin1.hostmanager.aliases = %w(admin1)

    config_playbook = "/home/vagrant/openshift-ansible/playbooks/byo/config.yml"

    admin1.vm.synced_folder ".", "/home/vagrant/sync", type: sync_type
    admin1.vm.synced_folder ".vagrant", "/home/vagrant/.hidden", type: sync_type

    ansible_groups = {
      OSEv3: ["master1", "node1", "node2", "node3"],
      'OSEv3:children': ["masters", "nodes", "etcd", "nfs"],
      'OSEv3:vars': {
        ansible_become: true,
        ansible_ssh_user: 'vagrant',
        deployment_type: deployment_type,
        openshift_master_identity_providers: "[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]",
        openshift_master_htpasswd_users: "{'admin': '$apr1$nWG7vwhy$jCMCBmBrW3MEYmCFCckYk1'}",
        openshift_master_default_subdomain: 'apps.example.com',
        osm_default_node_selector: 'region=primary',
        openshift_hosted_registry_selector: 'region=infra',
        openshift_hosted_registry_replicas: 1,
        openshift_hosted_registry_storage_kind: 'nfs',
        openshift_hosted_registry_storage_access_modes: ['ReadWriteMany'],
        openshift_hosted_registry_storage_host: 'admin1.example.com',
        openshift_hosted_registry_storage_nfs_directory: '/srv/nfs',
        openshift_hosted_registry_storage_volume_name: 'registry',
        openshift_hosted_registry_storage_volume_size: '5Gi',
        openshift_disable_check: "docker_image_availability,memory_availability,disk_availability,docker_storage",
        rhsm_user: "#{ENV.fetch('SUB_USERNAME', '')}",
        rhsm_password: "#{ENV.fetch('SUB_PASSWORD', '')}",
        rhsm_pool: rhsm_pool,
      },
      etcd: ["master1"],
      nfs: ["admin1"],
      masters: ["master1"],
      nodes: ["master1", "node1", "node2", "node3"],
      all: ["admin1", "master1", "node1", "node2", "node3"]
    }

    ansible_host_vars = {
      master1:  {
        openshift_ip: '192.168.50.20',
        openshift_node_labels: quote_labels(
          region: 'infra',
          zone: 'default',
        ),
        openshift_schedulable: true,
        ansible_host: '192.168.50.20',
        ansible_ssh_private_key_file: "/home/vagrant/.ssh/master1.key"
      },
      node1: {
        openshift_ip: '192.168.50.21',
        openshift_node_labels: quote_labels(
          region: 'primary',
          zone: 'east',
        ),
        openshift_schedulable: true,
        ansible_host: '192.168.50.21',
        ansible_ssh_private_key_file: "/home/vagrant/.ssh/node1.key"
      },
      node2: {
        openshift_ip: '192.168.50.22',
        openshift_node_labels: quote_labels(
          region: 'primary',
          zone: 'west',
        ),
        openshift_schedulable: true,
        ansible_host: '192.168.50.22',
        ansible_ssh_private_key_file: "/home/vagrant/.ssh/node2.key"
      },
      node3: {
        openshift_ip: '192.168.50.23',
        openshift_node_labels: quote_labels(
          region: 'primary',
          zone: 'central',
        ),
        openshift_schedulable: true,
        ansible_host: '192.168.50.23',
        ansible_ssh_private_key_file: "/home/vagrant/.ssh/node3.key"
      },
      admin1: {
        ansible_connection: 'local',
        deployment_type: deployment_type
      }
    }

    admin1.vm.provision :ansible_local do |ansible|
      ansible.verbose           = "vvv"
      ansible.install           = true
      ansible.limit             = 'OSEv3:localhost'
      ansible.provisioning_path = '/home/vagrant/sync'
      ansible.playbook          = '/home/vagrant/sync/install.yaml'
      ansible.groups            = ansible_groups
      ansible.host_vars         = ansible_host_vars
      #ansible.extra_vars        = { ansible_python_interpreter:"/usr/bin/python3.6" }
    end

    admin1.vm.provision :ansible_local do |ansible|
      ansible.verbose           = "vvv"
      ansible.install           = false
      ansible.limit             = "OSEv3:localhost"
      ansible.provisioning_path = '/home/vagrant/sync'
      ansible.playbook          = config_playbook
      ansible.groups            = ansible_groups
      ansible.host_vars         = ansible_host_vars
      #ansible.extra_vars        = { ansible_python_interpreter:"/usr/bin/python3.6" }
    end
  end
end
