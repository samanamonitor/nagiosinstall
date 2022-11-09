#!/bin/bash

set -xe

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IPR2VER=5.5

USERID=$(id -u)
if [ "${USERID}" != "0" ]; then
    echo "Please run using sudo or as root"
    exit 1
fi

isip() {
    echo "$1" | grep -qE "^([0-9]+\.){3}[0-9]+$"
    return $?
}

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

if [ -z "${SAMM_PWD}" ] || [ "${SAMM_PWD}" == "set-password" ]; then
    echo "SAMM password not set. Aborting"
    exit 1
fi

NAGIOS_IP=$1

if ! isip "$NAGIOS_IP"; then
    ipver=$(dpkg -s iproute2 | sed -n "s/^Version: //p")
    if [ "$ipver" == "$(echo -e "$ipver\n${IPR2VER}" | sort -V | head -n1)" ]; then
        echo "Usage: $0 <ip address/iface name>"
        exit 1
    fi
    set +e
    ipdata=$(ip --json addr show ${NAGIOS_IP} 2>/dev/null)
    if [ "$?" != "0" ]; then
        echo "Invalid interface ${NAGIOS_IP}"
        exit 1
    fi
    ip=$(echo ${ipdata} | jq -r ".[0].addr_info[] | select(.family == \"inet\").local" 2>/dev/null)
    if [ "$?" != "0" ] || ! isip $ip; then
        echo "Invalid data from interface ${NAGIOS_IP}. ${ipdata}"
        exit 1
    fi
    NAGIOS_IP=${ip}
    set -e
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

