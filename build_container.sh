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

install_pywinrm() {
    apt install -y python-pip
    pip install requests_ntlm
    pip install pywinrm
}

###  Install wmi
build_wmi() {
    # run the following commands on windows for winRM to be enabled
    # winrm quickconfig -transport:https
    LIBS="git build-essential autoconf python"
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    apt update
    apt install -y $LIBS
    git clone https://github.com/samanamonitor/wmi.git ${TEMPDIR}
    cd ${TEMPDIR}
    ulimit -n 100000 && make "CPP=gcc -E -ffreestanding"
    install -D ${TEMPDIR}/Samba/source/bin/wmic /opt/build/wmi/
}

install_wmi() {
    install /opt/build/wmi/wmic /usr/local/bin
}

##############donwload and install Nagios################
build_nagios() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="wget apache2 build-essential libgd-dev ssmtp unzip libapache2-mod-php"
    DEBIAN_FRONTEND="noninteractive" apt install -y $LIBS
    useradd -m nagios
    groupadd nagcmd
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    wget -P ${TEMPDIR} http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.2.0.tar.gz
    cd ${TEMPDIR}
    tar -zxvf nagios-4.2.0.tar.gz
    cd nagios-4.2.0
    ./configure --with-nagios-group=nagios \
        --with-command-group=nagcmd \
        --with-httpd-conf=/etc/apache2/sites-available
    make all 
    make install 
    make install-init
    make install-config
    make install-commandmode
    /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
    ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/
    cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
    /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
    a2enmod rewrite
    a2enmod cgi
    ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
    htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin Samana81.
    ln -s /usr/local/nagios/etc /etc/nagios
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

##############Configure nagios pluginss################
install_nagios_plugins() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="libldap2-dev libkrb5-dev libssl-dev iputils-ping smbclient snmp \
        libdbi-dev libmysqlclient-dev libpq-dev dnsutils fping libsnmp-perl" # removed libfreeradius-client-dev for bionic
    apt install -y $LIBS
    PERL_MM_USE_DEFAULT=1 cpan Net::SNMP
    wget -P ${TEMPDIR} http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
    cd ${TEMPDIR}
    tar zxvf nagios-plugins-2.1.2.tar.gz
    cd nagios-plugins-2.1.2
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios
    make
    make install
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

##############Configure pnp4nagios#####################
install_pnp4nagios() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="rrdtool librrdtool-oo-perl php-xml"
    apt install -y $LIBS
    wget "https://sourceforge.net/projects/pnp4nagios/files/latest" -O ${TEMPDIR}/pnp4nagios.latest.tar.gz
    cd ${TEMPDIR}
    tar zxvf pnp4nagios.latest.tar.gz
    cd pnp4nagios-0.6.26
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd  \
        --with-httpd-conf=/etc/apache2/sites-available
    make all
    make fullinstall

    # TODO: change configure to install apache files in the correct location
    #mv /etc/httpd/conf.d/pnp4nagios.conf /etc/apache2/sites-available/
    #rm -Rf /etc/httpd

    ln -s /etc/apache2/sites-available/pnp4nagios.conf /etc/apache2/sites-enabled/
    mv /usr/local/pnp4nagios/share/install.php /usr/local/pnp4nagios/share/install-old.php
    ln -s /etc/init.d/npcd /etc/rcS.d/S98npcd
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
    patch /usr/local/pnp4nagios/share/application/models/data.php $DIR/pnp4nagios.patch
}

install_check_samana() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="etcd python-etcd ansible"
    apt install -y $LIBS
    git clone https://github.com/samanamonitor/check_samana.git ${TEMPDIR}
    make -C ${TEMPDIR} install
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
    /etc/init.d/etcd start
    etcdctl setdir /samanamonitor/data
    etcdctl setdir /samanamonitor/config
    etcdctl set /samanamonitor/config/global \
        '{"eventminutes":10,"eventmax":11,"eventlevelmax":3,"eventlist":["System","Application"]}'
    etcdctl set /samanamonitor/config/storefront-example \
        '{"eventminutes":10,"eventmax":11,"eventlevelmax":3,"eventlist":["System","Application", "Citrix Delivery Services"]}'
    /etc/init.d/etcd stop

}

install_mibs() {
    cp $DIR/support/mibs/* /usr/share/snmp/mibs
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
    LIBS="php-sybase"
    apt install -y $LIBS
    install -o nagios -g nagios $DIR/support/check_mssql ${NAGIOS_LIBEXEC}
    sed -i '/^;\s\+tds\s\+version/a tds version = 8.0' \
        /etc/freetds/freetds.conf
}

install_slack_nagios() {
    cpan HTTP::Request
    cpan LWP::UserAgent
    cpan LWP::Protocol::https
    install -o nagios -g nagios -m 0755 $DIR/support/slack_nagios.pl ${NAGIOS_LIBEXEC}
}

install_check_wmi_plus() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    cpan Number::Format
    cpan Config::IniFiles
    #cpan Date::Time
    cpan DateTime

    git clone https://github.com/samanamonitor/check_wmi_plus.git ${TEMPDIR}
    install -o nagios -g nagios -m 0755 ${TEMPDIR}/check_wmi_plus_help.pl ${NAGIOS_LIBEXEC}
    install -o nagios -g nagios -m 0755 ${TEMPDIR}/check_wmi_plus.pl ${NAGIOS_LIBEXEC}
    install -o nagios -g nagios -m 0755 ${TEMPDIR}/check_wmi_plus.README.txt ${NAGIOS_LIBEXEC}
    cp -R ${TEMPDIR}/etc/check_wmi_plus ${NAGIOS_ETC}
    chown -R nagios.nagios ${NAGIOS_ETC}/check_wmi_plus
    cp ${NAGIOS_ETC}/check_wmi_plus/check_wmi_plus.conf.sample \
        ${NAGIOS_ETC}/check_wmi_plus/check_wmi_plus.conf
    sed -i -e "s|^\$base_dir=.*|\$base_dir='${NAGIOS_LIBEXEC}';|" \
        ${NAGIOS_ETC}/check_wmi_plus/check_wmi_plus.conf
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

docker_start() {
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
    mkdir -p ${LOGPATH}
    build_wmi
    install_pywinrm
    install_nagios
    install_nagios_plugins
    install_pnp4nagios
    install_check_samana
    install_mibs
    install_pynag
    install_check_mssql
    install_slack_nagios
    install_check_wmi_plus
    docker_start
    install_cleanup
    ;;
"wmi")
    build_wmi
    ;;
"pywinrm")
    install_pywinrm
    ;;
"nagios")
    install_nagios
    ;;
"nagios-plugins")
    install_nagios_plugins
    ;;
*)
    ;;
esac

