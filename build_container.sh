#!/bin/bash


# TODO: request credentials from user at install
# TODO: add proxy settings

set -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ ! -f $DIR/config.dat ]; then
    echo "Configuration file not found. Use config.dat.example as a base"
    exit 1
fi

. $DIR/config.dat

build_wmi() {
    # run the following commands on windows for winRM to be enabled
    # winrm quickconfig -transport:https
    LIBS="git build-essential autoconf python"
    local TEMPDIR=$(mktemp -d)
    apt update
    apt install -y $LIBS
    git clone https://github.com/samanamonitor/wmi.git ${TEMPDIR}
    cd ${TEMPDIR}
    ulimit -n 100000 && make "CPP=gcc -E -ffreestanding"
    install -d ${BUILD_DIR}/wmi/
    install -o root -g root -m 0755 ${TEMPDIR}/Samba/source/bin/wmic ${BUILD_DIR}/wmi/
}

##############donwload and install Nagios################
build_nagios() {
    local TEMPDIR=$(mktemp -d)
    LIBS="wget apache2 build-essential libgd-dev unzip libapache2-mod-php"
    DEBIAN_FRONTEND="noninteractive" apt install -y $LIBS
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    wget -P ${TEMPDIR} http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.2.0.tar.gz
    cd ${TEMPDIR}
    tar -zxvf nagios-4.2.0.tar.gz
    cd nagios-4.2.0
    ./configure --with-nagios-group=nagios \
        --with-command-group=nagcmd \
        --with-httpd-conf=${BUILD_DIR}/apache2/sites-available \
        --prefix=${BUILD_DIR}/nagios
    make all 
    make install 
    #make install-init
    make install-config
    make install-commandmode
    install -d -o root -g root ${BUILD_DIR}/apache2/sites-available/
    make install-webconf
    cp -R contrib/eventhandlers/ ${BUILD_DIR}/nagios/libexec/
}

##############Configure nagios pluginss################
build_nagios_plugins() {
    local TEMPDIR=$(mktemp -d)
    LIBS="libldap2-dev libkrb5-dev libssl-dev iputils-ping smbclient snmp \
        libdbi-dev libmysqlclient-dev libpq-dev dnsutils fping libnet-snmp-perl" # removed libfreeradius-client-dev for bionic
    apt install -y $LIBS
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    wget -P ${TEMPDIR} http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
    cd ${TEMPDIR}
    tar zxvf nagios-plugins-2.1.2.tar.gz
    cd nagios-plugins-2.1.2
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd --prefix=${BUILD_DIR}/nagios
    make
    make install
    install -d -o root -g root /opt/build/apache2/sites-available/
}

##############Configure pnp4nagios#####################
build_pnp4nagios() {
    local TEMPDIR=$(mktemp -d)
    LIBS="rrdtool librrdtool-oo-perl php-xml"
    apt install -y $LIBS
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    wget "https://sourceforge.net/projects/pnp4nagios/files/latest" -O ${TEMPDIR}/pnp4nagios.latest.tar.gz
    cd ${TEMPDIR}
    tar zxvf pnp4nagios.latest.tar.gz
    cd pnp4nagios-0.6.26
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd  \
        --with-httpd-conf=${BUILD_DIR}/apache2/sites-available \
        --prefix=${BUILD_DIR}/pnp4nagios
    make all
    make fullinstall

    mv ${BUILD_DIR}/pnp4nagios/share/install.php ${BUILD_DIR}/pnp4nagios/share/install-old.php
    patch ${BUILD_DIR}/pnp4nagios/share/application/models/data.php $DIR/pnp4nagios.patch
}

