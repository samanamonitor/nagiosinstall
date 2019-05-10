#!/bin/bash

set -x
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

NAGIOS=/usr/loca/nagios
NAGIOS_ETC=${NAGIOS}/etc
NAGIOS_BIN=${NAGIOS}/bin
NAGIOS_LIBEXEC=${NAGIOS}/libexec


###############Resize partitions##########################
resize_partition() {
    swapoff /dev/xvda5
    apt-get -y install parted
    mkdir /install_log
    (echo d; echo 5; echo d; echo 2; echo d; echo n; echo p; echo 1; echo 2048; echo +7.5G; echo n; echo p; echo 2; echo 15706112; echo 16750591; echo a; echo 1; echo t; echo 2; echo 82; echo w) | fdisk /dev/xvda
    partprobe
    resize2fs /dev/xvda1
    mkswap /dev/xvda2 >> /install_log/swaplog.log
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

    mkdir /tmp/install_log
    apt-get update
    apt-get install -y $INSTALL_PKGS >> /tmp/install_log/apt-get.log
    cpanm Number::Format
    cpanm Config::IniFiles
    cpam Date::Time
    cpanm DateTime
    (echo y; echo y; echo y) | sendmailconfig


    #curl -s https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    #bash -c "curl -s https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
    #apt-get update

}

###  Install wmi
install_wmi() {
    # run the following commands on windows for winRM to be enabled
    # winrm quickconfig -transport:https
    git clone https://github.com/samanamonitor/wmi.git
    cd wmi
    ulimit -n 100000 && make "CPP=gcc -E -ffreestanding" >> /tmp/install_log_wmi
    cp ${HOME}/bin/wmic /usr/local/bin/
    pip install --upgrade pywinrm
}


##############donwload and install Nagios################
install_nagios() {
    wget -P /tmp http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.2.0.tar.gz 
    useradd nagios
    groupadd nagcmd
    usermod -a -G nagcmd nagios
    usermod -a -G nagios,nagcmd www-data
    tar zxvf /tmp/nagios-4.2.0.tar.gz -C /tmp
    tar zxvf /tmp/nagios-plugins-2.1.2.tar.gz -C /tmp
    cd /tmp/nagios-4.2.0
    ./configure --with-nagios-group=nagios --with-command-group=nagcmd
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
}

##############Configure nagios pluginss################
install_nagios_plugins() {
    wget -P /tmp http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
    cd /tmp/nagios-plugins-2.1.2
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios
    make
    make install
}

##############Configure pnp4nagios#####################
install_pnp4nagios() {
    wget "https://sourceforge.net/projects/pnp4nagios/files/latest" -O /tmp/pnp4nagios.latest.tar.gz
    tar zxvf /tmp/pnp4nagios.latest.tar.gz -C /tmp
    cd /tmp/pnp4nagios-0.6.26
    ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd
    make all
    make fullinstall
    mv /etc/httpd/conf.d/pnp4nagios.conf /etc/apache2/sites-available/
    rm -Rf /etc/httpd
    ln -s /etc/apache2/sites-available/pnp4nagios.conf /etc/apache2/sites-enabled/
    mv /usr/local/pnp4nagios/share/install.php /usr/local/pnp4nagios/share/install-old.php
    ln -s /etc/init.d/npcd /etc/rcS.d/S98npcd
}

install_check_bw() {
    cp $DIR/support/check_bw.sh ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/check_bw.sh
}

install_check_samana() {
    git clone https://github.com/samanamonitor/check_samana.git
    cp check_samana/src/*.py ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/*.py
    chmod +x ${NAGIOS_LIBEXEC}/*.py
    mkdir ${NAGIOS_ETC}/check_samana
    cp check_samana/etc/config.json ${NAGIOS_ETC}
}

install_mibs() {
    # copy all the following MIBs to /usr/share/snmp/mibs
    #   NS-MIB-smiv2.txt 
    #   SDX-MIB-smiv2.txt 
    #   INET-ADDRESS-MIB.txt 
    #   IPV6-TC.txt 
    #   SNMPv2-SMI.txt 
    #   SNMPv2-TC.txt 
    #   SNMP-FRAMEWORK-MIB.txt
    #   SNMP-TARGET-MIB.txt
    #   SNMP-VIEW-BASED-ACM-MIB.txt

    #wget http://192.168.0.12/support/docs/snmp/HP-Openview/NS-MIB-smiv2.mib -O /usr/share/snmp/mibs/NS-MIB-smiv2.txt
    echo "mibs ALL" >> /etc/snmp/snmp.conf
}

install_pynag() {
    git clone https://github.com/samanamonitor/pynag.git
    cd pynag
    python setup.py build
    python setup.py install
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
    sed -i '/;^\s\+tds\s\+version/a    tds version = 8.0' \
        /etc/freetds/freetds.conf
}

install_slack_nagios() {
    cp $DIR/support/slack_nagios.pl ${NAGIOS_LIBEXEC}
    chown nagios.nagios ${NAGIOS_LIBEXEC}/slack_nagios.pl
    chmod +x ${NAGIOS_LIBEXEC}/slack_nagios.pl
}

install_check_wmi_plus() {
    git clone https://github.com/samanamonitor/check_wmi_plus.git
    cp $DIR/check_wmi_plus/check_wmi_plus_help.pl \
        $DIR/check_wmi_plus/check_wmi_plus.pl \
        $DIR/check_wmi_plus/check_wmi_plus.README.txt \
        ${NAGIOS_LIBEXEC}

    sed -i "s|my \$conf_file=.*|my \$conf_file='/etc/nagios/check_wmi_plus/check_wmi_plus.conf';|" \
        /usr/local/nagios/libexec/check_wmi_plus.pl

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
ExecReload=/bin/kill -HUP $MAINPID
EOF
}


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