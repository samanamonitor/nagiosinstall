#!/bin/sh

die () {
   echo >&2 "USAGE: destroy.sh <container_name>"
   exit 1
}

[ "$#" -eq 1 ] || die 

CONTAINER_NAME=nagiost1
lxc-stop -n ${CONTAINER_NAME}
lxc-destroy -n ${CONTAINER_NAME}
rm -f /etc/nginx/conf.d/${CONTAINER_NAME}.conf
systemctl restart nginx
