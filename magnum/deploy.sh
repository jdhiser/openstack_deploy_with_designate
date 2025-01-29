

# deploy software
juju deploy magnum --channel 2023.1/stable --to lxd:5
juju deploy docker-registry --to lxd:6
juju deploy containerd 
juju deploy easyrsa --to lxd:7


# make relations
juju relate easyrsa docker-registry
juju relate docker-registry vault
juju relate containerd vault
juju relate docker-registry containerd
juju relate magnum rabbitmq-server
juju relate magnum vault
juju relate magnum keystone


# mysql router for magnum
juju deploy --channel 8.0/stable mysql-router magnum-mysql-router
juju relate magnum-mysql-router:db-router mysql-innodb-cluster:db-router
juju relate magnum-mysql-router:shared-db magnum:shared-db

# mysql router for easyrsa
juju deploy --channel 8.0/stable mysql-router easyrsa-mysql-router
juju relate easyrsa-mysql-router:db-router mysql-innodb-cluster:db-router
juju relate easyrsa-mysql-router easyrsa
