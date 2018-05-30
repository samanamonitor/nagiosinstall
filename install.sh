#!/bin/sh

die () {
   echo >&2 "USAGE: . install.sh <container_name> <0-9> <fully qualified domain name>"
   exit 1
}

[ "$#" -eq 3 ] || die $@
echo $2 | grep -E -q '^[0-9]$' || die $@

CONTAINER=$1
C_IP=169.254.254.1$2
C_NETMASK=255.255.255.0
C_GATEWAY=169.254.254.1
C_PATH=/var/lib/lxc/$CONTAINER/rootfs
C_FQDN=$3
H_IP=169.254.254.1
H_NETMASK=255.255.255.0

install_lxc() {
   if ! rpm -ql lxc >/dev/null; then
      yum -y install lxc lxc-templates lxc-extra
      systemctl enable lxc.service
      echo "Installed LXC containers."
   else
      echo "LXC already installed."
   fi
}

install_nginx() {
   if ! rpm -ql nginx >/dev/null; then
      yum -y install nginx
      systemctl enable nginx
      systemctl start nginx
      echo "Finished installing NGINX."
   else
      echo "NGINX already installed."
   fi
}

enable_ipforward() {
   if ! grep -e "^net.ipv4.ip_forward\s*=\s*1" /etc/sysctl.conf >/dev/null; then 
      echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
      echo "Enabled IP Forwarding."
      sysctl -a
   else
      echo "IP Forwarding already configured."
   fi
}

set_ip() {
   NAME=$1
   FPATH=$2
   TYPE=$3
   IPADDR=$4
   NETMASK=$5
   GATEWAY=$6

   if [ ! -z $GATEWAY ]; then
      GATEWAY="GATEWAY=${GATEWAY}"
   fi

   cat include/ifcfg.template | \
      sed -e "s|\%NAME\%|${NAME}|" \
          -e "s|\%TYPE\%|${TYPE}|" \
          -e "s|\%IPADDR\%|${IPADDR}|" \
          -e "s|\%NETMASK\%|${NETMASK}|" \
          -e "s|\%GATEWAY\%|${GATEWAY}|" \
       > ${FPATH}/ifcfg-${NAME}
   echo "Interface ${NAME} has been configured."
}

setup_firewall() {
   IFCONTAINERS=$1
   IFOUT=$2

   firewall-cmd --permanent --zone=internal --change-interface=$IFCONTAINERS
   firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -o $IFOUT -j MASQUERADE
   firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i $IFCONTAINERS -o $IFOUT -j ACCEPT
   firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -o $IFCONTAINERS -i $IFOUT -m state --state RELATED,ESTABLISHED -j ACCEPT
   firewall-cmd --reload
   echo "Firewall has been configured."
}

setup_host_network() {
   IFCONTAINERS=$1
   IFOUT=$2
   HOSTIP=$3
   HOSTMASK=$4

   if [ ! -f /etc/sysconfig/network-scripts/ifcfg-${IFCONTAINERS} ]; then
      set_ip $IFCONTAINERS /etc/sysconfig/network-scripts Bridge $HOSTIP $HOSTMASK
      setup_firewall $IFCONTAINERS $IFOUT
      ifup virbr0
      echo "Finished configuring host network."
   else
      echo "Host network already configured."
   fi
}

install_lxc
enable_ipforward
setup_host_network virbr0 ens160 $H_IP $H_NETMASK

echo "Creating Container $CONTAINER ..."
lxc-create -t centos -n $CONTAINER
echo "Container $CONTAINER created."
echo "Configuring container IP address $C_IP ..."
set_ip eth0 $C_PATH/etc/sysconfig/network-scripts/ Ethernet $C_IP $C_NETMASK $C_GATEWAY
echo "$C_IP $CONTAINER" >> /etc/hosts
if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
    chmod 700 ~/.ssh
fi
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -C "nagios@samanagroup.com" -f ~/.ssh/id_rsa -P ""
    echo "Created SSH keys."
fi
if [ ! -d "$C_PATH/root/.ssh" ]; then
    mkdir $C_PATH/root/.ssh
    chmod 700 $C_PATH/root/.ssh
    echo "Created root .ssh path."
fi
cat ~/.ssh/id_rsa.pub >> $C_PATH/root/.ssh/authorized_keys
chmod 600 $C_PATH/root/.ssh/authorized_keys
echo "Created authorized_keys."
if ! dig mirrors.fedoraproject.org | grep "NOERROR">/dev/null; then
    echo `dig +short mirrors.fedoraproject.org @8.8.8.8 | sed -n 2p` mirrors.fedoraproject.org >> $C_PATH/etc/hosts
    echo "WARNING: DNS is not able to resove mirrors.fedoraproject.org. Creating a hosts entry."
fi
lxc-start -n $CONTAINER -d
echo "Started Container"
sleep 10
echo "Starting to install packages..."
lxc-attach -n $CONTAINER -- /usr/bin/yum -y install epel-release
lxc-attach -n $CONTAINER -- /usr/bin/yum -y install nagios nagios-plugins nagios-plugins-ping nagios-plugins-users nagios-plugins-load nagios-plugins-http nagios-plugins-disk nagios-plugins-ssh nagios-plugins-swap nagios-plugins-procs
lxc-attach -n $CONTAINER -- /usr/bin/yum -y install pnp4nagios
mkdir -p $C_PATH/var/www/html
mkdir -p $C_PATH/var/log/httpd
echo "Packages installed."
lxc-attach -n $CONTAINER -- systemctl enable httpd
lxc-attach -n $CONTAINER -- systemctl start httpd
echo "HTTPD daemon started"
cp include/index.html $C_PATH/var/www/html/index.html

##
#### Configure and Start Nagios #####
##

mv $C_PATH/etc/nagios/nagios.cfg $C_PATH/etc/nagios/nagios.cfg.orig
cp include/nagios.cfg $C_PATH/etc/nagios/nagios.cfg

mkdir -p $C_PATH/etc/nagios/objects/samana
cp include/perfdata.cfg $C_PATH/etc/nagios/objects/samana/perfdata.cfg
cp include/commands.cfg $C_PATH/etc/nagios/objects/samana/commands.cfg

lxc-attach -n $CONTAINER -- systemctl enable nagios
lxc-attach -n $CONTAINER -- systemctl start nagios
echo "Nagios has been configured and started."

mv $C_PATH/etc/pnp4nagios/npcd.cfg $C_PATH/etc/pnp4nagios/npcd.cfg.orig
cp include/npcd.cfg $C_PATH/etc/pnp4nagios/npcd.cfg
lxc-attach -n $CONTAINER -- systemctl enable npcd
lxc-attach -n $CONTAINER -- systemctl start npcd
echo "PNP4Nagios has been configured and started."

/usr/bin/cat include/nginx_nagios.conf.template | \
         sed -e "s|\%SERVER\%|${CONTAINER}|" \
             -e "s|\%SERVER_IP\%|${C_IP}|" \
             -e "s|%FQDN%|${C_FQDN}|" > /etc/nginx/conf.d/${CONTAINER}.conf

systemctl restart nginx
