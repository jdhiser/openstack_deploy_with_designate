#!/bin/bash

retry()
{
	local cmd="$@"
	local count=10

	echo "Sleeping 30s before: $cmd"
	sleep 30s

	while [[  $count -gt 0 ]] 
	do
		$cmd
		if [[ $? -eq 0 ]]
		then
			return	# exit function if success.
		fi
		count=$(expr $count - 1)
		sleep 5	# delay a bit
	done
	echo "Cannot run: '$cmd'"
	exit 1 # exit bash script (maybe?) if fail.
}

bootstrap()
{

	# probably don't need to re-run the cloud/maas config. and credentials.
	juju add-cloud --client -f maas-cloud.yaml maas-one
	juju add-credential --client -f maas-creds.yaml maas-one


	# start here.  bootstrap creates node 0.
	juju bootstrap --bootstrap-series=jammy --constraints tags=juju maas-one maas-controller
	# sleep 5m

	# create and switch to a model for deployment.
	juju add-model --config default-series=jammy openstack
	juju switch maas-controller:openstack

}

deploy_services()
{

	# deploy ceph-osd  to machines 0,1,2
	retry juju deploy -n 3 --channel quincy/stable --config ceph-osd.yaml --constraints tags=ceph ceph-osd

	# add machine 3
	retry juju add-machine

	# keep nova compute off the ceph/monitor nodes. mtx nodes are weak sauce.
	retry juju deploy -n 10 --channel 2023.1/stable --config nova-compute.yaml nova-compute

	# put mysql on 3 lightweight containers, sharing space with ceph
	retry juju deploy -n 3 --to lxd:0,lxd:1,lxd:2 --channel 8.0/stable mysql-innodb-cluster


	# setup "vault" for securely storing keys, etc.
	retry juju deploy --to lxd:3 --channel 1.8/stable vault
	retry juju deploy --channel 8.0/stable mysql-router vault-mysql-router
	juju relate vault-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate vault-mysql-router:shared-db vault:shared-db
	juju relate mysql-innodb-cluster:certificates vault:certificates



	# neutron
	retry juju deploy -n 3 --to lxd:0,lxd:1,lxd:2 --channel 23.03/stable ovn-central
	retry juju deploy --to lxd:1 --channel 2023.1/stable --config neutron.yaml neutron-api
	retry juju deploy --channel 2023.1/stable neutron-api-plugin-ovn
	retry juju deploy --channel 23.03/stable --config neutron.yaml ovn-chassis

	# neutron relations
	juju relate neutron-api-plugin-ovn:neutron-plugin neutron-api:neutron-plugin-api-subordinate
	juju relate neutron-api-plugin-ovn:ovsdb-cms ovn-central:ovsdb-cms
	juju relate ovn-chassis:ovsdb ovn-central:ovsdb
	juju relate ovn-chassis:nova-compute nova-compute:neutron-plugin
	juju relate neutron-api:certificates vault:certificates
	juju relate neutron-api-plugin-ovn:certificates vault:certificates
	juju relate ovn-central:certificates vault:certificates
	juju relate ovn-chassis:certificates vault:certificates

	# neutron api to cloud database 
	retry juju deploy --channel 8.0/stable mysql-router neutron-api-mysql-router
	juju relate neutron-api-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate neutron-api-mysql-router:shared-db neutron-api:shared-db



	# keystone
	retry juju deploy --to lxd:0 --channel 2023.1/stable keystone

	# Join keystone to the cloud database:
	retry juju deploy --channel 8.0/stable mysql-router keystone-mysql-router
	juju relate keystone-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate keystone-mysql-router:shared-db keystone:shared-db

	#Two additional relations can be added at this time:
	juju relate keystone:identity-service neutron-api:identity-service
	juju relate keystone:certificates vault:certificates



	# rabbitmq
	retry juju deploy --to lxd:2 --channel 3.9/stable rabbitmq-server

	#Two relations can be added at this time:
	juju relate rabbitmq-server:amqp neutron-api:amqp
	juju relate rabbitmq-server:amqp nova-compute:amqp

	# nova cloud controller
	retry juju deploy --to lxd:3 --channel 2023.1/stable --config ncc.yaml nova-cloud-controller

	# Join nova-cloud-controller to the cloud database:
	retry juju deploy --channel 8.0/stable mysql-router ncc-mysql-router
	juju relate ncc-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate ncc-mysql-router:shared-db nova-cloud-controller:shared-db

	#Five additional relations can be added at this time:

	juju relate nova-cloud-controller:identity-service keystone:identity-service
	juju relate nova-cloud-controller:amqp rabbitmq-server:amqp
	juju relate nova-cloud-controller:neutron-api neutron-api:neutron-api
	juju relate nova-cloud-controller:cloud-compute nova-compute:cloud-compute
	juju relate nova-cloud-controller:certificates vault:certificates



	#The placement application will be containerised on machine 3 with the placement charm. To deploy:
	retry juju deploy --to lxd:3 --channel 2023.1/stable placement

	# Join placement to the cloud database:
	retry juju deploy --channel 8.0/stable mysql-router placement-mysql-router
	juju relate placement-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate placement-mysql-router:shared-db placement:shared-db

	#Three additional relations can be added at this time:
	juju relate placement:identity-service keystone:identity-service
	juju relate placement:placement nova-cloud-controller:placement
	juju relate placement:certificates vault:certificates



	# dashboard
	retry juju deploy --to lxd:2 --channel 2023.1/stable openstack-dashboard

	#Join openstack-dashboard to the cloud database:
	retry juju deploy --channel 8.0/stable mysql-router dashboard-mysql-router
	juju relate dashboard-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate dashboard-mysql-router:shared-db openstack-dashboard:shared-db
	#Two additional relations are required:
	juju relate openstack-dashboard:identity-service keystone:identity-service
	juju relate openstack-dashboard:certificates vault:certificates


	#The glance application will be containerised on machine 3 with the glance charm. To deploy:
	retry juju deploy --to lxd:3 --channel 2023.1/stable glance

	#Join glance to the cloud database:
	retry juju deploy --channel 8.0/stable mysql-router glance-mysql-router
	juju relate glance-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate glance-mysql-router:shared-db glance:shared-db

	#Four additional relations can be added at this time:
	juju relate glance:image-service nova-cloud-controller:image-service
	juju relate glance:image-service nova-compute:image-service
	juju relate glance:identity-service keystone:identity-service
	juju relate glance:certificates vault:certificates

	# ceph monitor
	retry juju deploy -n 3 --to lxd:0,lxd:1,lxd:2 --channel quincy/stable --config ceph-mon.yaml ceph-mon

	#Three relations can be added at this time:
	juju relate ceph-mon:osd ceph-osd:mon
	juju relate ceph-mon:client nova-compute:ceph
	juju relate ceph-mon:client glance:ceph



	# cinder
	retry juju deploy --to lxd:1 --channel 2023.1/stable --config cinder.yaml cinder

	#Join cinder to the cloud database:
	retry juju deploy --channel 8.0/stable mysql-router cinder-mysql-router
	juju relate cinder-mysql-router:db-router mysql-innodb-cluster:db-router
	juju relate cinder-mysql-router:shared-db cinder:shared-db

	#Five additional relations can be added at this time:
	juju relate cinder:cinder-volume-service nova-cloud-controller:cinder-volume-service
	juju relate cinder:identity-service keystone:identity-service
	juju relate cinder:amqp rabbitmq-server:amqp
	juju relate cinder:image-service glance:image-service
	juju relate cinder:certificates vault:certificates

	#The above glance:image-service relation will enable Cinder to consume the Glance API (e.g. making Cinder able to perform volume snapshots of Glance images).
	#Like Glance, Cinder will use Ceph as its storage backend (hence block-device: None in the configuration file). This will be implemented via the cinder-ceph subordinate charm:

	retry juju deploy --channel 2023.1/stable cinder-ceph

	#Three relations need to be added:
	juju relate cinder-ceph:storage-backend cinder:storage-backend
	juju relate cinder-ceph:ceph ceph-mon:client
	juju relate cinder-ceph:ceph-access nova-compute:ceph-access

	# rados
	retry juju deploy --to lxd:0 --channel quincy/stable ceph-radosgw
	#A single relation is needed:
	juju relate ceph-radosgw:mon ceph-mon:radosgw

	# configure vnc access
	juju config nova-cloud-controller console-access-protocol=novnc

}

