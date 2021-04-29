#!/bin/bash

set -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ ! -f $DIR/config.dat ]; then
    echo "Configuration file not found. Use config.dat.example as a base"
    exit 1
fi

source $DIR/config.dat

if [ "$EXAMPLE" == "1" ]; then
    echo "Configuration file is an example, please modify the config file with the variables for the environment."
    exit 1
fi

if [ "$CONFIG_TYPE" != "install" ]; then
    echo "Invalid config file. Use config.dat.example as a template."
    exit 1
fi

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

add-local-volume() {
    VOLNAME=$1
    VOLPATH=$2
    if ! docker volume inspect $VOLNAME > /dev/null 2>&1; then
        docker volume create $VOLNAME
    fi
    if [ -L $VOLPATH ]; then
        rm $VOLPATH
    fi
    mkdir -p ${VOLPATH%/*}
    ln -s $(docker inspect $VOLNAME | jq -r .[0].Mountpoint) $VOLPATH

}

if ! docker image inspect $IMAGE > /dev/null 2>&1; then
    wget -O ${IMAGE_URL##*/} ${IMAGE_URL}
    docker load -i ${IMAGE_URL##*/}
    rm ${IMAGE_URL##*/}
fi

add-local-volume nagios_etc /usr/local/nagios/etc
add-local-volume nagios_libexec /usr/local/nagios/libexec
add-local-volume nagios_var /usr/local/nagios/var
add-local-volume pnp4nagios_perfdata /usr/local/pnp4nagios/var/perfdata
add-local-volume ssmtp_etc /usr/local/ssmtp/etc
add-local-volume apache_etc /usr/local/apache2/etc
add-local-volume apache_log /usr/local/apache2/log
add-local-volume etcd_data /usr/local/etcd/var

docker run -p 80:80 -p 443:443 \
    --mount source=nagios_etc,target=/usr/local/nagios/etc \
    --mount source=nagios_libexec,target=/usr/local/nagios/libexec \
    --mount source=nagios_var,target=/usr/local/nagios/var \
    --mount source=pnp4nagios_perfdata,target=/usr/local/pnp4nagios/var/perfdata \
    --mount source=ssmtp_etc,target=/etc/ssmtp \
    --mount source=apache_etc,target=/etc/apache2 \
    --mount source=apache_log,target=/var/log/apache2 \
    --name sm -it -d $IMAGE /bin/bash -x /start.sh


docker run -d -p 2379:2379 \
    --volume etcd_data:/etcd-data \
    --name etcd ${REGISTRY}:latest \
    /usr/local/bin/etcd --data-dir /etcd-data --name node0 \
    --advertise-client-urls http://${NAGIOS_IP}:2379 \
    --listen-client-urls http://0.0.0.0:2379 --max-snapshots 2 \
    --max-wals 5 --enable-v2 -auto-compaction-retention 1 \
    --snapshot-count 5000


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
\$USER13\$=http://$NAGIOS_IP:2379
\$USER14\$=$SLACK_DOMAIN
\$USER15\$=$SLACK_TOKEN
\$USER30\$=# replace with Citrix Cloud customer_id
\$USER31\$=# replace with Citrix Cloud API client_id
\$USER32\$=# replace with Citrix Cloud API client_secret
\$USER33\$=# replace with ETCD server IP
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

grep -q -E "^process_performance_data=1" /usr/local/nagios/etc/nagios.cfg
if [  "$?" != "0" ]; then
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
