#!/bin/bash

set -xe

. /etc/os-release

URL=https://s3-us-west-2.amazonaws.com/monitor.samanagroup.co/pywmi.so.gz

if [ -z "${URL}" ]; then
    echo "Invalid GIT URL."
    exit 1
fi

TEMPDIR=/usr/src/build
PREFIX=/usr/local
DIR=/usr/src/nagiosinstall

apt update
apt install -y wget

mkdir -p ${TEMPDIR}
wget -O ${TEMPDIR}/pywmi.so.gz ${URL}

PACKAGE_NAME=samm-pywmi
VERSION=0.0.1
ARCH=amd64

BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_${ARCH}
mkdir -p ${BUILD_DIR}/usr/local/lib/python3.6/dist-packages/
gunzip -c ${TEMPDIR}/pywmi.so.gz > ${BUILD_DIR}/usr/local/lib/python3.6/dist-packages/pywmi.so
mkdir -p ${BUILD_DIR}/DEBIAN
cat <<EOF > ${BUILD_DIR}/DEBIAN/control
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Maintainer: Samana <info@samanagroup.com>
Depends: python3, libjansson4, libpython3.6
Conflicts: 
Architecture: amd64
Homepage: https://www.samanagroup.com
Description: SAMM WinRM Python libraries. Samana Advanced Monitoring and Management
EOF

dpkg --build ${BUILD_DIR}

mkdir -p ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
