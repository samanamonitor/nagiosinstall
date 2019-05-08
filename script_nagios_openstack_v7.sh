#!/bin/bash
###############Resize partitions##########################
sudo swapoff /dev/xvda5
sudo apt-get -y install parted
sudo mkdir /install_log
(echo d; echo 5; echo d; echo 2; echo d; echo n; echo p; echo 1; echo 2048; echo +7.5G; echo n; echo p; echo 2; echo 15706112; echo 16750591; echo a; echo 1; echo t; echo 2; echo 82; echo w) | sudo fdisk /dev/xvda
sudo partprobe
sudo resize2fs /dev/xvda1
sudo mkswap /dev/xvda2 >> /install_log/swaplog.log
sudo swapon /dev/xvda2 
sudo sed -i '1d' /install_log/swaplog.log
sudo sed -i 's/^no label, //' /install_log/swaplog.log
sudo sed  -i '/UUID/s/$/ none            swap    sw              0       0/' /install_log/swaplog.log
cp /etc/fstab /etc/fstab.bak
sudo sed -i '/xvda5/r /install_log/swaplog.log' /etc/fstab
sudo sed -i '12d' /etc/fstab
##############Install prerequisites packages##############
sudo apt-get update
INSTALL_PKGS="apache2 php php-cgi libapache2-mod-php php-pear php-mbstring gcc glibc-source php-gd libgd-dev snmp unzip telnet smbclient rrdtool librrdtool-oo-perl cpanminus python-winrm sendmail autoconf mailutils python-pip bc"
for i in $INSTALL_PKGS; do
  sudo apt-get install -y $i >> /install_log/apt-get.log
done
sudo cpanm Number::Format
sudo cpanm Config::IniFiles
sudo cpam Date::Time
sudo cpanm DateTime
(echo y; echo y; echo y) | sudo sendmailconfig
sudo wget -P /tmp https://www.edcint.co.nz/checkwmiplus/wmi-1.3.14.tar.gz
sudo wget -P /tmp https://assets.nagios.com/downloads/nagiosxi/agents/wmi-1.3.14.tar.gz
sudo wget -P /tmp http://www.openvas.org/download/wmi/openvas-wmi-1.3.14.patch
sudo wget -P /tmp http://www.openvas.org/download/wmi/openvas-wmi-1.3.14.patch2
sudo wget -P /tmp http://www.openvas.org/download/wmi/openvas-wmi-1.3.14.patch3v2
sudo wget -P /tmp http://www.openvas.org/download/wmi/openvas-wmi-1.3.14.patch4
sudo wget -P /tmp http://www.openvas.org/download/wmi/openvas-wmi-1.3.14.patch5
sudo tar xvf /tmp/wmi-1.3.14.tar.bz2 -C /tmp
cd /tmp/wmi-1.3.14/
sudo patch -p1 < /tmp/openvas-wmi-1.3.14.patch
sudo patch -p1 < /tmp/openvas-wmi-1.3.14.patch2
sudo patch -p1 < /tmp/openvas-wmi-1.3.14.patch3v2
sudo patch -p1 < /tmp/openvas-wmi-1.3.14.patch4
sudo patch -p1 < /tmp/openvas-wmi-1.3.14.patch5
sudo sed -i '13i\ZENHOME=$(HOME)' /tmp/wmi-1.3.14/GNUmakefile
sudo sed -i '583d' /tmp/wmi-1.3.14/Samba/source/pidl/pidl
sudo sed -i '508s/gnutls_transport_set_lowat(tls->session, 0);/gnutls_record_check_pending(tls->session);/' /tmp/wmi-1.3.14/Samba/source/lib/tls/tls.c
sudo sed -i '587s/gnutls_transport_set_lowat(tls->session, 0);/gnutls_record_check_pending(tls->session);/' /tmp/wmi-1.3.14/Samba/source/lib/tls/tls.c
sudo sed -i '579d' /tmp/wmi-1.3.14/Samba/source/lib/tls/tls.c
sudo make "CPP=gcc -E -ffreestanding" >> /install_log/wmi.log
sudo cp Samba/source/bin/wmic /usr/local/bin/
pip install --upgrade pywinrm
##############donwload and install Nagios################
sudo wget -P /tmp http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.2.0.tar.gz 
sudo wget -P /tmp http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
sudo useradd nagios
sudo groupadd nagcmd
sudo usermod -a -G nagcmd nagios
sudo usermod -a -G nagios,nagcmd www-data
sudo tar zxvf /tmp/nagios-4.2.0.tar.gz -C /tmp
sudo tar zxvf /tmp/nagios-plugins-2.1.2.tar.gz -C /tmp
cd /tmp/nagios-4.2.0
sudo ./configure --with-nagios-group=nagios --with-command-group=nagcmd
sudo make all
sudo make install
sudo make install-init
sudo make install-config
sudo make install-commandmode
sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
sudo ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/
sudo cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
sudo a2enmod rewrite
sudo a2enmod cgi
sudo ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
sudo htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin Samana81.
##############Configure nagios pluginss################
cd /tmp/nagios-plugins-2.1.2
sudo ./configure --with-nagios-user=nagios --with-nagios-group=nagios
sudo make
sudo make install
##############Configure pnp4nagios#####################
sudo wget "https://sourceforge.net/projects/pnp4nagios/files/latest" -O /tmp/pnp4nagios.latest.tar.gz
sudo tar zxvf /tmp/pnp4nagios.latest.tar.gz -C /tmp
cd /tmp/pnp4nagios-0.6.26
sudo ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd
sudo make all
sudo make fullinstall
sudo mv /etc/httpd/conf.d/pnp4nagios.conf /etc/apache2/sites-available/
sudo rm -Rf /etc/httpd
sudo ln -s /etc/apache2/sites-available/pnp4nagios.conf /etc/apache2/sites-enabled/
sudo mv /usr/local/pnp4nagios/share/install.php /usr/local/pnp4nagios/share/install-old.php
sudo ln -s /etc/init.d/npcd /etc/rcS.d/S98npcd
##Reboot to be able to start nagios (instalation bug)##
reboot