#!/bin/bash



# wait for neutron to reconfigure and restart
echo "Configuring neutron-api"
juju ssh neutron-api/0 "sudo sed -i 's/dns_domain_ports/dns_domain_ports,subnet_dns_publish_fixed_ip/' /etc/neutron/plugins/ml2/ml2_conf.ini ; sudo service neutron-server restart"
sleep 30

export designate_bind_ip=10.246.118.192

source ~/openstack-bundles/stable/openstack-base/openrc
openstack zone create --email jdhiser@gmail.com shen.os.
openstack network set --dns-domain shen.os. ext_net
openstack subnet set --dns-publish-fixed-ip ext_subnet
openstack server create --image jammy-amd64 --flavor m1.small   --nic net-id=ext_net --key-name jdhKeyPair_admin --security-group Allow_SSH_admin dns-test
sleep 30s # long enough for the server to get an IP
openstack recordset list shen.os.
dig dns-test.shen.os @$designate_bind_ip
dig shen44.maas @$designate_bind_ip



echo "
Done setting up zones for mtx1.os.
If all went well, dig should show IP addresses for dns-test.mtx.os and mtx39.maas.

Recommend you change mtx1 settings to configure /etc/netplan/00-installer-config.yaml
to use $designate_bind_ip as a name server.
"
