#!/bin/bash



init_vault()
{
	# see https://opendev.org/openstack/charm-vault/src/branch/stable/1.8/src/README.md#post-deployment-tasks

	# wait for vault to be ready.
	while ! juju status|grep -e 'Vault needs to be initialized'  -e 'Unit is sealed' > /dev/null
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

	echo "$init_output" >> unseal_keys.txt

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
	echo "$vault_token" >> vault_token.txt

	#Key                  Value
	#---                  -----
	#token                s.pOMLN5YZqGpvDofeBsiVfxKD
	#token_accessor       m5GN7i8K1WZKzWIFANxjXT23
	#token_duration       1h40m
	#token_renewable      true
	#token_policies       ["root"]
	#identity_policies    []
	#policies             ["root"]
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ juju run --wait=5m vault/leader authorize-charm token=s.pOMLN5YZqGpvDofeBsiVfxKD
	juju_action=$(juju run --wait=5m vault/leader authorize-charm token=$juju_token)
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
	#jdh8d@shen-23:~/shen_openstack_deloy_antelope/juju_init$ juju run --wait=5m vault/leader generate-root-ca
	juju run --wait=5m vault/leader generate-root-ca
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
	init_vault
}

main "$@"
