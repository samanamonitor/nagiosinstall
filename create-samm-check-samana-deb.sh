#!/bin/bash

# TODO: add 

set -xe

. /etc/os-release

apt update
apt upgrade -y

CHECK_SAMANA_GIT=https://github.com/samanamonitor/check_samana.git

PACKAGE_NAME=samm-check-samana
TEMPDIR=/usr/src/build
PREFIX=/usr/local
DIR=/usr/src/nagiosinstall

DEBIAN_FRONTEND="noninteractive" apt install -y git make samm
git clone ${CHECK_SAMANA_GIT} ${TEMPDIR}
cd ${TEMPDIR}

VERSION=$(cat version)
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64

make install DESTDIR=${BUILD_DIR}
rm -f ${BUILD_DIR}${PREFIX}/nagios/etc/nagios.cfg

mkdir -p ${BUILD_DIR}/DEBIAN
sed -e "s/%VERSION%/$VERSION/" debian/control.tmpl > ${BUILD_DIR}/DEBIAN/control
install -m 0755 -o root -g root debian/postinst ${BUILD_DIR}/DEBIAN/postinst

dpkg --build ${BUILD_DIR}

mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
