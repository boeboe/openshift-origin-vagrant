Overview
--------

This is a Vagrant based project that demonstrates an advanced Openshift Origin install i.e. one using an Ansible playbook.

The documentation for the installation process can be found at

https://docs.openshift.org/latest/welcome/index.html



Pre-requisites
--------------

* Vagrant
* VirtualBox or Libvirt (--provider=libvirt)

Install the following vagrant plugins:

* landrush
* vagrant-hostmanager
* vagrant-sshfs or vagrant-rsync
* vagrant-cachier

In order to speed-up provisioning, we use vagrant-cachier, which needs VirtualBox Guest Additions to work. We have provided
such a box based on centos/7 for VirtualBox version 5.2.6. Feel free to submit a request for other versions.

https://app.vagrantup.com/boeboe/boxes/centos7-vbguest/versions/5.2.6

*NOTE:* You can create your own box by using a helper script located at _vagrant-box/create-box.sh_

Installation
------------

    git clone https://github.com/boeboe/openshift-origin-vagrant.git
    cd openshift-origin-vagrant
    vagrant up

Two ansible playbooks will start on admin1 after it has booted. The first playbook bootstraps the pre-requisites for the Openshift install. The second playbook is the actual Openshift install. The inventory for the Openshift install is declared inline in the Vagrantfile.

The install comprises one master and three nodes. The NFS share gets created on admin1.

| VM Name   | Memory  | Cores  | IP             | DNS                  |
| --------- |:-------:|:------:|:--------------:|:--------------------:|
| admin1    | 1GB     | 1      | 192.168.50.24  | admin1.example.com   |
| master1   | 4GB     | 2      | 192.168.50.20  | master1.example.com  |
| node1     | 2GB     | 1      | 192.168.50.21  | node1.example.com    |
| node2     | 2GB     | 1      | 192.168.50.22  | node2.example.com    |
| node3     | 2GB     | 1      | 192.168.50.23  | node3.example.com    |

The inventory makes use of the 'openshift_ip' property to force the use of the eth1 network interface which is using the 192.168.50.x ip addresses of the vagrant private network.

Once complete AND after confirming that the docker-registry pod is up and running then

Logon to https://master1.example.com:8443 as admin/admin123, create a project test then

ssh to master1:

    ssh master1
    oc login -u=system:admin
    oc annotate namespace test openshift.io/node-selector='region=primary' --overwrite

On the host machine first verify the contents of /etc/dnsmasq.d/vagrant-landrush gives

    server=/example.com/127.0.0.1#10053

then update the dns entries thus

    vagrant landrush set apps.example.com 192.168.50.20

In the web console create a PHP app and wait for it to complete the deployment. Navigate to the overview page for the test app and click on the link for the service i.e.

    cakephp-example-test.apps.example.com

What has just been demonstrated? The new app is deployed into a project with a node selector which requires the region label to be 'primary', this means the app gets deployed to either node1 or node2. The landrush DNS wild card entry for apps.example.com points to master1 which is where the router is running, therefore being able to render the home page of the app means that the SDN of Openshift is working properly with Vagrant.

Notes
-----

The landrush plugin creates a small DNS server to that the guest VMs can resolve each others hostnames and also the host can resolve the guest VMs hostnames. The landrush DNS server is listens on 127.0.0.1 on port 10053. It uses a dnsmasq process to redirect dns traffic to landrush. If this isn't working verify that:

    cat /etc/dnsmasq.d/vagrant-landrush

gives

    server=/example.com/127.0.0.1#10053

and that /etc/resolv.conf has an entry

    # Added by landrush, a vagrant plugin 
    nameserver 127.0.0.1
