#!/bin/bash

set -xe

. /etc/os-release

GRAPHIOS_GIT=https://github.com/shawn-sterling/graphios.git

VERSION=1.0.0
PACKAGE_NAME=samm-graphios
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall
DEPENDS="samm"
CONFLICTS="samm-php4nagios"

DEBIAN_FRONTEND="noninteractive" apt install -y git python-setuptools
git clone ${GRAPHIOS_GIT} ${TEMPDIR}
cd ${TEMPDIR}
python setup.py build
python setup.py bdist

mkdir -p ${BUILD_DIR}/DEBIAN
tar -C ${BUILD_DIR} -xzvf ${TEMPDIR}/dist/graphios*.tar.gz
rm -Rf ${BUILD_DIR}/etc/init/
mkdir -p 
mkdir -p ${BUILD_DIR}${PREFIX}/nagios/var/spool/graphios

cat nagios/nagios_perfdata.cfg | sed 's|/var/spool/nagios|/usr/local/nagios/var/spool|' > \
    ${BUILD_DIR}/usr/share/graphios/nagios_perfdata.cfg
cat nagios/graphios_commands.cfg | sed 's|/var/spool/nagios|/usr/local/nagios/var/spool|' > \
    ${BUILD_DIR}/usr/local/nagios/etc/graphios_commands.cfg
chown nagios.nagios ${BUILD_DIR}/usr/local/nagios/etc/graphios_commands.cfg
cat <<EOF > ${BUILD_DIR}/usr/share/samana/graphite.conf.template
ProxyPass "/graphite" "http://%SAMM_IP%:8080/graphite"
ProxyPassReverse "/graphite" "http://%SAMM_IP%:8080/graphite"
EOF

cat <<EOF > ${BUILD_DIR}/DEBIAN/preinst
if grep -q "Auto-generated Graphios configs" /usr/local/nagios/etc/nagios.cfg; then
    echo "Graphios config already applied" >&2
    exit 1
fi
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/preinst

cat <<EOF > ${BUILD_DIR}/DEBIAN/postinst
cat ${DIR}/etc/graphios.cfg | sed -e "s/%SAMM_IP%/\${SAMM_IP}/" > ${BUILD_DIR}/etc/graphios/graphios.cfg
cat /usr/share/graphios/nagios_perfdata.cfg >> /usr/local/nagios/etc/nagios.cfg
echo "cfg_file=/usr/local/nagios/etc/graphios_commands.cfg" >> /usr/local/nagios/etc/nagios.cfg
cat /usr/share/samana/graphite.conf.template | \
    sed -e "s/%SAMM_IP%/\${SAMM_IP}/" > \
    /etc/apache2/conf-available/graphite.conf
a2enconf --quiet graphite
a2enmod --quiet proxy
a2enmod --quiet proxy_http
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/postinst

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

