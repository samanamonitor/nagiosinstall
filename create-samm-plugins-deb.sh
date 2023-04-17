#!/bin/bash

set -xe

. /etc/os-release

NP_VERSION=release-2.4.3
NP_GIT=https://github.com/nagios-plugins/nagios-plugins.git
NP_RABBITMQ_GIT=https://github.com/nagios-plugins-rabbitmq/nagios-plugins-rabbitmq

VERSION=1.0.0
PACKAGE_NAME=samm-plugins
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall

common_depends="libc6 (>= 2.15), samm, libldap-common, libkrb5-3, \
iputils-ping, smbclient, snmp, libdbi1, \
libpq5, dnsutils, fping, libnet-snmp-perl, libcrypt-x509-perl, \
libdatetime-format-dateparse-perl, libtext-glob-perl, \
libwww-perl, libmonitoring-plugin-perl, ssh-client, \
libjson-perl"

bionic_depends="libssl1.1 (>= 1.1.0), libmysqlclient20, ${common_depends}"

focal_depends="libssl1.1 (>= 1.1.0), libmysqlclient21, ${common_depends}"

jammy_depends="libssl3 (>= 3.0), libmysqlclient21, ${common_depends}"

if [ "${UBUNTU_CODENAME}" == "jammy" ]; then
    DEPENDS=${jammy_depends}
elif [ "${UBUNTU_CODENAME}" == "focal" ]; then
    DEPENDS=${focal_depends}
elif [ "${UBUNTU_CODENAME}" == "bionic" ]; then
    DEPENDS=${bionic_depends}
else
    echo "Invalid OS." >&2
    exit 1
fi

if [ -n "${SAMM_DEB}" ] && [ -f "${SAMM_DEB}" ]; then
    apt install -y -f ${SAMM_DEB}
fi

DEV_PACKS="m4 gettext automake autoconf make gcc git samm"

LIBS="libldap2-dev libkrb5-dev libssl-dev libdbi-dev \
        libmysqlclient-dev libpq-dev"

PERL_LIBS="libnet-snmp-perl libcrypt-x509-perl \
        libdatetime-format-dateparse-perl libtext-glob-perl \
        libwww-perl"

TOOLS="iputils-ping smbclient snmp \
        dnsutils fping ssh-client"

DEBIAN_FRONTEND="noninteractive" apt install -y $DEV_PACKS $LIBS $PERL_LIBS $TOOLS

if [ ! -d ${TEMPDIR} ]; then
    mkdir -p ${TEMPDIR}
fi

if [ ! -d ${TEMPDIR}/nagios-plugins ]; then
    git clone --branch ${NP_VERSION} ${NP_GIT} ${TEMPDIR}/nagios-plugins
fi

cd ${TEMPDIR}/nagios-plugins
./tools/setup
./configure --with-nagios-user=nagios --with-nagios-group=nagcmd --enable-perl-modules \
        --prefix=${PREFIX}/nagios --libexecdir=${PREFIX}/nagios/libexec \
        --sysconfdir=${PREFIX}/nagios/etc --with-cgiurl=/samm/cgi-bin

make
make install DESTDIR=${BUILD_DIR}
git clone ${NP_RABBITMQ_GIT} ${TEMPDIR}/np-rabbitmq
install -o nagios -g nagios -m 0755 ${TEMPDIR}/np-rabbitmq/scripts/* ${BUILD_DIR}${PREFIX}/nagios/libexec

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

dpkg --build ${BUILD_DIR}

mv /usr/src/${PACKAGE_NAME}*.deb ${DIR}/apt-repo/pool/main/${VERSION_CODENAME}
