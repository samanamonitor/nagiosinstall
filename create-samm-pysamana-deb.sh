#!/bin/bash

set -xe

. /etc/os-release

GIT_URL=https://github.com/samanamonitor/pysamana.git

PACKAGE_NAME=samm-pysamana
TEMPDIR=/usr/src/build
PREFIX=/usr/local
DIR=/usr/src/nagiosinstall
DEPENDS="python3-urllib3"
CONFLICTS=""

DEBIAN_FRONTEND="noninteractive" apt install -y git python3-setuptools
git clone ${GIT_URL} ${TEMPDIR}
cd ${TEMPDIR}

python3 setup.py build
python3 setup.py bdist

tarball=$(find /usr/src/build/dist -type f -name \*.tar.gz)
t=${tarball%.linux-x86_64.tar.gz}
VERSION=${t#*-}

BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
mkdir -p ${BUILD_DIR}/DEBIAN
tar -C ${BUILD_DIR} -xzvf ${tarball}

sed -e "s/%PACKAGE_NAME%/${PACKAGE_NAME}/" \
    -e "s/%VERSION%/${VERSION}/" \
    -e "s/%DEPENDS%/${DEPENDS}/" \
    -e "s/%CONFLICTS%/${CONFLICTS}/" debian/control \
    > ${BUILD_DIR}/DEBIAN/control

dpkg --build ${BUILD_DIR}

mkdir -p ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}