#!/bin/bash

main()
{

	source ~/openstack-bundles/stable/openstack-base/openrc
	openstack image create --public --container-format bare --disk-format qcow2 --file ~/cloud-images/jammy-amd64.img jammy-amd64
	openstack image create --public --container-format bare --disk-format qcow2 --file ~/cloud-images/cirros-0.6.2-x86_64-disk.img cirros-amd64
	openstack flavor create --ram 2048 --disk 20 --ephemeral 20 m1.small
	openstack network create --external --share --provider-network-type flat --provider-physical-network physnet1 ext_net
	# OS recommendation
	# openstack subnet create --network ext_net --no-dhcp --gateway 10.246.112.3 --subnet-range 10.246.112.0/21 --allocation-pool start=10.246.114.0,end=10.246.115.255 ext_subnet
	# but this works:  note add dhcp and dns resolution
	openstack subnet create --dhcp --network ext_net  --dns-nameserver 10.246.112.3 --gateway 10.246.112.3 --subnet-range 10.246.112.0/21 --allocation-pool start=10.246.114.0,end=10.246.115.255 ext_subnet
	openstack keypair create --public-key ~jdh8d/.ssh/id_rsa.pub jdhKeyPair_admin
	openstack security group create --description 'Allow SSH' Allow_SSH_admin
	openstack security group rule create --proto tcp --dst-port 22 Allow_SSH_admin
	openstack security group create --description 'Allow ICMP' Allow_ICMP_admin
	openstack security group rule create --proto icmp Allow_ICMP_admin
#	openstack server create --image jammy-amd64  --flavor m1.small --key-name jdhKeyPair_admin --network ext_net --security-group Allow_SSH_admin --security-group Allow_ICMP_admin jammy-1
#	openstack server create --image jammy-amd64  --flavor m1.small --key-name jdhKeyPair_admin --network ext_net --security-group Allow_SSH_admin --security-group Allow_ICMP_admin jammy-2
	openstack server create --image cirros-amd64 --flavor m1.small --key-name jdhKeyPair_admin --network ext_net --security-group Allow_SSH_admin --security-group Allow_ICMP_admin cirros-1
#	openstack server create --image cirros-amd64 --flavor m1.small --key-name jdhKeyPair_admin --network ext_net --security-group Allow_SSH_admin --security-group Allow_ICMP_admin cirros-2

	openstack domain create domain1
	openstack project create --domain domain1 project1
	userinfo=$(openstack user create --domain domain1 --project project1 --password password1 user1)
	user_id=$(echo "$userinfo"|grep \ id|cut -f3 -d\|)
	openstack role add --user $user_id  --project project1 Member

	echo "
export OS_AUTH_URL=$OS_AUTH_URL
export OS_USER_DOMAIN_NAME=domain1
export OS_USERNAME=user1
export OS_PROJECT_DOMAIN_NAME=domain1
export OS_PROJECT_NAME=project1
export OS_PASSWORD=password1
export OS_CACERT=/home/jdh8d/snap/openstackclients/common/root-ca.crt
export OS_AUTH_VERSION=3
export OS_AUTH_PROTOCOL=https
" > project1-rc

	source project1-rc
	openstack network create --internal user1_net

	openstack subnet create --network user1_net --dns-nameserver 10.246.112.3 \
	   --subnet-range 192.168.0/24 \
	   --allocation-pool start=192.168.0.10,end=192.168.0.99 \
	   user1_subnet

	openstack router create user1_router
	openstack router add subnet user1_router user1_subnet
	openstack router set user1_router --external-gateway ext_net


	openstack security group create --description 'Allow SSH' Allow_SSH
	openstack security group rule create --proto tcp --dst-port 22 Allow_SSH
	openstack security group create --description 'Allow ICMP' Allow_ICMP
	openstack security group rule create --proto icmp Allow_ICMP

	openstack keypair create --public-key ~jdh8d/.ssh/id_rsa.pub jdhKeyPair


#	openstack server create --image jammy-amd64  --flavor m1.small --key-name jdhKeyPair --network user1_net --security-group Allow_SSH --security-group Allow_ICMP jammy-3
#	FLOATING_IP=$(openstack floating ip create -f value -c floating_ip_address ext_net)
#	openstack server add floating ip jammy-3 $FLOATING_IP
#	openstack server create --image jammy-amd64  --flavor m1.small --key-name jdhKeyPair --network user1_net --security-group Allow_SSH --security-group Allow_ICMP jammy-4
#	FLOATING_IP=$(openstack floating ip create -f value -c floating_ip_address ext_net)
#	openstack server add floating ip jammy-4 $FLOATING_IP
#	openstack server create --image cirros-amd64 --flavor m1.small --key-name jdhKeyPair --network user1_net --security-group Allow_SSH --security-group Allow_ICMP cirros-3
#	FLOATING_IP=$(openstack floating ip create -f value -c floating_ip_address ext_net)
#	openstack server add floating ip cirros-3 $FLOATING_IP
	openstack server create --image cirros-amd64 --flavor m1.small --key-name jdhKeyPair --network user1_net --security-group Allow_SSH --security-group Allow_ICMP cirros-4
	FLOATING_IP=$(openstack floating ip create -f value -c floating_ip_address ext_net)
	openstack server add floating ip cirros-4 $FLOATING_IP





}

main "$@"
