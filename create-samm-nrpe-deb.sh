#!/bin/bash

set -xe

. /etc/os-release

URL=https://github.com/NagiosEnterprises/nrpe/archive/nrpe-4.1.0.tar.gz

VERSION=1.0.0
PACKAGE_NAME=samm-nrpe
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall

DEPENDS="libssl1.1 (>= 1.1.0), samm"

DEV_PACKS="autoconf automake gcc libc6 libmcrypt-dev make libssl-dev wget openssl samm"

LIBS="libmcrypt-dev libssl-dev"

TOOLS=""

DEBIAN_FRONTEND="noninteractive" apt install -y $DEV_PACKS $LIBS $PERL_LIBS $TOOLS

if [ ! -d ${TEMPDIR} ]; then
    mkdir -p ${TEMPDIR}
fi

if [ ! -f ${TEMPDIR}/nrpe.tar.gz ]; then
    wget --no-check-certificate -O ${TEMPDIR}/nrpe.tar.gz ${URL}
    tar -C ${TEMPDIR} -xzf ${TEMPDIR}/nrpe.tar.gz
fi

cd ${TEMPDIR}/nrpe-nrpe-4.1.0
./configure --enable-command-args --enable-ssl --with-ssl-lib=/usr/lib/i386-linux-gnu/

make all
make install DESTDIR=${BUILD_DIR}

mkdir -p ${BUILD_DIR}/DEBIAN
cat <<EOF > ${BUILD_DIR}/DEBIAN/control
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Maintainer: Samana <info@samanagroup.com>
Depends: ${DEPENDS}
Architecture: amd64
Homepage: https://www.samanagroup.com
Description: NRPE plugin for SAMM. Samana Advanced Monitoring and Management"
EOF

dpkg --build ${BUILD_DIR}

mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