set-key() {
    local file=$1
    shift
    local key=$1
    shift
    if [ -f $file ]; then
        sed -i -e "/^$key=.*/d" $file
    fi
    if [ "aa" == "a${@}a" ]; then
        echo "#$key=<set value and remove comment>"
    else
        echo "$key=$@" >> $file
    fi
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
add-local-volume ssmtp_etc /usr/local/ssmtp/etc
add-local-volume apache_etc /usr/local/apache2/etc
add-local-volume apache_log /usr/local/apache2/log
add-local-volume apache_html /usr/local/apache2/html
add-local-volume etcd_data /usr/local/etcd/var
add-local-volume snmp_mibs /usr/local/snmp/mibs
add-local-volume graphite /usr/local/graphite

chmod o+x /var/lib/docker
chmod o+x /var/lib/docker/volumes

SM_ID=$(docker ps -f name=sm -q)
if [ "$SM_ID" == "" ]; then
    docker run -p 80:80 -p 443:443 \
        --restart=always \
        --mount source=nagios,target=/usr/local/nagios \
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
        --restart=always \
        --volume etcd_data:/etcd-data \
        --name etcd ${REGISTRY}:latest \
        /usr/local/bin/etcd --data-dir /etcd-data --name node0 \
        --advertise-client-urls http://${NAGIOS_IP}:2379,http://localhost:2379 \
        --listen-client-urls http://0.0.0.0:2379 --max-snapshots 2 \
        --max-wals 5 --enable-v2 -auto-compaction-retention 1 \
        --snapshot-count 5000
fi

GRAPHITE_ID=$(docker ps -af name=graphite -q)
if [ -z "${GRAPHITE_ID}" ]; then
    docker run -d \
         --name graphite \
         --restart=always \
         --mount source=graphite,target=/opt/graphite \
         --env GRAPHITE_URL_ROOT=graphite \
         -p 8080:80 \
         -p 2003-2004:2003-2004 \
         -p 2023-2024:2023-2024 \
         -p 8125:8125/udp \
         -p 8126:8126 \
         graphiteapp/graphite-statsd
fi
GRAPH_CONF=$(docker inspect graphite \
    | jq -r '.[0].Mounts[] | select(.Destination == "/opt/graphite/conf").Source')
${DIR}/editini.py ${GRAPH_CONF} set default_average xfilesfactor 0

if [ "$new" == "1" ]; then
    docker exec -it sm htpasswd -b \
        -c /usr/local/nagios/etc/htpasswd.users "${SAMM_USER}" "${SAMM_PWD}"

    NAGIOS_REC=/usr/local/nagios/etc/resource.cfg
    echo "# Sets \$USER3\$ for SNMP community" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER3\$ ${NAGIOS_SNMP_COMMUNITY}
    echo "# NetScaler SNMPv3 user" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER4\$ nagiosmonitor
    echo "# NETBIOS domain for multiple checks" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER6\$ ${NAGIOS_NETBIOS_DOMAIN}
    echo "# WMI user for servers" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER7\$ ${NAGIOS_WMI_USER}
    echo "# WMI user's password" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER8\$ ${NAGIOS_WMI_PASSWORD}
    echo "# Path with authentication credentials for scripts" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER9\$ /usr/local/nagios/etc/samananagios.pw
    echo "# Powershell script for citrix xa/xd monitoring" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER11\$ http://$NAGIOS_IP/samanamonctx.ps1
    echo "# Powershell script for windows monitoring (legacy)" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER12\$ http://$NAGIOS_IP/samanamon.ps1
    echo "# Etcd server URL (deprecated) is replaced by \$USER33\$" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER13\$ http://$NAGIOS_IP:2379
    echo "# Slach domain" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER14\$ $SLACK_DOMAIN
    echo "# Slach Tocken" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER15\$ $SLACK_TOKEN
    echo "# Citrix Cloud customer_id" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER30\$
    echo "# Citrix Cloud API client_id" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER31\$
    echo "# Citrix Cloud API client_secret" >> ${NAGIOS_REC}
    set-key ${NAGIOS_REC} \$USER32\$
    set-key ${NAGIOS_REC} \$USER33\$ ${NAGIOS_IP}:2379

    PW_FILE=/usr/local/nagios/etc/samananagios.pw
    set-key ${PW_FILE} username ${NAGIOS_WMI_USER}
    set-key ${PW_FILE} password ${NAGIOS_WMI_PASSWORD}
    set-key ${PW_FILE} domain ${NAGIOS_NETBIOS_DOMAIN}
    chown nagios.nagios ${PW_FILE}
    chmod 660 ${PW_FILE}

    SSMTP_FILE=/usr/local/ssmtp/etc/ssmtp.conf

    set-key ${SSMTP_FILE} hostname ${NAGIOS_HOSTNAME}
    set-key ${SSMTP_FILE} root ${NAGIOS_EMAIL}
    set-key ${SSMTP_FILE} mailhub ${NAGIOS_SMTP_SERVER}
    set-key ${SSMTP_FILE} FromLineOverride YES
    set-key ${SSMTP_FILE} AuthUser ${NAGIOS_SMTP_USER}
    set-key ${SSMTP_FILE} AuthPass ${NAGIOS_SMTP_PASSWORD}
    set-key ${SSMTP_FILE} UseTLS YES

    NAGIOS_CFG=/usr/local/nagios/etc/nagios.cfg
    GRAPHIOS_SPOOL=/usr/local/nagios/var/spool/graphios
    mkdir -p ${GRAPHIOS_SPOOL}
    chown nagios.nagios ${GRAPHIOS_SPOOL}
    sed -i "/^cfg_dir=\/etc\/nagios\/objects$/d" ${NAGIOS_CFG}
    set-key ${NAGIOS_CFG} process_performance_data 1
    set-key ${NAGIOS_CFG} service_perfdata_file ${GRAPHIOS_SPOOL}/service-perfdata
    set-key ${NAGIOS_CFG} service_perfdata_file_template DATATYPE::SERVICEPERFDATA\\tTIMET::\$TIMET\$\\tHOSTNAME::\$HOSTNAME\$\\tSERVICEDESC::\$SERVICEDESC\$\\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\\tHOSTSTATE::\$HOSTSTATE\$\\tHOSTSTATETYPE::$HOSTSTATETYPE\$\\tSERVICESTATE::$SERVICESTATE\$\\tSERVICESTATETYPE::\$SERVICESTATETYPE\$\\tGRAPHITEPREFIX::\$_SERVICEGRAPHITEPREFIX\$\\tGRAPHITEPOSTFIX::\$_SERVICEGRAPHITEPOSTFIX\$
    set-key ${NAGIOS_CFG} service_perfdata_file_mode a
    set-key ${NAGIOS_CFG} service_perfdata_file_processing_interval 15
    set-key ${NAGIOS_CFG} service_perfdata_file_processing_command process-service-perfdata-file-graphios
    set-key ${NAGIOS_CFG} host_perfdata_file ${GRAPHIOS_SPOOL}/host-perfdata
    set-key ${NAGIOS_CFG} host_perfdata_file_template DATATYPE::HOSTPERFDATA\\tTIMET::\$TIMET\$\\tHOSTNAME::\$HOSTNAME\$\\tHOSTPERFDATA::\$HOSTPERFDATA\$\\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\\tHOSTSTATE::\$HOSTSTATE\$\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\\tGRAPHITEPREFIX::\$_HOSTGRAPHITEPREFIX\$\\tGRAPHITEPOSTFIX::\$_HOSTGRAPHITEPOSTFIX\$
    set-key ${NAGIOS_CFG} host_perfdata_file_mode a
    set-key ${NAGIOS_CFG} host_perfdata_file_processing_interval 15
    set-key ${NAGIOS_CFG} host_perfdata_file_processing_command process-host-perfdata-file-graphios
    set +e

    GRAPHIOS_CFG=/usr/local/nagios/etc/graphios/graphios.cfg
    echo "[graphios]" > ${GRAPHIOS_CFG}
    set-key ${GRAPHIOS_CFG} replacement_character  _
    set-key ${GRAPHIOS_CFG} spool_directory  ${GRAPHIOS_SPOOL}
    set-key ${GRAPHIOS_CFG} log_file  /usr/local/nagios/var/graphios.log
    set-key ${GRAPHIOS_CFG} log_max_size  25165824
    set-key ${GRAPHIOS_CFG} log_level  logging.INFO
    set-key ${GRAPHIOS_CFG} debug  False
    set-key ${GRAPHIOS_CFG} sleep_time  15
    set-key ${GRAPHIOS_CFG} sleep_max  480
    set-key ${GRAPHIOS_CFG} test_mode  False
    set-key ${GRAPHIOS_CFG} use_service_desc  True
    set-key ${GRAPHIOS_CFG} replace_hostname  True
    set-key ${GRAPHIOS_CFG} reverse_hostname  False
    set-key ${GRAPHIOS_CFG} enable_carbon  True
    set-key ${GRAPHIOS_CFG} carbon_plaintext  False
    set-key ${GRAPHIOS_CFG} carbon_servers  $NAGIOS_IP:2004
    set-key ${GRAPHIOS_CFG} enable_statsd  False
    set-key ${GRAPHIOS_CFG} statsd_server  127.0.0.1:8125
    set-key ${GRAPHIOS_CFG} enable_librato  False
    set-key ${GRAPHIOS_CFG} librato_whitelist  [".*"]
    set-key ${GRAPHIOS_CFG} enable_stdout  False
    set-key ${GRAPHIOS_CFG} nerf_stdout  True

    sed -i -e "s/%NAGIOS_IP%/${NAGIOS_IP}/" /usr/local/apache2/etc/conf-available/graphite.conf
    sed -i -e '/service_description\s\+SSH/a\    register        0' \
        /usr/local/nagios/etc/objects/localhost.cfg
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
