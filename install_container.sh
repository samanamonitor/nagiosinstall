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

if [ "${IMAGE}" == "" ]; then
    echo "Set IMAGE variable in config.dat file"
    exit 1
fi

NAGIOS_IP=$1

if [ -z "$NAGIOS_IP" ]; then
    echo "Usage: $0 <ip address>"
    exit 1
fi

if ! which docker; then
    if [ "$DIST" == "ubuntu" ]; then
        apt install -y wget docker.io jq
    elif [ "$DIST" == "rhel" ]; then
        yum install -y yum-utils
        yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io jq wget --allowerasing
    else
        echo "Invalid distribution. Use ubuntu or rhel"
        exit 1
    fi        
    systemctl start docker
fi

add-local-volume() {
    VOLNAME=$1
    VOLPATH=$2
    if ! docker volume inspect $VOLNAME > /dev/null 2>&1; then
        docker volume create $VOLNAME
    else
        return 0
    fi
    if [ -L $VOLPATH ]; then
        rm $VOLPATH
    fi
    mkdir -p ${VOLPATH%/*}
    ln -s $(docker inspect $VOLNAME | jq -r .[0].Mountpoint) $VOLPATH

}

IMAGE_ID=$(docker image ls ${IMAGE} -q)
if [ "$IMAGE_ID" == "" ]; then
    if [ ! -f ${IMAGE_URL##*/} ]; then
        wget -O ${IMAGE_URL##*/} ${IMAGE_URL}
    fi
    docker load -i ${IMAGE_URL##*/}
    rm ${IMAGE_URL##*/}
fi

if ! getent group nagios > /dev/null; then
    groupadd -g ${NAGIOS_GID} nagios
fi

if ! getent group nagcmd > /dev/null; then
    groupadd -g ${NAGCMD_GID} nagcmd
fi

if ! id nagios > /dev/null 2>&1; then
    useradd -M -u ${NAGIOS_UID} -g ${NAGIOS_GID} nagios
fi

if [ -d /usr/local/nagios/etc ]; then
    new=0
else
    new=1
fi

add-local-volume nagios /usr/local/nagios
add-local-volume pnp4nagios /usr/local/pnp4nagios
add-local-volume ssmtp_etc /usr/local/ssmtp/etc
add-local-volume apache_etc /usr/local/apache2/etc
add-local-volume apache_log /usr/local/apache2/log
add-local-volume apache_html /usr/local/apache2/html
add-local-volume etcd_data /usr/local/etcd/var
add-local-volume smnp_mibs /usr/local/smnp/mibs

chmod o+x /var/lib/docker/volumes

SM_ID=$(docker ps -f name=sm -q)
if [ "$SM_ID" == "" ]; then
    docker run -p 80:80 -p 443:443 \
        --mount source=nagios,target=/usr/local/nagios \
        --mount source=pnp4nagios,target=/usr/local/pnp4nagios \
        --mount source=ssmtp_etc,target=/etc/ssmtp \
        --mount source=apache_etc,target=/etc/apache2 \
        --mount source=apache_log,target=/var/log/apache2 \
        --mount source=apache_html,target=/var/www/html \
        --mount source=snmp_mibs,target=/usr/share/snmp/mibs \
        --name sm -it -d $IMAGE
fi

ETCD_ID=$(docker ps -af name=etcd -q)
if [ "$ETCD_ID" == "" ]; then
    docker run -d -p 2379:2379 \
        --volume etcd_data:/etcd-data \
        --name etcd ${REGISTRY}:latest \
        /usr/local/bin/etcd --data-dir /etcd-data --name node0 \
        --advertise-client-urls http://${NAGIOS_IP}:2379 \
        --listen-client-urls http://0.0.0.0:2379 --max-snapshots 2 \
        --max-wals 5 --enable-v2 -auto-compaction-retention 1 \
        --snapshot-count 5000
fi

if $new; then
    sed -i -e "/USER12/d" \
        -e "/USER13/d" \
        -e "/USER11/d" \
        -e "/USER9/d" \
        -e "/USER14/d" \
        -e "/USER15/d" \
        -e "/USER30/d" \
        -e "/USER31/d" \
        -e "/USER32/d" \
        -e "/USER33/d" \
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
    chown ${NAGIOS_UID}.${NAGIOS_GID} /usr/local/nagios/etc/samananagios.pw
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

    set +e
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
    set -e
fi
cd /usr/src
if [ ! -d /usr/src/check_samana ]; then
    git clone https://github.com/samanamonitor/check_samana.git
else
    cd check_samana
    git pull
fi
apt install -y make
make -C /usr/src/check_samana
make -C /usr/src/check_samana install
