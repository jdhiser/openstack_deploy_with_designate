#!/bin/bash


ip=$(juju status --format=yaml openstack-dashboard | grep public-address | awk '{print $2}' | head -1)
pass=$(juju exec --unit keystone/leader leader-get admin_passwd)

echo Login to "http://$ip/horizon"
echo "User name: admin"
echo "Password: $pass"
echo "Domain: admin_domain"

