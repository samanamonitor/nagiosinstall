#!/bin/bash

set -xe

. /etc/os-release

GIT_URL=$1

if [ -z "${GIT_URL}" ]; then
    echo "Invalid GIT URL."
    exit 1
fi

TEMPDIR=/usr/src/build
PREFIX=/usr/local
DIR=/usr/src/nagiosinstall

apt update
DEBIAN_FRONTEND="noninteractive" apt install -y git python3-setuptools
git clone ${GIT_URL} ${TEMPDIR}
cd ${TEMPDIR}

python3 setup.py build
python3 setup.py bdist

PACKAGE_NAME=$(cat debian/control | sed -n -e "s/^Package: *//p")
VERSION=$(cat debian/control | sed -n -e "s/^Version: *//p")
ARCH=$(cat debian/control | sed -n -e "s/Architecture: *//p")

tarballpath=$(find ${TEMPDIR}/dist -type f -name \*linux-x86_64.tar.gz)

BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_${ARCH}
mkdir -p ${BUILD_DIR}/DEBIAN
tar -C ${BUILD_DIR} -xzvf ${tarballpath}
cp ${TEMPDIR}/debian/control ${BUILD_DIR}/DEBIAN

dpkg --build ${BUILD_DIR}

mkdir -p ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
