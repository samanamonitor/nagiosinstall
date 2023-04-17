#!/bin/bash

set -xe

. /etc/os-release

GIT_URL=https://github.com/samanamonitor/pynag.git

PACKAGE_NAME=samm-pynag
TEMPDIR=/usr/src/build
PREFIX=/usr/local
DIR=/usr/src/nagiosinstall
DEPENDS="python3, python3-six, python3-chardet"
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

cat <<EOF > ${BUILD_DIR}/DEBIAN/control
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Maintainer: Samana <info@samanagroup.com>
Depends: ${DEPENDS}
Conflicts: ${CONFLICTS}
Architecture: amd64
Homepage: https://www.samanagroup.com
Description: Samana Advanced Monitoring and Management"
EOF

dpkg --build ${BUILD_DIR}

mkdir -p ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}