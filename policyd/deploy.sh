#!/bin/bash


sudo apt install zip -y
zip policyd-override.zip policyd.yaml
juju attach-resource neutron-api policyd-override=policyd-override.zip
juju config neutron-api use-policyd-override=true

