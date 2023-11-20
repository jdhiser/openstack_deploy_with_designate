#/bin/bash

main ()
{
	local mach="$1"
	juju ssh $mach '
		set -x
		missing_cert=$(journalctl -u apache2|grep apache|grep cert|cut -d'\\\'' -f2|head -1)
		existing_cert=$(ls /etc/apache2/ssl/*/cert*)
		sudo ln -s $existing_cert $missing_cert
		sudo ln -s $(echo "$existing_cert $missing_cert"|sed "s/cert/key/g")
		sudo reboot now
'
}

main "$@"
