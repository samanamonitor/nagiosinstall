#!/bin/bash

set -x 

LIBS="libldap2-dev libkrb5-dev libssl-dev libdbi-dev libmysqlclient-dev libpq-dev \
libldap2-dev libkrb5-dev libssl-dev libdbi-dev libmysqlclient-dev libpq-dev"

DEPS=""

packsfromdepends() {
    local dependlist=
}

finddepends() {
    local pack=$1
    local tempifs=$IFS
    IFS=","
    local depends=($(dpkg -s $pack | sed -n -e 's/^Depends: //p'))
    IFS=$tempifs
    for d in $(seq 0 ${#depends[@]}); do
        echo ${depends[$d]%% *}
    done
}

for l in ${LIBS}; do
    depends=$(finddepends $l)
    for d in ${depends}; do
        dependpack=${d%% *}
        if [[ ${dependpack} == *dev ]]; then
            finddepends ${dependpack}
        fi
        if [ "lib" = "${depends::3}" ]; then
            DEPS="$d, ${DEPS}"
        else
            finddepends $d
        fi
    done
done
echo $DEPS