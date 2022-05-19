#!/bin/bash

TFTPROOT=/tmp/tftpboot
DIST="focal"
ARCH_INSTALLER="/ubuntu-installer/amd64"
ARCH="http://archive.ubuntu.com/ubuntu/dists/${DIST}/main/installer-amd64/current/legacy-images/netboot"
HOST_BOOTMAC=
HOST_NAME=
HOST_IP=
HOST_NET=
NET_MASK=
DNS_SERVERS=
NET_GW=
DOMAIN=

mkdir -p ${TFTPROOT}/pxelinux.cfg
mkdir -p ${TFTPROOT}${ARCH_INSTALLER}

wget -O ${TFTPROOT}/ldlinux.c32 ${ARCH}/ldlinux.c32
wget -O ${TFTPROOT}/pxelinux.0 ${ARCH}/pxelinux.0
wget -O ${TFTPROOT}${ARCH_INSTALLER}/linux ${ARCH}${ARCH_INSTALLER}/linux
wget -O ${TFTPROOT}${ARCH_INSTALLER}/initrd.gz ${ARCH}${ARCH_INSTALLER}/initrd.gz

cp $DIR/pxelinux_cfg.default ${TFTPROOT}/pxelinux.cfg/default

cat <<EOF > ${TFTPROOT}/pxelinux.cfg/default
default install
PROMPT 1
TIMEOUT 10
serial 0 115200

LABEL install
     kernel ubuntu-installer/amd64/linux
     append initrd=ubuntu-installer/amd64/initrd.gz --- net.ifnames=0 biosdevname=0 nosplash
EOF
chmod 777 $TFTPROOT/*

dnsmasq --no-hosts --strict-order --except-interface=lo \
  --pid-file=$PIDFILE --port=0 --dhcp-leasefile=/tmp/install \
  --dhcp-host=${HOST_BOOTMAC},${HOST_NAME},${HOST_IP} \
  --dhcp-match=set:ipxe,175 --bind-interfaces --interface=eth0 \
  --dhcp-range=set:tag0,${HOST_NET},static,${NET_MASK},86400s \
  --dhcp-option=option:dns-server,"${DNS_SERVERS}" \
  --dhcp-option=tag:tag0,3,${NET_GW} \
  --dhcp-lease-max=128 --conf-file= \
  --domain=${DOMAIN} --dhcp-boot=pxelinux.0 \
  --enable-tftp --tftp-root=${TFTPROOT} 
