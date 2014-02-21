#!/bin/bash

#sudo -u troll
# swap off
# swapoff -a

#sudo -u troll
cd /home/troll/mojo_epp/epp_robot
#/usr/local/bin/hypnotoad /home/troll/betterknow/betterknow/script/better_ed &

perl /usr/local/bin/morbo script/robot reload --listen http://*:6000 &
#perl /usr/local/bin/hypnotoad script/robot &
exit 1;
#read -n 1
#perl /usr/local/bin/hypnotoad script/epp_client --listen http://*:4000 &
