#!/bin/bash

#sudo -u troll
# swap off
# swapoff -a

#sudo -u troll
cd /home/troll/epp/epp_auth/
#/usr/local/bin/hypnotoad /home/troll/betterknow/betterknow/script/better_ed &

#perl /usr/local/bin/morbo script/auth reload --listen http://*:5000 &
perl /usr/local/bin/hypnotoad script/auth &
exit 1;
#read -n 1
#perl /usr/local/bin/hypnotoad script/epp_client --listen http://*:4000 &
