#!/bin/bash

. ./functions

SAMMCONT=$1
ETCDCONT=$2
SFID=$3

usage() {
    echo $1 >&2
    echo "Usage: $0 <samm container name> <etcd container name> <storefront id>" >&2
    exit 1
}

if [ -z "${SAMMCONT}" ]; then
    usage "SAMM container name or id is mandatory."
fi

if [ -z "${ETCDCONT}" ]; then
    usage "etcd container name or id is mandatory."
fi

if [ -z "$SFID" ]; then
    usage "store front id is mandatory"
fi

ETCDIP=$(getetcdip ${ETCDCONT})

sample=$(etcdget /samanamonitor/config/storefront-example)
etcdset /samanamonitor/config/$SFID "${sample}"
