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

###############Resize partitions##########################
resize_partition() {
    swapoff /dev/xvda5
    apt-get -y install parted
    mkdir /install_log
    (echo d; echo 5; echo d; echo 2; echo d; echo n; echo p; echo 1; echo 2048; echo +7.5G; echo n; echo p; echo 2; echo 15706112; echo 16750591; echo a; echo 1; echo t; echo 2; echo 82; echo w) | fdisk /dev/xvda
    partprobe
    resize2fs /dev/xvda1
    mkswap /dev/xvda2 >> ${LOGPATH}/swaplog.log
    swapon /dev/xvda2
    sed -i '1d' /install_log/swaplog.log
    sed -i 's/^no label, //' /install_log/swaplog.log
    sed  -i '/UUID/s/$/ none            swap    sw              0       0/' /install_log/swaplog.log
    cp /etc/fstab /etc/fstab.bak
    sed -i '/xvda5/r /install_log/swaplog.log' /etc/fstab
    sed -i '12d' /etc/fstab
}

##############Install prerequisites packages##############
install_prereqs() {
    INSTALL_PKGS="apache2 \
        php \
        php-cgi \
        libapache2-mod-php \
        php-pear \
        php-mbstring \
        gcc \
        glibc-source \
        php-gd \
        libgd-dev \
        snmp \
        unzip \
        telnet \
        smbclient \
        rrdtool \
        librrdtool-oo-perl \
        cpanminus \
        python-winrm \
        sendmail \
        autoconf \
        mailutils \
        python-pip \
        bc \
        git \
        php-sybase \
        curl \
        apt-transport-https \
        libwww-perl \
        libcrypt-ssleay-perl \
        liblwp-protocol-https-perl \
        autoconf \
        make \
        libdatetime-perl \
        build-essential \
        g++ \
        python-dev \
        libssl-dev \
        python-openssl \
        libffi-dev"

    mkdir -p ${LOGPATH}
    apt-get update >> ${LOGPATH}/prerequisites.log
    apt-get install -y $INSTALL_PKGS >> ${LOGPATH}/prerequisites.log
    (echo y; echo y; echo y) | sendmailconfig
    pip install --upgrade pyOpenSSL
    #python -m easy_install --upgrade pyOpenSSL


    #curl -s https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    #bash -c "curl -s https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
    #apt-get update

}

install_pywinrm() {
    apt install -y python-winrm >> ${LOGPATH}/install_pywinrm.log
}

###  Install wmi
install_wmi() {
    # run the following commands on windows for winRM to be enabled
    # winrm quickconfig -transport:https
    LIBS="git build-essential autoconf python"
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    apt install -y $LIBS >> ${LOGPATH}/install_wmi.log
    git clone https://github.com/samanamonitor/wmi.git ${TEMPDIR}
    cd ${TEMPDIR}
    ulimit -n 100000 && make "CPP=gcc -E -ffreestanding" >> ${LOGPATH}/install_wmi.log
    install ${TEMPDIR}/Samba/source/bin/wmic ${WMIC_PATH}/
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}


##############donwload and install Nagios################
install_nagios() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="wget apache2 build-essential libgd-dev sendmail mailutils unzip libapache2-mod-php"
    apt install -y $LIBS
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
        --with-httpd-conf=/etc/apache2/sites-available >> ${LOGPATH}/install_nagios.log
    make all  >> ${LOGPATH}/install_nagios.log
    make install  >> ${LOGPATH}/install_nagios.log
    make install-init >> ${LOGPATH}/install_nagios.log
    make install-config >> ${LOGPATH}/install_nagios.log
    make install-commandmode >> ${LOGPATH}/install_nagios.log
    /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
    ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/
    cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
    /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg >> ${LOGPATH}/install_nagios.log
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
    LIBS="libfreeradius-client-dev libldap2-dev libkrb5-dev libssl-dev iputils-ping smbclient snmp \
        libdbi-dev libmysqlclient-dev libpq-dev dnsutils fping libsnmp-perl"
    apt install -y $LIBS
    PERL_MM_USE_DEFAULT=1 cpan Net::SNMP >> ${LOGPATH}/install_nagios.log
    wget -P ${TEMPDIR} http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
    cd ${TEMPDIR}
    tar zxvf nagios-plugins-2.1.2.tar.gz
    cd nagios-plugins-2.1.2
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios >> ${LOGPATH}/install_nagios.log
    make >> ${LOGPATH}/install_nagios.log
    make install >> ${LOGPATH}/install_nagios.log
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

