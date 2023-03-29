#!/bin/bash

RETRIES=2

rm -f /run/nagios.lock /run/apache2/apache2.pid /run/sammworker_process.pid
r=$RETRIES
while [ $r -gt 0 ]; do
    service nagios start
    sleep 5
    if [ -f /run/nagios.lock ]; then
        break
    else
        echo "Retrying Nagios..."
        r=$(( $r - 1 ))
    fi
    if [ "$r" == "0" ]; then
        echo "Nagios didn't start. Abort" >&2
        exit 1
    fi
done

r=$RETRIES
while [ $r -gt 0 ]; do
    service apache2 start
    sleep 5
    if [ -f /run/apache2/apache2.pid ]; then
        break
    else
        echo "Retrying Apache..."
        r=$(( $r - 1 ))
    fi
    if [ "$r" == "0" ]; then
        echo "Apache didn't start. Abort" >&2
        exit 1
    fi
done

if dpkg-query --status samm-pnp4nagios >/dev/null 2>&1; then
    service npcd start
fi

if dpkg-query --status samm-graphios >/dev/null 2>&1; then
    service graphios start
fi

#sleep 5
#
#if [ -x /usr/local/nagios/libexec/sammworker.py ]; then
#    /usr/local/nagios/libexec/sammworker.py
#    sleep 5
#    if [ ! -f /run/sammworker_process.pid ]; then
#        echo "SAMM Worker didn't start. Continuing." >&2
#    fi
#fi

tail -f /usr/local/nagios/var/nagios.log