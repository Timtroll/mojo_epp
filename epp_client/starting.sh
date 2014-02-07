#!/bin/bash

sudo -u troll
# swap off
# swapoff -a

#sudo -u troll
cd  /home/troll/epp/epp_client
#/usr/local/bin/hypnotoad /home/troll/betterknow/betterknow/script/better_ed &

perl /usr/local/bin/morbo script/epp_client reload --listen http://*:4000 &
exit 1;
#read -n 1
#perl /usr/local/bin/hypnotoad script/epp_client --listen http://*:4000 &