##############Configure pnp4nagios#####################
install_pnp4nagios() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="rrdtool librrdtool-oo-perl"
    apt install -y $LIBS >> ${LOGPATH}/install_nagios.log
    wget "https://sourceforge.net/projects/pnp4nagios/files/latest" -O ${TEMPDIR}/pnp4nagios.latest.tar.gz
    cd ${TEMPDIR}
    tar zxvf pnp4nagios.latest.tar.gz
    cd pnp4nagios-0.6.26
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd  \
        --with-httpd-conf=/etc/apache2/sites-available >> ${LOGPATH}/install_nagios.log
    make all >> ${LOGPATH}/install_nagios.log
    make fullinstall >> ${LOGPATH}/install_nagios.log

    # TODO: change configure to install apache files in the correct location
    #mv /etc/httpd/conf.d/pnp4nagios.conf /etc/apache2/sites-available/
    #rm -Rf /etc/httpd

    ln -s /etc/apache2/sites-available/pnp4nagios.conf /etc/apache2/sites-enabled/
    mv /usr/local/pnp4nagios/share/install.php /usr/local/pnp4nagios/share/install-old.php
    ln -s /etc/init.d/npcd /etc/rcS.d/S98npcd
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

install_check_samana() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    LIBS="etcd python-etcd ansible"
    apt install -y $LIBS >> ${LOGPATH}/install_nagios.log
    git clone https://github.com/samanamonitor/check_samana.git ${TEMPDIR}
    make -C ${TEMPDIR} install
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
    cat <<EOF >> /etc/default/etcd
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
EOF
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
    apt install -y $LIBS >> ${LOGPATH}/install_check_mssql.log
    install -o nagios -g nagios $DIR/support/check_mssql ${NAGIOS_LIBEXEC}
    #ACCEPT_EULA=Y apt-get -y install msodbcsql17 mssql-tools
    #apt-get -y install unixodbc-dev
    #apt install -y php7.0-dev
    #pecl install sqlsrv-5.3.0
    #pecl install pdo_sqlsrv-5.3.0
    #cat <<EOF | tee /etc/php/7.0/mods-available/pdo_sqlsrv.ini
    #; configuration for php sqlite3 module
    #; priority=30
    #extension=pdo_sqlsrv.so
    #EOF
    #ln -s /etc/php/7.0/mods-available/pdo_sqlsrv.ini /etc/php/7.0/apache2/conf.d/20-pdo_sqlsrv.ini
    #ln -s /etc/php/7.0/mods-available/pdo_sqlsrv.ini /etc/php/7.0/cli/conf.d/20-pdo_sqlsrv.ini
    sed -i '/^;\s\+tds\s\+version/a tds version = 8.0' \
        /etc/freetds/freetds.conf
}

install_slack_nagios() {
    cpan HTTP::Request >> ${LOGPATH}/install_slack_nagios.log
    cpan LWP::UserAgent >> ${LOGPATH}/install_slack_nagios.log
    cpan LWP::Protocol::https >> ${LOGPATH}/install_slack_nagios.log
    install -o nagios -g nagios $DIR/support/slack_nagios.pl ${NAGIOS_LIBEXEC}
}

install_check_wmi_plus() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    cpan Number::Format >> ${LOGPATH}/install_check_wmi.log
    cpan Config::IniFiles >> ${LOGPATH}/install_check_wmi.log
    #cpan Date::Time
    cpan DateTime >> ${LOGPATH}/install_check_wmi.log

    git clone https://github.com/samanamonitor/check_wmi_plus.git ${TEMPDIR}
    install -o nagios -g nagios ${TEMPDIR}/check_wmi_plus_help.pl ${NAGIOS_LIBEXEC}
    install -o nagios -g nagios ${TEMPDIR}/check_wmi_plus.pl ${NAGIOS_LIBEXEC}
    install -o nagios -g nagios ${TEMPDIR}/check_wmi_plus.README.txt ${NAGIOS_LIBEXEC}
    cp -R ${TEMPDIR}/etc/check_wmi_plus ${NAGIOS_ETC}
    chown -R nagios.nagios ${NAGIOS_ETC}/check_wmi_plus
    cp ${NAGIOS_ETC}/check_wmi_plus/check_wmi_plus.conf.sample \
        ${NAGIOS_ETC}/check_wmi_plus/check_wmi_plus.conf
    sed -i -e "s|^\$base_dir=.*|\$base_dir='${NAGIOS_LIBEXEC}';|" \
        ${NAGIOS_ETC}/check_wmi_plus/check_wmi_plus.conf
    #sed -i "s|my \$conf_file=.*|my \$conf_file='/etc/nagios/check_wmi_plus/check_wmi_plus.conf';|" \
    #    ${NAGIOS_LIBEXEC}/check_wmi_plus.pl
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

