#!/bin/bash


# TODO: request credentials from user at install
# TODO: add proxy settings

set -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ ! -f $DIR/build_config.dat ]; then
    echo "Configuration file not found. Use config.dat.example as a base"
    exit 1
fi

. $DIR/build_config.dat

if [ "$CONFIG_TYPE" != "build" ]; then
    echo "Invalid config file. Use build_config.dat.example as a template."
    exit 1
fi

##############donwload and install Nagios################
build_nagios() {
    local TEMPDIR=$(mktemp -d)
    LIBS="wget apache2 build-essential libgd-dev unzip libapache2-mod-php libssl-dev"
    DEBIAN_FRONTEND="noninteractive" apt install -y $LIBS
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    wget -O ${TEMPDIR}/nagios.tar.gz ${NAGIOS_URL}
    mkdir -p ${TEMPDIR}/nagios
    cd ${TEMPDIR}
    tar --strip-components=1 -C nagios -zxvf nagios.tar.gz
    cd nagios
    ./configure --with-nagios-group=nagios \
        --with-command-group=nagcmd \
        --with-httpd-conf=${BUILD_DIR}/apache2/sites-available \
        --prefix=${BUILD_DIR}/nagios \
        --with-initdir=${BUILD_DIR}/nagios/etc/init.d \
        --with-cgiurl=/samm/cgi-bin \
        --with-htmurl=/samm
    sed -i '1634d' cgi/cgiutils.c
    make all 
    make install 
    make install-init
    make install-config
    make install-commandmode
    install -d -o root -g root ${BUILD_DIR}/apache2/sites-available/
    make install-webconf
    echo "RedirectMatch ^/$ /samm/" >> ${BUILD_DIR}/apache2/sites-available/nagios.conf
    cp -R contrib/eventhandlers/ ${BUILD_DIR}/nagios/libexec/
    install -o root -g root -m 0664 ${DIR}/nagiosweb/index.php ${BUILD_DIR}/nagios/share
    install -o root -g root -m 0664 ${DIR}/nagiosweb/main.php ${BUILD_DIR}/nagios/share
    install -o root -g root -m 0664 ${DIR}/nagiosweb/side.php ${BUILD_DIR}/nagios/share
    wget -O ${BUILD_DIR}/nagios/share/images/SamanaGroup.png \
        https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/SamanaGroup.png
    wget -O ${BUILD_DIR}/nagios/share/images/SAMM.png \
        https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/SAMM.png
    wget -O ${BUILD_DIR}/nagios/share/images/favicon.ico \
        https://s3.us-west-2.amazonaws.com/monitor.samanagroup.co/favicon.ico
    cp ${BUILD_DIR}/nagios/share/images/favicon.ico /var/www/html
    sed -i "s/^#enable_page_tour=1/enable_page_tour=0/" ${BUILD_DIR}/nagios/etc/cgi.cfg
}

