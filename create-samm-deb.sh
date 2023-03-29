#!/bin/bash

# TODO: use libssl1.1 for bionic and focal and libssl3 for jammy
# TODO: add add package to accept snmp traps
# TODO: add ansible?

set -xe

. /etc/os-release

NAGIOS_UID=5001
NAGIOS_GID=5001
NAGCMD_GID=5002
NAGIOS_URL=https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.8.tar.gz

VERSION=1.0.0
PACKAGE_NAME=samm
TEMPDIR=/usr/src/build
PREFIX=/usr/local
BUILD_DIR=/usr/src/${PACKAGE_NAME}-${VERSION}-1_amd64
DIR=/usr/src/nagiosinstall

if [ -z "${SAMM_PWD}" ]; then
    echo "Please define SAMM_PWD variable." >&2
    exit 1
fi

common_depends="libc6 (>= 2.15), apache2, libapache2-mod-php, libapache2-mod-wsgi-py3, ssmtp, python-pip, sudo"

bionic_depends="libssl1.1 (>= 1.1.0), ${common_depends}"

focal_depends="libssl1.1 (>= 1.1.0), ${common_depends}"

jammy_depends="libssl3 (>= 3.0), ${common_depends}"

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

LIBS="wget apache2 build-essential libgd-dev unzip libapache2-mod-php libssl-dev ssmtp"
DEBIAN_FRONTEND="noninteractive" apt install -y $LIBS

if [ ! -d ${TEMPDIR} ]; then
    mkdir -p ${TEMPDIR}
fi

if [ ! -f ${TEMPDIR}/nagios.tar.gz ]; then
    wget -O ${TEMPDIR}/nagios.tar.gz ${NAGIOS_URL}
fi

if [ ! -d ${TEMPDIR}/nagios ]; then
    mkdir -p ${TEMPDIR}/nagios
fi

if ! getent group nagios >/dev/null 2>&1; then
    echo "Creating group \"nagios\"."
    groupadd -g ${NAGIOS_GID} nagios
fi
if ! getent group nagcmd >/dev/null 2>&1; then
    echo "Creating group \"nagcmd\"."
    groupadd -g ${NAGCMD_GID} nagcmd
fi
if ! getent passwd nagios >/dev/null 2>&1; then
    echo "Creating user \"nagios\"."
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
fi

cd ${TEMPDIR}
tar --strip-components=1 -C nagios -zxvf nagios.tar.gz
cd nagios
./configure --with-nagios-group=nagios \
    --with-command-group=nagcmd \
    --prefix=${PREFIX}/nagios \
    --sysconfdir=${PREFIX}/nagios/etc \
    --libexecdir=${PREFIX}/nagios/libexec \
    --with-cgiurl=/samm/cgi-bin \
    --with-htmurl=/samm
sed -i '1634d' cgi/cgiutils.c
make install-groups-users
make all
make install DESTDIR=${BUILD_DIR}
make install-init DESTDIR=${BUILD_DIR}
make install-config DESTDIR=${BUILD_DIR}
make install-commandmode DESTDIR=${BUILD_DIR}
install -d -o root -g root ${BUILD_DIR}/etc/apache2/sites-available/
install -d -o root -g root ${BUILD_DIR}/etc/apache2/sites-enabled/
install -d -o root -g root ${BUILD_DIR}/etc/apache2/conf-available/
install -d -o root -g root ${BUILD_DIR}/etc/apache2/conf-enabled/
make install-webconf DESTDIR=${BUILD_DIR}
rm ${BUILD_DIR}/etc/apache2/sites-enabled/nagios.conf
install -d -o root -g root ${BUILD_DIR}/usr/share/samana
echo "RedirectMatch ^/$ /samm/" >> ${BUILD_DIR}/etc/apache2/sites-available/nagios.conf