init_vault()
{
	# see https://opendev.org/openstack/charm-vault/src/branch/stable/1.8/src/README.md#post-deployment-tasks

	# wait for vault to be ready.
	while ! juju status|grep 'Vault needs to be initialized' > /dev/null
	do
		echo waiting for vault to be ready.
		sleep 5s
	done

	export VAULT_ADDR="http://$(juju status|grep vault/0|awk '{print $5}'):8200"
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ vault operator init -key-shares=5 -key-threshold=3
	init_output=$(vault operator init -key-shares=5 -key-threshold=3)
	echo "$init_output"
	key1=$(echo "$init_output"|grep "Key 1:"|awk '{print $4}')
	key2=$(echo "$init_output"|grep "Key 2:"|awk '{print $4}')
	key3=$(echo "$init_output"|grep "Key 3:"|awk '{print $4}')
	root_token=$(echo "$init_output"|grep "Root Token:"|awk '{print $4}')
	echo "Key1=$key1"
	echo "Key2=$key2"
	echo "Key3=$key3"
	echo "root_token=$root_token"

	#Unseal Key 1: FqWLp6r/UP8IvvjIqNV/4u1Nt0/Jb4Qz/DOydXwTzBNC
	#Unseal Key 2: i471YuplZ9ebAuwTzamG/smjLZSnV1CeRdoWaJU0Zr9X
	#Unseal Key 3: LaQWA1KVH5cwN7tyBQxUMVtyP8brX10+ddItNM3wsRr1
	#Unseal Key 4: yzyn9A/KuigxCdLBNk+fBCcedF+iaFDJMTVVGTAt74/Q
	#Unseal Key 5: 8txcaoQd+Z9Fj4ZLXDtmZc8OXY95D3gtv8yADinaepJG
	#
	#Initial Root Token: s.ouJyv8yo5XcHO0X4T3CoCku8
	#
	#Vault initialized with 5 key shares and a key threshold of 3. Please securely
	#distribute the key shares printed above. When the Vault is re-sealed,
	#restarted, or stopped, you must supply at least 3 of these keys to unseal it
	#before it can start servicing requests.
	#
	#Vault does not store the generated root key. Without at least 3 keys to
	#reconstruct the root key, Vault will remain permanently sealed!
	#
	#It is possible to generate new unseal keys, provided you have a quorum of
	#existing unseal keys shares. See "vault operator rekey" for more information.

	vault operator unseal $key1
	vault operator unseal $key2
	vault operator unseal $key3

	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ vault operator unseal  FqWLp6r/UP8IvvjIqNV/4u1Nt0/Jb4Qz/DOydXwTzBNC
	#Key                Value
	#---                -----
	#Seal Type          shamir
	#Initialized        true
	#Sealed             true
	#Total Shares       5
	#Threshold          3
	#Unseal Progress    1/3
	#Unseal Nonce       94391318-afef-9bdb-87f2-0bd8acdea74f
	#Version            1.8.8
	#Storage Type       mysql
	#HA Enabled         false
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ vault operator unseal  i471YuplZ9ebAuwTzamG/smjLZSnV1CeRdoWaJU0Zr9X
	#Key                Value
	#---                -----
	#Seal Type          shamir
	#Initialized        true
	#Sealed             true
	#Total Shares       5
	#Threshold          3
	#Unseal Progress    2/3
	#Unseal Nonce       94391318-afef-9bdb-87f2-0bd8acdea74f
	#Version            1.8.8
	#Storage Type       mysql
	#HA Enabled         false
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ vault operator unseal LaQWA1KVH5cwN7tyBQxUMVtyP8brX10+ddItNM3wsRr1
	#Key             Value
	#---             -----
	#Seal Type       shamir
	#Initialized     true
	#Sealed          false
	#Total Shares    5
	#Threshold       3
	#Version         1.8.8
	#Storage Type    mysql
	#Cluster Name    vault-cluster-ed327602
	#Cluster ID      6e3ab010-f3c4-c6ff-ed72-b44f2667f2f8
	#HA Enabled      false
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ export VAULT_TOKEN=s.ouJyv8yo5XcHO0X4T3CoCku8
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ vault token create -ttl=100m
	sleep 30s
	export VAULT_TOKEN="$root_token"
	vault_token=$(vault token create -ttl=100m)
	echo "$vault_token"

	juju_token=$( echo "$vault_token"|grep "^token "|awk '{print $2}' )
	echo juju_token=$juju_token

	#Key                  Value
	#---                  -----
	#token                s.pOMLN5YZqGpvDofeBsiVfxKD
	#token_accessor       m5GN7i8K1WZKzWIFANxjXT23
	#token_duration       1h40m
	#token_renewable      true
	#token_policies       ["root"]
	#identity_policies    []
	#policies             ["root"]
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ juju run vault/leader authorize-charm token=s.pOMLN5YZqGpvDofeBsiVfxKD
	juju_action=$(juju run vault/leader authorize-charm token=$juju_token)
	echo "$juju_action"
	sleep 30s

	#unit-vault-0:
	#  UnitId: vault/0
	#  id: "2"
	#  results:
	#    Stdout: |
	#      lxc
	#      active
	#  status: completed
	#  timing:
	#    completed: 2023-06-18 01:49:37 +0000 UTC
	#    enqueued: 2023-06-18 01:49:34 +0000 UTC
	#    started: 2023-06-18 01:49:35 +0000 UTC
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ juju run vault/leader generate-root-ca
	juju run vault/leader generate-root-ca
	#unit-vault-0:
	#  UnitId: vault/0
	#  id: "4"
	#  results:
	#    Stdout: |
	#      lxc
	#      active
	#      active
	#      active
	#      lxc
	#    output: |-
	#      -----BEGIN CERTIFICATE-----
	#      MIIDazCCAlOgAwIBAgIUIsRkjwiH8J+BvMfNvWejH9yN1w4wDQYJKoZIhvcNAQEL
	#      BQAwPTE7MDkGA1UEAxMyVmF1bHQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkg
	#      KGNoYXJtLXBraS1sb2NhbCkwHhcNMjMwNjE4MDE1MzM4WhcNMzMwNjE1MDA1NDA3
	#      WjA9MTswOQYDVQQDEzJWYXVsdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAo
	#      Y2hhcm0tcGtpLWxvY2FsKTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
	#      ANLTeknP5M8ANyP/d2Aw2Lil4XgyZHcfcSo+ocMjlFZiXgDttKlYE8Kbk4NEcHUu
	#      /9BC7eEAKMwi8jbSsN9LFEG9IreqpsAZ1U3P37HCVbiw0O5lKBwR1jBKMm9nw2vK
	#      x0e/G6S/mlY0fJ58Lh/wl6w/5Aj4BqP+CojunbPA1DHJqYIX6SqZacUKO1Q1Vjs2
	#      9xEQshf9if4pXK2xiUkDSL3jk2klyv3yfvPdP/CwLHELO4dNLaaGydR2McVpLgWE
	#      LR01eL4Y0Ab94iGM2b/+z67P6QTEZVrWbRwizLXXK2ij13hfflcUWdXbHi2h1x3Y
	#      EZCx+d5vA3ZoFAcWHUH5VokCAwEAAaNjMGEwDgYDVR0PAQH/BAQDAgEGMA8GA1Ud
	#      EwEB/wQFMAMBAf8wHQYDVR0OBBYEFDvHAVxVitGarPj+Uf0nb0GQnzdrMB8GA1Ud
	#      IwQYMBaAFDvHAVxVitGarPj+Uf0nb0GQnzdrMA0GCSqGSIb3DQEBCwUAA4IBAQBh
	#      vC14C8fyREPpNACT2mYo5ydkH3c264OvWqh40HGLCcwAknujln1fOWRHyBijp2qJ
	#      EdF7TYoMGgC85Lf+kZZJwz79zu893BEG6sSloZrykqLYdIxdLk59dTfuM1HqaK5H
	#      38eASWO56LR91VyEaMARhpUDo6pVSKJXoo4zaaAtMVzmHJuyJXs5QwhUvfxVz7aE
	#      xMq9aDlDTTaA/rNxp5UHnpGCD6rXCRyOrzw0tyoAkxOU2yqD9HeZ1ZOL2E97w3oP
	#      ePsXAmtSuSYWIbJJTyd9/U89FhnClYMuGZvdEfg0ly6UJ+NzufC/f8Ey4bQnhz+T
	#      ZqfsGyL4ONLJzG0wPvRA
	#      -----END CERTIFICATE-----
	#  status: completed
	#  timing:
	#    completed: 2023-06-18 01:54:19 +0000 UTC
	#    enqueued: 2023-06-18 01:54:05 +0000 UTC
	#    started: 2023-06-18 01:54:07 +0000 UTC


}




main()
{
	bootstrap
	deploy_services
	sleep 10m
	init_vault

#	retry juju add-unit nova-compute -n 17 # start 17 new machines


}

main "$@"
