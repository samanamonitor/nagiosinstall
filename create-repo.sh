#!/bin/bash

set -x

. /etc/os-release

do_hash() {
    HASH_NAME=$1
    HASH_CMD=$2
    echo "${HASH_NAME}:"
    for f in $(find -type f); do
        f=$(echo $f | cut -c3-) # remove ./ prefix
        if [ "$f" = "Release" ]; then
            continue
        fi
        echo " $(${HASH_CMD} ${f}  | cut -d" " -f1) $(wc -c $f)"
    done
}

if [ ! -d gpg ]; then
    mkdir gpg
fi

if [ ! -d apt-repo/pool/main/${VERSION_CODENAME} ]; then
    echo "Directory containing packages is missing (apt-repo/pool/main/${VERSION_CODENAME})" >&2
    exit 1
fi

apt update
apt install -y dpkg-dev

CURDIR=$(pwd)
export GNUPGHOME="$(mktemp -d ${CURDIR}/gpg/pgpkeys-XXXXXX)"

gpg --list-keys SamanaMonitor > /dev/null 2>&1
if [ "0" != "$?" ]; then
    if [ ! -f gpg/pgp-key.private ]; then
        echo "Add private key to gpg directory" >&2
        exit 1
    fi
    cat gpg/pgp-key.private | gpg --import
    gpg --armor --export SamanaMonitor > gpg/pgp-key.public
fi
cp gpg/pgp-key.public apt-repo/pgp-samm-key.public

mkdir -p apt-repo/dists/${VERSION_CODENAME}/main/binary-amd64
cd apt-repo
dpkg-scanpackages --arch amd64 pool/ > dists/${VERSION_CODENAME}/main/binary-amd64/Packages
cat dists/${VERSION_CODENAME}/main/binary-amd64/Packages | gzip -9 > dists/${VERSION_CODENAME}/main/binary-amd64/Packages.gz
cd dists/${VERSION_CODENAME}
cat << EOF > Release
Origin: Samana Monitor Repository
Label: SAMM
Suite: ${VERSION_CODENAME}
Codename: ${VERSION_CODENAME}
Version: 1.0.0
Architectures: amd64
Components: main
Description: SAMM Samana Advanced Monitoring and Management repository
Date: $(date -Ru)
EOF
do_hash "MD5Sum" "md5sum" >> Release
do_hash "SHA1" "sha1sum" >> Release
do_hash "SHA256" "sha256sum" >> Release
cat Release | gpg --default-key SamanaMonitor -abs > Release.gpg
cat Release | gpg --default-key SamanaMonitor -abs --clearsign > InRelease