install_nagios_sysctl() {
    cat <<EOF > /lib/systemd/system/nagios.service
[Unit]
Description=Nagios
BindTo=network.target


[Install]
WantedBy=multi-user.target

[Service]
User=nagios
Group=nagios
Type=simple
ExecStart=${NAGIOS_BIN}/nagios /etc/nagios/nagios.cfg
ExecReload=/bin/kill -HUP \$MAINPID
EOF
}

install_nagios_base_config() {
    mkdir -p /etc/nagios/objects/samana
    mkdir -p /etc/nagios/objects/environment
    cp -R etc/objects/samana/* /etc/nagios/objects/samana/
    cp -R etc/objects/environment/* /etc/nagios/objects/environment
    echo "cfg_dir=/etc/nagios/objects/samana" >> /etc/nagios/nagios.cfg
    echo "cfg_dir=/etc/nagios/objects/environment" >> /etc/nagios/nagios.cfg
    chown -R nagios.nagios /etc/nagios/objects/samana /etc/nagios/objects/environment
    chmod g+w /etc/nagios/objects/environment/* /etc/nagios/objects/samana/*
}

install_nagios_config() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    git clone https://github.com/samanamonitor/nagios-config.git ${TEMPDIR}
    cd ${TEMPDIR}
    apt install -y libapache2-mod-wsgi
    pip install flask
    mkdir -p /var/www/nagios_config/nagios_config
    mkdir -p /var/www/nagios_config/html
    cp -R nagios_config/* /var/www/nagios_config/nagios_config/
    cp -R html/* /var/www/nagios_config/html/
    cp nagios_config.wsgi /var/www/nagios_config/
    chown -R www-data.www-data /var/www/nagios_config
    cp etc/apache2/sites-available/nagios-config.conf /etc/apache2/sites-available/
    cd /etc/apache2/sites-enabled/
    ln -s ../sites-available/nagios-config.conf
    cp check_config.sh reload_config.sh /var/www/nagios_config
    chown nagios.nagios /var/www/nagios_config/check_config.sh
    chown root.root /var/www/nagios_config/reload_config.sh
    chmod u+s /var/www/nagios_config/check_config.sh /var/www/nagios_config/reload_config.sh
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

install_credentials() {
    cat <<EOF >> /etc/nagios/resource.cfg
# Sets \$USER3\$ for SNMP community
\$USER3\$=${NAGIOS_SNMP_COMMUNITY}

# NetScaler SNMPv3 user
#$USER4$=nagiosmonitor

# NETBIOS domain for multiple checks
\$USER6\$=${NAGIOS_NETBIOS_DOMAIN}

# WMI user for servers
\$USER7\$=${NAGIOS_WMI_USER}

# WMI user's password
\$USER8\$=${NAGIOS_WMI_PASSWORD}

# Path with authentication credentials for scripts
\$USER9\$=/etc/nagios/samananagios.pw
EOF
    cat <<EOF > /etc/nagios/samananagios.pw
username=${NAGIOS_WMI_USER}@${NAGIOS_FQDN_DOMAIN}
password=${NAGIOS_WMI_PASSWORD}
domain=
EOF
    chown nagios.nagios /etc/nagios/samananagios.pw
    chmod 660 /etc/nagios/samananagios.pw
}

docker_start() {
    cat <<EOF > /start.sh
#!/bin/bash

/usr/local/nagios/bin/nagios /etc/nagios/nagios.cfg &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start Nagios: $status"
  exit $status
fi

APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 /usr/sbin/apachectl -DFOREGROUND &

/usr/local/pnp4nagios/bin/npcd -f /usr/local/pnp4nagios/etc/npcd.cfg &

/usr/bin/etcd &

/bin/bash
EOF
}

install_cleanup() {
    echo "TODO:"
}

USERID=$(id -u)
if [ "${USERID}" != "0" ]; then
    echo "Please run using sudo or as root"
    exit 1
fi

case $1 in
"installall")
    mkdir -p ${LOGPATH}
    #resize_partition
    #install_prereqs
    install_wmi
    install_pywinrm
    install_nagios
    install_nagios_plugins
    #install_nagios_sysctl
    install_pnp4nagios
    install_check_samana
    install_mibs
    install_pynag
    install_check_mssql
    install_slack_nagios
    install_check_wmi_plus
    #install_nagios_config
    install_credentials
    docker_start
    install_cleanup
    ;;
*)
    ;;
esac

#systemctl daemon-reload
#systemctl start nagios
#systemctl reload apache2
