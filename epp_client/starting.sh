#!/bin/bash

#sudo -u troll
# swap off
# swapoff -a

#sudo -u troll
cd  /home/troll/mojo_epp/epp_auth
#/usr/local/bin/hypnotoad script/better_ed &
perl /usr/local/bin/morbo script/auth reload --listen http://*:5000 &
sleep 1

cd  /home/troll/mojo_epp/epp_client
perl /usr/local/bin/morbo script/epp_client reload --listen http://*:4000 &
exit 1
#read -n 1
#perl /usr/local/bin/hypnotoad script/epp_client --listen http://*:4000 &
