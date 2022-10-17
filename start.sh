#!/bin/bash

service nagios start
sleep 5
service apache2 start
sleep 5
service graphios start
tail -f /usr/local/nagios/var/nagios.log