##############Configure nagios pluginss################
build_nagios_plugins() {
    local TEMPDIR=$(mktemp -d)
    LIBS="libldap2-dev libkrb5-dev libssl-dev iputils-ping smbclient snmp \
        libdbi-dev libmysqlclient-dev libpq-dev dnsutils fping libnet-snmp-perl \
        libcrypt-x509-perl libdatetime-format-dateparse-perl libtext-glob-perl \
        libwww-perl ssh-client" # removed libfreeradius-client-dev for bionic
    apt install -y $LIBS
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    wget -O ${TEMPDIR}/nagios-plugins.tar.gz ${NAGIOS_PLUGINS_URL}
    mkdir -p ${TEMPDIR}/nagios-plugins
    cd ${TEMPDIR}
    tar --strip-components=1 -C nagios-plugins -zxvf nagios-plugins.tar.gz
    cd nagios-plugins
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd --enable-perl-modules \
        --prefix=${BUILD_DIR}/nagios
    make
    make install
    install -d -o root -g root ${BUILD_DIR}/apache2/sites-available/
    RABBIT_TEMP=$(mktemp -d)
    cd ${RABBIT_TEMP}
    git clone https://github.com/nagios-plugins-rabbitmq/nagios-plugins-rabbitmq
    install -o root -g root ${RABBIT_TEMP}/nagios-plugins-rabbitmq/scripts/* ${BUILD_DIR}/nagios/libexec
}

build_nagiosinstall() {
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    install -d -o root -g root ${BUILD_DIR}/snmp/mibs
    install -o root -g root ${DIR}/support/mibs/* ${BUILD_DIR}/snmp/mibs
    install -o root -g root ${DIR}/support/www/* /var/www/html
}

build_tarball() {
    tar -cvf apps.tar ${BUILD_DIR}/*
}

install_prereqs() {
    LIBS="apache2 libgd3 ssmtp libapache2-mod-php unzip libapache2-mod-wsgi-py3 \
        libldap-common libkrb5-3 libssl3 iputils-ping smbclient snmp \
        libdbi1 libmysqlclient21 libpq5 dnsutils fping libnet-snmp-perl \
        rrdtool librrdtool-oo-perl php-xml git ansible php-sybase \
        libhttp-request-ascgi-perl libnumber-format-perl \
        libconfig-inifiles-perl libdatetime-perl python-pip \
        python3 python3-urllib3 python3-smbc ceph-base sudo"
####### Following libraries are necessary for VMWare SDK - Disabled for now
#        libxml-libxml-perl libxml2-dev xml2 uuid-dev perl-doc rpm \
#        libsoap-lite-perl"
    apt update
    apt install -y $LIBS

    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} -d ${BUILD_DIR}/nagios nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
}

install_pywinrm() {
    LIBS="python3-winrm python3-etcd"
    apt update
    apt install -y $LIBS
}

install_nagios() {
    if [ ! -d ${BUILD_DIR}/nagios ]; then
        echo "Build directory missing from ${BUILD_DIR}/nagios"
        exit 1
    fi
    mv ${BUILD_DIR}/apache2/sites-available/nagios.conf /etc/apache2/sites-available
    /usr/bin/install -c -m 755 -o root -g root /usr/local/nagios/etc/init.d/nagios /etc/init.d/
    a2ensite nagios
    a2enmod rewrite
    a2enmod cgi
    a2enmod proxy
    a2enmod proxy_http
    htpasswd -b -c ${BUILD_DIR}/nagios/etc/htpasswd.users nagiosadmin "${SAMM_PWD}"
    chown nagios.nagios ${BUILD_DIR}/nagios/etc/htpasswd.users
    chmod 0640 ${BUILD_DIR}/nagios/etc/htpasswd.users
    ln -s ${BUILD_DIR}/nagios/etc /etc/nagios
    # Enable md4 on openssl for ntlm authentication
    sed -i -e '/default = default_sect/alegacy = legacy_sect\n' \
        -e '/\[default_sect\]/a activate = 1\n\n[legacy_sect]\nactivate = 1\n' \
        /etc/ssl/openssl.cnf
    ln -s /usr/bin/python2 /usr/bin/python
    pip2 install -t /usr/local/nagios/libexec/lib urllib3

}

install_graphios() {
    pip2 install Graphios
    mkdir -p ${BUILD_DIR}/nagios/var/spool/graphios
    mkdir -p ${BUILD_DIR}/nagios/etc/graphios
    mv /etc/graphios/graphios.cfg ${BUILD_DIR}/nagios/etc/graphios
    chown nagios.nagios ${BUILD_DIR}/nagios/etc/graphios
    ln -s ${BUILD_DIR}/nagios/etc/graphios/graphios.cfg /etc/graphios
    sed -i "/^cfg_dir=/etc/nagios/objects$/d" ${BUILD_DIR}/nagios/etc/nagios.cfg
}

install_check_samana() {
    local TEMPDIR
    TEMPDIR=$(mktemp -d)
    git clone https://github.com/samanamonitor/check_samana.git ${TEMPDIR}/check_samana
    make -C ${TEMPDIR}/check_samana
    make -C ${TEMPDIR}/check_samana install
    rm -Rf ${TEMPDIR}
}

install_mibs() {
    mv ${BUILD_DIR}/snmp/mibs/* /usr/share/snmp/mibs
    echo "mibs ALL" >> /etc/snmp/snmp.conf
}

install_pynag() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    git clone https://github.com/samanamonitor/pynag.git ${TEMPDIR}
    cd ${TEMPDIR}
    python3 setup.py build
    python3 setup.py install
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

install_check_mssql() {
    sed -i '/^;\s\+tds\s\+version/a tds version = 8.0' \
        /etc/freetds/freetds.conf
}

install_start() {
    install -o root -g root -m 0755 $DIR/start.sh /start.sh
}

install_cleanup() {
    apt clean
    rm $(find /var/lib/apt/lists/ -type f )
    > /var/log/alternatives.log
    > /var/log/bootstrap.log
    > /var/log/dmesg
    > /var/log/dpkg.log
    > /var/log/faillog
    > /var/log/fontconfig.log
    > /var/log/lastlog
    > /var/log/apt/history.log
    > /var/log/apt/term.log
}

USERID=$(id -u)
if [ "${USERID}" != "0" ]; then
    echo "Please run using sudo or as root"
    exit 1
fi

case $1 in
"installall")
    install_prereqs
    install_pywinrm
    install_nagios
    install_graphios
    install_check_samana
    install_mibs
    install_pynag
    install_check_mssql
    install_start
    install_cleanup
    ;;
"build_nagios")
    build_nagios
    ;;
"build_nagios_plugins")
    build_nagios_plugins
    ;;
"build_nagiosinstall")
    build_nagiosinstall
    ;;
"build_tarball")
    build_tarball
    ;;
"shell")
    /bin/bash
    ;;
*)
    ;;
esac
