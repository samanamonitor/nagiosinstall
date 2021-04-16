#!/bin/bash

/usr/local/nagios/bin/nagios /etc/nagios/nagios.cfg &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start Nagios: $status"
  exit $status
fi

rm /run/apache2/apache2.pid
rm /run/etcd.pid

APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 /usr/sbin/apachectl -DFOREGROUND &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start Apache: $status"
  exit $status
fi

/usr/local/pnp4nagios/bin/npcd -f /usr/local/pnp4nagios/etc/npcd.cfg &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start NPCD: $status"
  exit $status
fi

ETCD_ADVERTISE_CLIENT_URLS=http://0.0.0.0:2379 ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379 ETCD_DATA_DIR="/var/lib/etcd/default" /usr/bin/etcd &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start ETCD: $status"
  exit $status
fi

/bin/bash
