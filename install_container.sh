#!/bin/bash

IMAGE_URL="" # s3 url to samanamonitor.tgz image
IMAGE=samanamon:v1
NAGIOS_IP=$1

if [ -z "$NAGIOS_IP" ]; then
    echo "Usage: $0 <ip address>"
    exit 1
fi

apt install -y wget docker.io jq
wget -O - ${IMAGE_URL} | docker load
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

docker run -p 80:80 -p 443:443 -p 2379:2379 \
    --mount source=nagios_etc,target=/usr/local/nagios/etc \
    --mount source=nagios_libexec,target=/usr/local/nagios/libexec \
    --mount source=pnp4nagios_perfdata,target=/usr/local/pnp4nagios/var/perfdata \
    --name sm -it -d $IMAGE /bin/bash -x /start.sh

sed -i -e "/USER12/d" -e "/USER13/d" /usr/local/nagios/etc/resource.cfg
cat <<EOF >> /usr/local/nagios/etc/resource.cfg
\$USER12\$=http://$NAGIOS_IP/samanamon.ps1
\$USER13\$=-SamanaMonitorURI http://$NAGIOS_IP:2379
EOF