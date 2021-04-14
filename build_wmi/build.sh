#!/bin/bash

# run the following commands on windows for winRM to be enabled
# winrm quickconfig -transport:https
LIBS="git build-essential autoconf python"
TEMPDIR=$(mktemp -d)
CURDIR=$(pwd)
apt update
apt install -y $LIBS
git clone https://github.com/samanamonitor/wmi.git ${TEMPDIR}
cd ${TEMPDIR}
ulimit -n 100000 && make "CPP=gcc -E -ffreestanding"
install ${TEMPDIR}/Samba/source/bin/wmic ${WMIC_PATH}/
cd ${CURDIR}
rm -Rf ${TEMPDIR}