cp -R ${TEMPDIR}/nagios/contrib/eventhandlers/ ${BUILD_DIR}${PREFIX}/nagios/libexec/
install -o root -g root -m 0664 ${DIR}/nagiosweb/index.php ${BUILD_DIR}${PREFIX}/nagios/share
install -o root -g root -m 0664 ${DIR}/nagiosweb/main.php ${BUILD_DIR}${PREFIX}/nagios/share
install -o root -g root -m 0664 ${DIR}/nagiosweb/side.php ${BUILD_DIR}${PREFIX}/nagios/share
install -o root -g root -m 0664 ${DIR}/nagiosweb/graph.html ${BUILD_DIR}${PREFIX}/nagios/share
install -o nagios -g nagios -m 0775 ${DIR}/nagiosweb/wsgi/rdp.py ${BUILD_DIR}${PREFIX}/nagios/sbin
install -o root -g root -m 0664 ${DIR}/nagiosweb/wsgi/rdp.conf ${BUILD_DIR}/etc/apache2/conf-available
wget -O ${BUILD_DIR}${PREFIX}/nagios/share/images/SamanaGroup.png \
    https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/SamanaGroup.png
wget -O ${BUILD_DIR}${PREFIX}/nagios/share/images/SAMM.png \
    https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/SAMM.png
wget -O ${BUILD_DIR}${PREFIX}/nagios/share/images/favicon.ico \
    https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/favicon.ico
wget -O ${BUILD_DIR}${PREFIX}/nagios/share/images/notes.gif \
    https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/notes.gif
install -d -o root -g root ${BUILD_DIR}/var/www/html
cp ${BUILD_DIR}${PREFIX}/nagios/share/images/favicon.ico ${BUILD_DIR}/var/www/html
sed -i "s/^#enable_page_tour=1/enable_page_tour=0/" ${BUILD_DIR}${PREFIX}/nagios/etc/cgi.cfg
sed -i -e "s/nagiosadmin/sammadmin/" ${BUILD_DIR}${PREFIX}/nagios/etc/cgi.cfg
install -o root -g root ${DIR}/etc/graphios.cfg ${BUILD_DIR}/usr/share/samana

install -d -o root -g root ${BUILD_DIR}/usr/share/snmp/mibs
install -o root -g root ${DIR}/support/mibs/* ${BUILD_DIR}/usr/share/snmp/mibs

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

cat <<EOF > ${BUILD_DIR}/DEBIAN/postinst
a2ensite --quiet nagios
a2enmod --quiet rewrite
a2enmod --quiet cgi
a2enconf --quiet rdp
htpasswd -b -c ${PREFIX}/nagios/etc/htpasswd.users sammadmin "${SAMM_PWD}"
chown nagios.nagios ${PREFIX}/nagios/etc/htpasswd.users
chmod 0640 ${PREFIX}/nagios/etc/htpasswd.users
ln -s ${PREFIX}/nagios/etc /etc/nagios
if [ ! -s /usr/bin/python ]; then
    ln -s /usr/bin/python2 /usr/bin/python
fi

sed -i "\|^cfg_dir=/etc/nagios/objects$|d" ${PREFIX}/nagios/etc/nagios.cfg
sed -i -e '/service_description\s\+SSH/a\    register        0' \
        ${PREFIX}/nagios/etc/objects/localhost.cfg
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/postinst

cat <<EOF > ${BUILD_DIR}/DEBIAN/preinst
if ! getent group nagios >/dev/null 2>&1; then
    echo "Creating group \"nagios\"."
    groupadd -g ${NAGIOS_GID} nagios
fi
if ! getent group nagcmd >/dev/null 2>&1; then
    echo "Creating group \"nagcmd\"."
    groupadd -g ${NAGCMD_GID} nagcmd
fi
if ! getent passwd nagios >/dev/null 2>&1; then
    echo "Creating user \"nagios\"."
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
fi
EOF
chmod 0755 ${BUILD_DIR}/DEBIAN/preinst

dpkg --build ${BUILD_DIR}

mv ${BUILD_DIR}.deb ${DIR}