#!/bin/bash

. /etc/os-release

KEYPATH=/var/lib/samana/pgp-samm-key.public
apt update
apt upgrade -y
apt install -y ca-certificates wget
mkdir -p /var/lib/samana
wget -O ${KEYPATH} https://samm-repo.s3.amazonaws.com/pgp-samm-key.public
echo "deb [arch=amd64 signed-by=${KEYPATH}] https://samm-repo.s3.amazonaws.com ${UBUNTU_CODENAME} main" \
    > /etc/apt/sources.list.d/samm.list
apt update
apt install -y samm samm-plugins samm-check-samana samm samm-check-winrm samm-pynag samm-pnp4nagios
apt clean
rm $(find /var/lib/apt/lists/ -type f )
> /var/log/alternatives.log
> /var/log/bootstrap.log
> /var/log/dmesg
> /var/log/dpkg.log
> /var/log/faillog
> /var/log/fontconfig.log
> /var/log/lastlog
> /var/log/apt/history.log
> /var/log/apt/term.log
pam_tally --file /var/log/tallylog --reset
