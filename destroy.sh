#!/bin/sh

die () {
   echo >&2 "USAGE: destroy.sh <container_name>"
   exit 1
}

[ "$#" -eq 1 ] || die 

CONTAINER_NAME=nagiost1
lxc-stop -n ${CONTAINER_NAME}
echo "Container ${CONTAINER_NAME} stopped."
lxc-destroy -n ${CONTAINER_NAME}
echo "Container ${CONTAINER_NAME} destroyed."
rm -f /etc/nginx/conf.d/${CONTAINER_NAME}.conf
echo "NGINX reconfigured."
systemctl restart nginx
echo "Finished removing ${CONTAINER_NAME}"