build_check_wmi_plus() {
    local TEMPDIR=$(mktemp -d)
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    git clone https://github.com/samanamonitor/check_wmi_plus.git ${TEMPDIR}
    install -o nagios -g nagcmd -m 0755 ${TEMPDIR}/check_wmi_plus_help.pl ${BUILD_DIR}/nagios/libexec
    install -o nagios -g nagcmd -m 0755 ${TEMPDIR}/check_wmi_plus.pl ${BUILD_DIR}/nagios/libexec
    install -o nagios -g nagcmd -m 0755 ${TEMPDIR}/check_wmi_plus.README.txt ${BUILD_DIR}/nagios/libexec
    install -d -o nagios -g nagcmd ${BUILD_DIR}/nagios/etc/check_wmi_plus
    cp -R ${TEMPDIR}/etc/check_wmi_plus/* ${BUILD_DIR}/nagios/etc

}

build_nagiosinstall() {
    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    install -o nagios -g nagcmd support/check_mssql ${BUILD_DIR}/nagios/libexec
    install -d -o root -g root ${BUILD_DIR}/snmp
    install -d -o root -g root ${BUILD_DIR}/snmp/mibs
    install -o root -g root support/mibs/* ${BUILD_DIR}/snmp/mibs
    install -o nagios -g nagcmd -m 0755 support/slack_nagios.pl ${BUILD_DIR}/nagios/libexec
}

build_tarball() {
    tar -cvf apps.tar ${BUILD_DIR}/*
}

install_prereqs() {
    LIBS="apache2 libgd3 ssmtp libapache2-mod-php unzip libapache2-mod-wsgi \
        libldap-2.4-2 libkrb5-3 libssl1.1 iputils-ping smbclient snmp \
        libdbi1 libmysqlclient20 libpq5 dnsutils fping libnet-snmp-perl \
        rrdtool librrdtool-oo-perl php-xml git ansible php-sybase \
        libhttp-request-ascgi-perl libnumber-format-perl \
        libconfig-inifiles-perl libdatetime-perl python-pip \
        python3 python3-urllib3"
    apt update
    apt install -y $LIBS

    groupadd -g ${NAGIOS_GID} nagios
    groupadd -g ${NAGCMD_GID} nagcmd
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
}

install_pywinrm() {
    # TODO: requesting tz info. Need to fix
    pip install requests_ntlm
    pip install pywinrm
}

install_wmi() {
    if [ ! -d ${BUILD_DIR}/wmi ]; then
        echo "Build directory missing from /opt/build/wmi"
        exit 1
    fi
    install ${BUILD_DIR}/wmi/wmic /usr/local/bin
}

install_nagios() {
    if [ ! -d /opt/build/nagios ]; then
        echo "Build directory missing from /opt/build/nagios"
        exit 1
    fi
    mv ${BUILD_DIR}/nagios /usr/local
    mv ${BUILD_DIR}/apache2/sites-available/nagios.conf /etc/apache2/sites-available
    a2ensite nagios
    a2enmod rewrite
    a2enmod cgi
    htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin Samana81.
    ln -s /usr/local/nagios/etc /etc/nagios
}

install_pnp4nagios() {
    mv ${BUILD_DIR}/pnp4nagios /usr/local
    mv ${BUILD_DIR}/apache2/sites-available/pnp4nagios.conf /etc/apache2/sites-available
    a2ensite pnp4nagios
}

install_check_samana() {
    git clone https://github.com/samanamonitor/check_samana.git /usr/src/nagiosinstall/check_samana
    make -C /usr/src/nagiosinstall/check_samana
    make -C /usr/src/nagiosinstall/check_samana install
    #etcdctl setdir /samanamonitor/data
    #etcdctl setdir /samanamonitor/config
    #etcdctl set /samanamonitor/config/global \
    #    '{"eventminutes":10,"eventmax":11,"eventlevelmax":3,"eventlist":["System","Application"]}'
    #etcdctl set /samanamonitor/config/storefront-example \
    #    '{"eventminutes":10,"eventmax":11,"eventlevelmax":3,"eventlist":["System","Application", "Citrix Delivery Services"]}'
    #/etc/init.d/etcd stop
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
    python setup.py build
    python setup.py install
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

install_check_mssql() {
    sed -i '/^;\s\+tds\s\+version/a tds version = 8.0' \
        /etc/freetds/freetds.conf
}

install_check_wmi_plus() {
    cp /usr/local/nagios/etc/check_wmi_plus.conf.sample \
        /usr/local/nagios/etc/check_wmi_plus.conf
    sed -i -e "s|^\$base_dir=.*|\$base_dir='/usr/local/nagios/libexec';|" \
        /usr/local/nagios/etc/check_wmi_plus.conf
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
    install_wmi
    install_nagios
    install_pnp4nagios
    install_check_samana
    install_mibs
    install_pynag
    install_check_mssql
    install_check_wmi_plus
    install_start
    install_cleanup
    ;;
"build_wmi")
    build_wmi
    ;;
"build_nagios")
    build_nagios
    ;;
"build_nagios_plugins")
    build_nagios_plugins
    ;;
"build_pnp4nagios")
    build_pnp4nagios
    ;;
"build_check_wmi_plus")
    build_check_wmi_plus
    ;;
"build_nagiosinstall")
    build_nagiosinstall
    ;;
"build_tarball")
    build_tarball
    ;;
*)
    ;;
esac

