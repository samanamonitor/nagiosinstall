#!/bin/sh

CONTAINER_NAME=nagiost1
lxc-stop -n ${CONTAINER_NAME}
lxc-destroy -n ${CONTAINER_NAME}
rm -f /etc/nginx/conf.d/${CONTAINER_NAME}.conf
systemctl restart nginx
