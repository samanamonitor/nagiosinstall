#!/bin/bash

set -xe

. /etc/os-release

PNP4NAGIOS_URL=https://sourceforge.net/projects/pnp4nagios/files/latest

VERSION=1.0.0
PACKAGE_NAME=samm-pnp4nagios
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall

common_depends="libc6 (>= 2.15), samm, rrdtool, librrdtool-oo-perl, php-xml"

bionic_depends=${common_depends}

if [ "${UBUNTU_CODENAME}" == "bionic" ]; then
    DEPENDS=${bionic_depends}
else
    echo "Invalid OS." >&2
    exit 1
fi
CONFLICTS="samm-graphios"

DEV_PACKS="m4 gettext automake autoconf make gcc wget samm"

LIBS="php-xml"

PERL_LIBS="librrdtool-oo-perl"

TOOLS="rrdtool"

DEBIAN_FRONTEND="noninteractive" apt install -y $DEV_PACKS $LIBS $PERL_LIBS $TOOLS

if [ ! -d ${TEMPDIR} ]; then
    mkdir -p ${TEMPDIR}
fi

if [ ! -d ${TEMPDIR}/pnp4nagios ]; then
    mkdir -p /usr/src/build/pnp4nagios
    wget -O ${TEMPDIR}/pnp4nagios.latest.tar.gz ${PNP4NAGIOS_URL}
    tar --strip-components=1 -C ${TEMPDIR}/pnp4nagios -zxvf ${TEMPDIR}/pnp4nagios.latest.tar.gz

fi

cd ${TEMPDIR}/pnp4nagios
./configure --with-nagios-user=nagios --with-nagios-group=nagcmd  \
    --with-httpd-conf=/etc/apache2/sites-available \
    --prefix=${PREFIX}/pnp4nagios
make all
make fullinstall DESTDIR=${BUILD_DIR}
rm -f ${BUILD_DIR}/usr/local/pnp4nagios/share/install.php
patch ${BUILD_DIR}/usr/local/pnp4nagios/share/application/models/data.php /usr/src/nagiosinstall/pnp4nagios.patch

mkdir -p ${BUILD_DIR}/usr/share/samana
cat <<EOF > ${BUILD_DIR}/usr/share/samana/pnp4nagios_perfdata

###### Auto-generated PNP4Nagios configs #######
process_performance_data=1
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tSERVICEDESC::\$SERVICEDESC\$\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\tSERVICESTATE::\$SERVICESTATE\$\tSERVICESTATETYPE::\$SERVICESTATETYPE\$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-pnp4n-service-perfdata-file
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tHOSTPERFDATA::\$HOSTPERFDATA\$\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-pnp4n-host-perfdata-file
cfg_file=/usr/local/nagios/etc/objects/pnp4nagios.cfg
EOF

mkdir -p ${BUILD_DIR}/usr/local/nagios/etc/objects
cat <<EOF > ${BUILD_DIR}/usr/local/nagios/etc/objects/pnp4nagios.cfg
define command {
    command_name process-pnp4n-service-perfdata-file
    command_line /bin/mv /usr/local/pnp4nagios/var/service-perfdata /usr/local/pnp4nagios/var/spool/service-perfdata.\$TIMET\$
}

define command {
    command_name process-pnp4n-host-perfdata-file
    command_line /bin/mv /usr/local/pnp4nagios/var/host-perfdata /usr/local/pnp4nagios/var/spool/host-perfdata.\$TIMET\$
}
EOF

mkdir -p ${BUILD_DIR}/DEBIAN
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

cat <<EOF > ${BUILD_DIR}/DEBIAN/postinst
cat /usr/share/samana/pnp4nagios_perfdata >> /usr/local/nagios/etc/nagios.cfg
a2ensite --quiet pnp4nagios
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/postinst

dpkg --build ${BUILD_DIR}

mv ${BUILD_DIR}.deb ${DIR}
