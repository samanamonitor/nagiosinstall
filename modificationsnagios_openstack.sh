CHECKBW_URL="https://exchange.nagios.org/components/com_mtree/attachment.php?link_id=4970&cf_id=24"
NAGIOS=/usr/loca/nagios
NAGIOS_ETC=${NAGIOS}/etc
NAGIOS_LIBEXEC=${NAGIOS}/libexec
sudo wget $CHECKBW_URL \
    -O ${NAGIOS_LIBEXEC}/check_bw.sh
chown nagios.nagios ${NAGIOS_LIBEXEC}/check_bw.sh
chmod +x ${NAGIOS_LIBEXEC}/check_bw.sh

sudo apt install -y git
git clone https://github.com/samanamonitor/check_samana.git
sudo cp check_samana/src/*.py ${NAGIOS_LIBEXEC}
sudo chown nagios.nagios ${NAGIOS_LIBEXEC}/*.py
sudo chmod +x ${NAGIOS_LIBEXEC}/*.py
sudo mkdir ${NAGIOS_ETC}/check_samana
sudo cp check_samana/etc/config.json ${NAGIOS_ETC}
sudo apt install -y snmp-mibs-downloader
sudo wget http://192.168.0.12/support/docs/snmp/HP-Openview/NS-MIB-smiv2.mib -O /usr/share/snmp/mibs/NS-MIB-smiv2.txt

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
ExecStart=/usr/local/nagios/bin/nagios /usr/local/nagios/etc/nagios.cfg
ExecReload=/bin/kill -HUP $MAINPID
EOF


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

echo "mibs ALL" >> /etc/snmp/snmp.conf
apt install -y python-pynag

sudo apt install -y php-sybase
sudo wget "https://exchange.nagios.org/components/com_mtree/attachment.php?link_id=497&cf_id=24" -O /usr/local/nagios/libexec/check_mssql
sudo chmod +x /usr/local/nagios/libexec/check_mssql

# run the following commands on windows for winRM to be enabled
# winrm quickconfig -transport:https

## need to validate if the following is needed for check_mssql
sudo apt install -y curl
sudo apt install -y apt-transport-https
curl -s https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo bash -c "curl -s https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get -y install msodbcsql17 mssql-tools
sudo apt-get -y install unixodbc-dev
sudo apt install -y php7.0-dev
sudo pecl install sqlsrv-5.3.0
sudo pecl install pdo_sqlsrv-5.3.0
cat <<EOF | sudo tee /etc/php/7.0/mods-available/pdo_sqlsrv.ini
; configuration for php sqlite3 module
; priority=30
extension=pdo_sqlsrv.so
EOF
sudo ln -s /etc/php/7.0/mods-available/pdo_sqlsrv.ini /etc/php/7.0/apache2/conf.d/20-pdo_sqlsrv.ini
sudo ln -s /etc/php/7.0/mods-available/pdo_sqlsrv.ini /etc/php/7.0/cli/conf.d/20-pdo_sqlsrv.ini

apt install -y libwww-perl libcrypt-ssleay-perl liblwp-protocol-https-perl
wget -O "/usr/local/nagios/libexec/slack_nagios.pl" https://raw.github.com/tinyspeck/services-examples/master/nagios.pl
chown nagios.nagios /usr/local/nagios/libexec/slack_nagios.pl
chmod +x /usr/local/nagios/libexec/slack_nagios.pl

wget -O check_wmi_plus.v1.64.tar.gz "http://edcint.co.nz/checkwmiplus/sites/default/files/check_wmi_plus.v1.64.tar.gz"
tar -xzvf check_wmi_plus.v1.64.tar.gz
sudo mv check_wmi_plus_help.pl check_wmi_plus.pl check_wmi_plus.README.txt /usr/local/nagios/libexec/
sed -i "s|my \$conf_file=.*|my \$conf_file='/etc/nagios/check_wmi_plus/check_wmi_plus.conf';|" \
    /usr/local/nagios/libexec/check_wmi_plus.pl
apt -y install autoconf make gcc libdatetime-perl build-essential g++ python-dev
git clone https://github.com/samanamonitor/wmi.git
cd wmi
ulimit -n 100000 && make "CPP=gcc -E -ffreestanding"
sudo cp ${HOME}/bin/wmic /usr/local/bin/
