juju deploy --to lxd:4 heat --channel 2023.1/stable





# no, this is what the router is for.
#juju relate mysql-innodb-cluster heat

juju relate rabbitmq-server heat
juju relate keystone heat
juju relate vault heat


juju deploy mysql-router heat-mysql-router  --channel 8.0/stable
juju relate heat:shared-db heat-mysql-router:shared-db
juju relate  heat-mysql-router mysql-innodb-cluster


juju run-action heat/0 domain-setup

#sudo apt-get install heat-api heat-api-cfn heat-engine

