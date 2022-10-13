#!/bin/bash

service nagios start
service apache2 start
service graphios start
tail -f /usr/local/nagios/var/nagios.log
