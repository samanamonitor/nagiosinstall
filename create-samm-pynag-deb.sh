#!/bin/bash

set -xe

. /etc/os-release

PYNAG_GIT=https://github.com/samanamonitor/pynag.git

VERSION=1.0.0
PACKAGE_NAME=samm-pynag
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall
DEPENDS="python3, python3-six, python3-chardet"

DEBIAN_FRONTEND="noninteractive" apt install -y python3 git python3-setuptools
git clone ${PYNAG_GIT} ${TEMPDIR}
cd ${TEMPDIR}
python3 setup.py build
python3 setup.py bdist

mkdir -p ${BUILD_DIR}/DEBIAN
tar -C ${BUILD_DIR} -xzvf ${TEMPDIR}/dist/pynag*.tar.gz


cat <<EOF > ${BUILD_DIR}/DEBIAN/control
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Maintainer: Samana <info@samanagroup.com>
Depends: ${DEPENDS}
Architecture: amd64
Homepage: https://www.samanagroup.com
Description: Samana Advanced Monitoring and Management"
EOF

dpkg --build ${BUILD_DIR}

mv ${BUILD_DIR}.deb ${DIR}
