
for i in $(seq 5 15); do juju add-machine lxd:$i; done
juju deploy charmed-kubernetes --channel 1.28/stable --overlay ./kub-overlay.yaml  --trust
juju config calico ignore-loose-rpf=True

 #2051  juju remove-unit easyrsa/5
 #2052  juju remove-unit etcd/15
 #2053  juju remove-unit etcd/16
 #2054  juju remove-unit etcd/17
 #2055  juju remove-unit kubeapi-load-balancer/5
 #2056  juju remove-unit kubernetes-control-plane/10
 #2057  juju remove-unit kubernetes-control-plane/11
 #2058  juju remove-unit kubernetes-worker/15
 #2059  juju remove-unit kubernetes-worker/16
 #2060  juju remove-unit kubernetes-worker/17
 #2061  juju remove-machine $(seq 72 81)
 #2062  juju status
 #2063  juju add-unit kubernetes-control-plane --to 6/lxd/0
 #2064  juju add-unit easyrsa --to 7/lxd/0
 #2065  juju add-unit etcd --to 8/lxd/0
 #2066  juju add-unit etcd --to 9/lxd/0
 #2067  juju add-unit etcd --to 10/lxd/0
 #2068  juju add-unit kubeapi-load-balancer --to 11/lxd/0
 #2069  juju add-unit kubernetes-worker --to 12/lxd/0
 #2070  juju add-unit kubernetes-worker --to 13/lxd/0
 #2071  juju add-unit kubernetes-worker --to 14/lxd/0


 # fix "containerd-stress has wrong version" messages.
 for i in $(seq 0 4)
 do
 juju ssh containerd/$i sudo cp /usr/bin/containerd-stress /var/lib/juju/agents/unit-containerd-$i/charm/resources/containerd/amd64/bin/
 juju ssh containerd/0 sudo reboot now
done

juju deploy magnum --channel 2023.1/stable --to lxd:15
juju relate magnum keystone
juju relate magnum neutron-api
juju relate magnum glance
juju relate magnum heat
juju relate magnum rabbitmq-server

juju deploy --channel 8.0/stable mysql-router magnum-mysql-router
juju relate magnum-mysql-router:db-router mysql-innodb-cluster:db-router
juju relate magnum-mysql-router:shared-db magnum:shared-db

