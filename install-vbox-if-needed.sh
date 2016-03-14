#!/bin/bash
set +x
set +e
[[ $CHECK != "acceptance" ]] && exit 0
sudo apt-get update -q
sudo apt-get install -q virtualbox
sudo wget -nv https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1_x86_64.deb
sudo dpkg -i vagrant_1.8.1_x86_64.deb
