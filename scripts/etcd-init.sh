#!/bin/bash

. ./functions

SAMMCONT=$1
ETCDCONT=$2

usage() {
    echo $1 >&2
    echo "Usage: $0 <samm container name> <etcd container name>" >&2
    exit 1
}

if [ -z "${SAMMCONT}" ]; then
    usage "SAMM container name or id is mandatory."
fi

if [ -z "${ETCDCONT}" ]; then
    usage "etcd container name or id is mandatory."
fi

ETCDIP=$(getetcdip ${ETCDCONT})

if [ -z "${ETCDIP}" ]; then
    echo "etcd container is wrong." >&2
    exit 1
fi

etcdset /samanamonitor/config/global \
    '{"eventminutes":10,"eventmax":11,"eventlevelmax":3,"eventlist":["System","Application"]}'
etcdset /samanamonitor/config/storefront-example \
    '{"eventminutes":10,"eventmax":11,"eventlevelmax":3,"eventlist":["System","Application", "Citrix Delivery Services"]}'
