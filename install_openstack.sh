#!/bin/bash

set -x
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

NAGIOS=/usr/local/nagios
NAGIOS_ETC=${NAGIOS}/etc
NAGIOS_BIN=${NAGIOS}/bin
NAGIOS_LIBEXEC=${NAGIOS}/libexec
LOGPATH=/tmp/install_log


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
        python-dev"

    mkdir -p ${LOGPATH}
    apt-get update >> ${LOGPATH}/prerequisites.log
    apt-get install -y $INSTALL_PKGS >> ${LOGPATH}/prerequisites.log
    cpanm Number::Format >> ${LOGPATH}/prerequisites.log
    cpanm Config::IniFiles >> ${LOGPATH}/prerequisites.log
    cpanm Date::Time >> ${LOGPATH}/prerequisites.log
    cpanm DateTime >> ${LOGPATH}/prerequisites.log
    (echo y; echo y; echo y) | sendmailconfig
    python -m easy_install --upgrade pyOpenSSL


    #curl -s https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    #bash -c "curl -s https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
    #apt-get update

}

###  Install wmi
install_wmi() {
    # run the following commands on windows for winRM to be enabled
    # winrm quickconfig -transport:https
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    git clone https://github.com/samanamonitor/wmi.git ${TEMPDIR}
    cd {TEMPDIR}
    ulimit -n 100000 && make "CPP=gcc -E -ffreestanding" >> ${LOGPATH}/install_wmi.log
    cp ${TEMPDIR}/bin/wmic /usr/local/bin/
    pip install --upgrade pywinrm >> ${LOGPATH}/install_wmi.log
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}


##############donwload and install Nagios################
install_nagios() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    wget -P ${TEMPDIR} http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.2.0.tar.gz
    useradd nagios
    groupadd nagcmd
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
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
    wget -P ${TEMPDIR} http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
    cd {TEMPDIR}
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
    wget "https://sourceforge.net/projects/pnp4nagios/files/latest" -O ${TEMPDIR}/pnp4nagios.latest.tar.gz
    cd ${TEMPDIR}
    tar zxvf pnp4nagios.latest.tar.gz
    cd pnp4nagios-0.6.26
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd  --with-httpd-conf=/etc/apache2/sites-available
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
}

install_check_bw() {
    cp $DIR/support/check_bw.sh ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/check_bw.sh
}

install_check_samana() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    git clone https://github.com/samanamonitor/check_samana.git ${TEMPDIR}
    cp ${TEMPDIR}/src/*.py ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/*.py
    chmod +x ${NAGIOS_LIBEXEC}/*.py
    mkdir ${NAGIOS_ETC}/check_samana
    cp check_samana/etc/config.json ${NAGIOS_ETC}
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
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
    cp $DIR/support/check_mssql ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/check_mssql
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
    cp $DIR/support/slack_nagios.pl ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/slack_nagios.pl
    chmod +x ${NAGIOS_LIBEXEC}/slack_nagios.pl
}

install_check_wmi_plus() {
    local TEMPDIR=$(mktemp -d)
    local CURDIR=$(pwd)
    git clone https://github.com/samanamonitor/check_wmi_plus.git ${TEMPDIR}
    cp ${TEMPDIR}/check_wmi_plus/check_wmi_plus_help.pl \
        ${TEMPDIR}/check_wmi_plus/check_wmi_plus.pl \
        ${TEMPDIR}/check_wmi_plus/check_wmi_plus.README.txt \
        ${NAGIOS_LIBEXEC}

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
    cd ${CURDIR}
    rm -Rf ${TEMPDIR}
}

USERID=$(id -u)
if [ "${USERID}" != "0" ]; then
    echo "Please run using sudo or as root"
    exit 1
fi

#resize_partition
install_prereqs
install_wmi
install_nagios
install_nagios_plugins
install_nagios_sysctl
install_pnp4nagios
install_check_bw
install_check_samana
install_mibs
install_pynag
install_check_mssql
install_slack_nagios
install_check_wmi_plus
install_nagios_base_config
install_nagios_config

systemctl daemon-reload
systemctl start nagios
systemctl reload apache2