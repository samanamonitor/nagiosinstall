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

if [ "$DIST" == "ubuntu" ]; then
    apt install -y wget docker.io jq
elif [ "$DIST" == "rhel" ]; then
    yum install -y yum-utils
    yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io jq wget --allowerasing
    systemctl start docker
else
    echo "Invalid distribution. Use ubuntu or rhel"
    exit 1
fi

if ! docker image inspect $IMAGE > /dev/null 2>&1; then
    wget -O - ${IMAGE_URL} | docker load
fi

if [ ! -d /usr/local/nagios ]; then
    mkdir -p /usr/local/nagios
fi
if [ ! -d /usr/local/pnp4nagios ]; then
    mkdir -p /usr/local/pnp4nagios
fi

if ! docker volume inspect nagios_etc > /dev/null 2>&1; then
    docker volume create nagios_etc
fi
if [ -L /usr/local/nagios/etc ]; then
    rm /usr/local/nagios/etc
fi
ln -s $(docker inspect nagios_etc | jq -r .[0].Mountpoint) /usr/local/nagios/etc

if ! docker volume inspect nagios_libexec > /dev/null 2>&1; then
    docker volume create nagios_libexec
fi
if [ -L /usr/local/nagios/libexec ]; then
    rm /usr/local/nagios/libexec
fi
ln -s $(docker inspect nagios_libexec | jq -r .[0].Mountpoint) /usr/local/nagios/libexec

if ! docker volume inspect pnp4nagios_perfdata > /dev/null 2>&1; then
    docker volume create pnp4nagios_perfdata
fi
if [ -L /usr/local/pnp4nagios/perfdata ]; then
    rm /usr/local/pnp4nagios/perfdata
fi
ln -s $(docker inspect pnp4nagios_perfdata | jq -r .[0].Mountpoint) /usr/local/pnp4nagios/perfdata

if ! docker volume inspect ssmtp_etc > /dev/null 2>&1; then
    docker volume create ssmtp_etc
fi
if [ ! -d /usr/local/ssmtp ]; then
    mkdir -p /usr/local/ssmtp
fi
if [ -L /usr/local/ssmtp/etc ]; then
    rm /usr/local/ssmtp/etc
fi
ln -s $(docker volume inspect ssmtp_etc | jq -r .[0].Mountpoint) /usr/local/ssmtp/etc

docker run -p 80:80 -p 443:443 -p 2379:2379 \
    --mount source=nagios_etc,target=/usr/local/nagios/etc \
    --mount source=nagios_libexec,target=/usr/local/nagios/libexec \
    --mount source=pnp4nagios_perfdata,target=/usr/local/pnp4nagios/var/perfdata \
    --mount source=ssmtp_etc,target=/etc/ssmtp \
    --name sm -it -d $IMAGE /bin/bash -x /start.sh

sed -i -e "/USER12/d" \
    -e "/USER13/d" \
    -e "/USER11/d" \
    -e "/USER9/d" \
    -e "/USER14/d" \
    -e "/USER15/d" \
    /usr/local/nagios/etc/resource.cfg
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

\$USER11\$=http://$NAGIOS_IP/samanamonctx.ps1
\$USER12\$=http://$NAGIOS_IP/samanamon.ps1
\$USER13\$=-SamanaMonitorURI http://$NAGIOS_IP:2379
\$USER14\$=$SLACK_DOMAIN
\$USER15\$=$SLACK_TOKEN
EOF

cat <<EOF > /usr/local/nagios/etc/samananagios.pw
username=${NAGIOS_WMI_USER}@${NAGIOS_FQDN_DOMAIN}
password=${NAGIOS_WMI_PASSWORD}
domain=
EOF
chown 1000.1000 /usr/local/nagios/etc/samananagios.pw
chmod 660 /usr/local/nagios/etc/samananagios.pw

cat <<EOF > /usr/local/ssmtp/etc/ssmtp.conf
hostname=${NAGIOS_HOSTNAME}
root=${NAGIOS_EMAIL}
mailhub=${NAGIOS_SMTP_SERVER}
FromLineOverride=YES
AuthUser=${NAGIOS_SMTP_USER}
AuthPass=${NAGIOS_SMTP_PASSWORD}
UseTLS=YES
EOF

if ! grep -q -E "^process_performance_data=1"; do
    cat <<EOF >> /usr/local/nagios/etc/nagios.cfg
process_performance_data=1
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tSERVICEDESC::\$SERVICEDESC\$\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\tSERVICESTATE::\$SERVICESTATE\$\tSERVICESTATETYPE::\$SERVICESTATETYPE\$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tHOSTPERFDATA::\$HOSTPERFDATA\$\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
EOF
fi
