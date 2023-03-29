#!/bin/bash

# TODO: add 

set -xe

. /etc/os-release

CHECK_SAMANA_GIT=https://github.com/samanamonitor/check_samana.git

VERSION=1.0.0
PACKAGE_NAME=samm-check-samana
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall
DEPENDS="samm, python3-urllib3, python3-smbc, ceph-base, freetds-common, python3-winrm, python3-etcd"

DEBIAN_FRONTEND="noninteractive" apt install -y git make samm
git clone ${CHECK_SAMANA_GIT} ${TEMPDIR}
cd ${TEMPDIR}
make install DESTDIR=${BUILD_DIR}
rm -f ${BUILD_DIR}${PREFIX}/nagios/etc/nagios.cfg

mkdir -p ${BUILD_DIR}/DEBIAN

cat <<EOF > ${BUILD_DIR}/DEBIAN/control
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Maintainer: Samana <info@samanagroup.com>
Depends: ${DEPENDS}
Architecture: amd64
Homepage: https://www.samanagroup.com
Description: Samana Advanced Monitoring and Management"
EOF

cat <<EOF > ${BUILD_DIR}/DEBIAN/preinst
if [ ! -f /etc/freetds/freetds.conf ]; then
    echo "Missing freetds-common package. Cannot continue"
fi
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/preinst

cat <<EOF > ${BUILD_DIR}/DEBIAN/postinst
if ! grep -q -e "^cfg_dir=${PREFIX}/nagios/etc/objects/samana" ${PREFIX}/nagios/etc/nagios.cfg; then
    echo "cfg_dir=${PREFIX}/nagios/etc/objects/samana" >> ${PREFIX}/nagios/etc/nagios.cfg
fi
if ! grep -q -e "^cfg_dir=${PREFIX}/nagios/etc/objects/environment" ${PREFIX}/nagios/etc/nagios.cfg; then
    echo "cfg_dir=${PREFIX}/nagios/etc/objects/environment" >> ${PREFIX}/nagios/etc/nagios.cfg
fi

sed -i '/^;\s\+tds\s\+version/a tds version = 8.0' \
    /etc/freetds/freetds.conf
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/postinst

dpkg --build ${BUILD_DIR}

mv ${BUILD_DIR}.deb ${DIR}
