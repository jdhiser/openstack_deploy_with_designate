#!/bin/sh 

juju deploy designate-bind --to lxd:4 --channel 2023.1/stable --config designate-bind.yaml

juju deploy memcached --to lxd:4 --config memcached.yaml

juju deploy designate --to lxd:4 --channel 2023.1/stable --config designate.yaml

juju relate designate designate-bind
juju relate designate memcached
juju relate designate keystone
juju relate designate rabbitmq-server
juju relate designate neutron-api
juju relate designate vault


juju relate designate mysql-innodb-cluster

# trying this to link designate to already deployed mysql.
juju deploy mysql-router designate-mysql-router  --channel 8.0/stable
juju relate designate:shared-db designate-mysql-router:shared-db
juju relate  designate-mysql-router mysql-innodb-cluster



# enable reverse dns lookup 
juju config neutron-api reverse-dns-lookup=True
juju config neutron-api ipv4-ptr-zone-prefix-size=16


echo "
juju deploys completed.
Wait for containers to be ready, then run setup_zones.sh
"
