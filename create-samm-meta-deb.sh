#!/bin/bash

set -xe

. /etc/os-release

PREFIX=/usr/local
DIR=/usr/src/nagiosinstall

PACKAGE_NAME=samm-common
VERSION=1.0.0
ARCH=amd64

BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_${ARCH}
mkdir -p ${BUILD_DIR}/DEBIAN
cp debian/control ${BUILD_DIR}/DEBIAN/control

dpkg --build ${BUILD_DIR}

mkdir -p ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
