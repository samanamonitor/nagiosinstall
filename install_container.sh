#!/bin/bash

set -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ ! -f $DIR/config.dat ]; then
    echo "Configuration file not found. Use config.dat.example as a base"
    exit 1
fi

. $DIR/config.dat

NAGIOS_IP=$1

if [ -z "$NAGIOS_IP" ]; then
    echo "Usage: $0 <ip address>"
    exit 1
fi

apt install -y wget docker.io jq
if ! docker image inspect $IMAGE 2&> /dev/null; then
    wget -O - ${IMAGE_URL} | docker load
fi

docker run -p 80:80 -p 443:443 -p 2379:2379 \
    --mount source=nagios_etc,target=/usr/local/nagios/etc \
    --mount source=nagios_libexec,target=/usr/local/nagios/libexec \
    --mount source=pnp4nagios_perfdata,target=/usr/local/pnp4nagios/var/perfdata \
    --mount source=ssmtp_etc,target=/etc/ssmtp \
    --name sm -it -d $IMAGE /bin/bash -x /start.sh

if [ ! -d /usr/local/nagios ]; then
    mkdir -p /usr/local/nagios
fi
if [ ! -d /usr/local/pnp4nagios ]; then
    mkdir -p /usr/local/pnp4nagios
fi

if ! docker volume inspect nagios_etc 2&> /dev/null; then
    docker volume create nagios_etc
fi
if [ -L /usr/local/nagios/etc ]; then
    rm /usr/local/nagios/etc
fi
ln -s $(docker inspect nagios_etc | jq -r .[0].Mountpoint) /usr/local/nagios/etc

if ! docker volume inspect nagios_libexec 2&> /dev/null; then
    docker volume create nagios_libexec
fi
if [ -L /usr/local/nagios/libexec ]; then
    rm /usr/local/nagios/libexec
fi
ln -s $(docker inspect nagios_libexec | jq -r .[0].Mountpoint) /usr/local/nagios/libexec

if ! docker volume inspect pnp4nagios_perfdata 2&> /dev/null; then
    docker volume create pnp4nagios_perfdata
fi
if [ -L /usr/local/pnp4nagios/perfdata ]; then
    rm /usr/local/pnp4nagios/perfdata
fi
ln -s $(docker inspect pnp4nagios_perfdata | jq -r .[0].Mountpoint) /usr/local/pnp4nagios/perfdata

if ! docker volume inspect ssmtp_etc 2&> /dev/null; then
    docker volume create ssmtp_etc
fi
if [ ! -d /usr/local/ssmtp ]; then
    mkdir -p /usr/local/ssmtp
fi
if [ -L /usr/local/ssmtp/etc ]; then
    rm /usr/local/ssmtp/etc
fi
ln -s $(docker inspect ssmtp_etc | jq -r .[0].Mountpoint) /usr/local/ssmtp/etc

sed -i -e "/USER12/d" -e "/USER13/d" /usr/local/nagios/etc/resource.cfg
cat <<EOF >> /usr/local/nagios/etc/resource.cfg
# Sets \$USER3\$ for SNMP community
\$USER3\$=${NAGIOS_SNMP_COMMUNITY}

# NetScaler SNMPv3 user
#\$USER4\$=nagiosmonitor

# NETBIOS domain for multiple checks
\$USER6\$=${NAGIOS_NETBIOS_DOMAIN}

# WMI user for servers
\$USER7\$=${NAGIOS_WMI_USER}

# WMI user's password
\$USER8\$=${NAGIOS_WMI_PASSWORD}

# Path with authentication credentials for scripts
\$USER9\$=/etc/nagios/samananagios.pw

\$USER12\$=http://$NAGIOS_IP/samanamon.ps1
\$USER13\$=-SamanaMonitorURI http://$NAGIOS_IP:2379
\$USER14\$=$SLACK_DOMAIN
\$USER15\$=$SLACK_TOKEN
\$USER16\$=$SLACK_CHANNEL
EOF

cat <<EOF > /usr/local/nagios/etc/samananagios.pw
username=${NAGIOS_WMI_USER}@${NAGIOS_FQDN_DOMAIN}
password=${NAGIOS_WMI_PASSWORD}
domain=
EOF
chown nagios.nagios /etc/nagios/samananagios.pw
chmod 660 /etc/nagios/samananagios.pw

cat <<EOF > /usr/local/ssmtp/etc/ssmtp.conf
hostname=${NAGIOS_HOSTNAME}
root=${NAGIOS_EMAIL}
mailhub=${NAGIOS_SMTP_SERVER}
FromLineOverride=YES
AuthUser=${NAGIOS_SMTP_USER}
AuthPass=${NAGIOS_SMTP_PASSWORD}
UseTLS=YES
EOF
