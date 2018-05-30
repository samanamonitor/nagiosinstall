#!/bin/sh

HOST=nagiost1
H_IP=169.254.254.10
H_NETMASK=255.255.255.0
H_GATEWAY=169.254.254.1
H_PATH=/var/lib/lxc/$HOST/rootfs
echo "Creating Container $HOST ..."
lxc-create -t centos -n $HOST
echo "Container $HOST created."
echo "Configuring IP Address $H_IP ..."
cat <<EOT > $H_PATH/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=static
IPADDR=$H_IP
NETMASK=$H_NETMASK
GATEWAY=$H_GATEWAY
ONBOOT=yes
HOSTNAME=$HOST
NM_CONTROLLED=no
TYPE=Ethernet
MTU=
EOT
echo "IP Address Configured."
echo "$H_IP $HOST" >> /etc/hosts
if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
    chmod 700 ~/.ssh
fi
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -C "nagios@samanagroup.com" -f ~/.ssh/id_rsa -P ""
    echo "Created SSH keys."
fi
if [ ! -d "$H_PATH/root/.ssh" ]; then
    mkdir $H_PATH/root/.ssh
    chmod 700 $H_PATH/root/.ssh
    echo "Created root .ssh path."
fi
cat ~/.ssh/id_rsa.pub >> $H_PATH/root/.ssh/authorized_keys
chmod 600 $H_PATH/root/.ssh/authorized_keys
echo "Created authorized_keys."
if ! dig mirrors.fedoraproject.org | grep "NOERROR">/dev/null; then
    echo `dig +short mirrors.fedoraproject.org @8.8.8.8 | sed -n 2p` mirrors.fedoraproject.org >> $H_PATH/etc/hosts
    echo "WARNING: DNS is not able to resove mirrors.fedoraproject.org. Creating a hosts entry."
fi
lxc-start -n $HOST -d
echo "Started Container"
echo "Starting to install packages..."
lxc-attach -n $HOST -- /usr/bin/yum -y install epel-release git
lxc-attach -n $HOST -- /usr/bin/yum -y install nagios nagios-plugins nagios-plugins-ping nagios-plugins-users nagios-plugins-load nagios-plugins-http nagios-plugins-disk nagios-plugins-ssh nagios-plugins-swap nagios-plugins-procs
lxc-attach -n $HOST -- /usr/bin/yum -y install pnp4nagios
mkdir -p $H_PATH/var/www/html
mkdir -p $H_PATH/var/log/httpd
echo "Packages installed."
lxc-attach -n $HOST -- systemctl enable httpd
lxc-attach -n $HOST -- systemctl start httpd
echo "HTTPD daemon started"
cp include/index.html $H_PATH/var/www/html/index.html

##
#### Configure and Start Nagios #####
##

mv $H_PATH/etc/nagios/nagios.cfg $H_PATH/etc/nagios/nagios.cfg.orig
cp include/nagios.cfg $H_PATH/etc/nagios/nagios.cfg

mkdir -p $H_PATH/etc/nagios/objects/samana
cp include/perfdata.cfg $H_PATH/etc/nagios/objects/samana/perfdata.cfg
cp include/commands.cfg $H_PATH/etc/nagios/objects/samana/commands.cfg

lxc-attach -n $HOST -- systemctl enable nagios
lxc-attach -n $HOST -- systemctl start nagios
echo "Nagios has been configured and started."

mv $H_PATH/etc/pnp4nagios/npcd.cfg $H_PATH/etc/pnp4nagios/npcd.cfg.orig
cp include/npcd.cfg $H_PATH/etc/pnp4nagios/npcd.cfg
lxc-attach -n $HOST -- systemctl enable npcd
lxc-attach -n $HOST -- systemctl start npcd
echo "PNP4Nagios has been configured and started."
