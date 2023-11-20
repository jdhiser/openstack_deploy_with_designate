# openstack_deploy_with_designate

Scripts used to deploy Openstack Antelope via Juju on the mega-techx1 cluster.


## Step 1:

Prepare maas, install juju according to these directions: https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/2023.1/install-juju.html

For mtx1, the openstack yaml files are included in `juju_init`.  You may need to change for your hardware, of course.

Of note, there are designate-specific settings in some of the yaml files:

```
netuon.yaml:
  enable-ml2-dns: true
  enable-ml2-port-security: true
  dns-domain: mtx1.os.
  reverse-dns-lookup: true
```

The `deploy.sh` script is designed to be pretty readable and in the order of the directions.  Read/edit first.  Then, run:

```
cd juju_init; ./deploys.h
```


This will take a while, a few hours maybe.

Sometimes apache2 fails to get the proper certificates and juju will report
"service not running that should be, apache2".

Use `./fix_apache.sh <unit name>`, e.g. `./fix_apache glance/0` to setup the certificates on that machine and reset it to working state.


At this point, openstack should be setup and working.  Juju should report all units are active/idle/ready.

## Step 2:  setup networking, etc. in openstack 

```
cd  openstack_init; ./test_os.sh
```

This will setup networking, a user, and a VM for both the admin user and non-admin user.  This is a sanity check that openstack works OK, but
also creates the public networking necessary to install designate.


## Step 3a:  Install designate.

Again, `deploy.sh` should be human readable.  Read it, edit config files, etc., then run:

```
cd designate_install; ./deploys.sh
```

Wait for juju to report that the new charms are installed and ready/active/idle.



## Step 3b:  Configure designate.

To configure designate to publish fixed ips on the public network to the designate-bind DNS server,
the neutron-api's ml2 plugin needs to be extended to use `subnet_dns_publish_fixed_ip`.  I cannot
find any configuration options supported by the juju charms to do this.  Thus, it is done
manually in `setup_zones.sh`.  Future runs of `juju config` on anything related to neutron is likely
to overwrite this config file, and you'll need to redo this manual integration point.

But, for now, you can configure it the first time with:

```
cd designate_install; ./setup_zones.sh
```

## Step 4:  configure your dns server to use designate-bind.


no scripts, just edit /etc/netplan/\*.yaml and make it right.

