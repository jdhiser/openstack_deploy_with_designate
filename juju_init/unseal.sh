#!/bin/bash


main()
{
	local unseal_key=$1


	if [[ ! -e $unseal_key ]]
	then
		echo "Please specify an unseal key file (e.g., unseal-<date>.txt"
		exit 1
	fi

	
	export VAULT_ADDR="http://$(juju status|grep vault/0|awk '{print $5}'):8200"



	vault operator unseal $(cat $unseal_key |grep "Unseal Key 1" | cut -d: -f2)
	vault operator unseal $(cat $unseal_key |grep "Unseal Key 2" | cut -d: -f2)
	vault operator unseal $(cat $unseal_key |grep "Unseal Key 3" | cut -d: -f2)

	local token=$(cat $unseal_key |grep Token|cut -d: -f2)
	juju run-action vault/leader authorize-charm token=$(echo $token)

	exit 0


}

main "$@"
