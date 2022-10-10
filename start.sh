#!/bin/bash

/etc/init.d/nagios start
/etc/init.d/apache2 start

/usr/local/pnp4nagios/bin/npcd -f /usr/local/pnp4nagios/etc/npcd.cfg &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start NPCD: $status"
  exit $status
fi

/bin/bash
