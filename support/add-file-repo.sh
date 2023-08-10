#!/bin/bash

set -xe

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

source /etc/os-release
VERSION_NUMBER=1.0.0
PKG_FILE=$1

if [ ! -f ${PKG_FILE} ]; then
    echo "Package file not available" >&2
    exit 1
fi
if [ ! -f Packages ]; then
    echo "To continue, download the Packages file from current repo" > &2
    exit 1
fi
if [ ! -f pgp-key.private ]; then
    echo "To continue, download the private key to current directory" >&2
    exit 1
fi

apt update && apt install -y dpkg-dev awscli

CURDIR=/usr/src
DISTS_DIR=dists/${VERSION_CODENAME}
PACKAGE_DIR=${DISTS_DIR}/main/binary-amd64
POOL_DIR=pool/main/${VERSION_CODENAME}
TEMPDIR=$(mktemp -d ./repo-XXXXX)
mkdir -p ${CURDIR}/gpg

export GNUPGHOME="$(mktemp -d ${CURDIR}/gpg/pgpkeys-XXXXXX)"

cat pgp-key.private | gpg --import

mkdir -p ${TEMPDIR}/${PACKAGE_DIR}
mkdir -p ${TEMPDIR}/${POOL_DIR}
cp Packages ${TEMPDIR}/${PACKAGE_DIR}
cp ${PKG_FILE} ${TEMPDIR}/POOL_DIR

cd ${TEMPDIR}
PKG_NAME=$(dpkg-deb -f ${POOL_DIR}/${PKG_FILE} Package)
# Delete package info if it exists
sed -i "/^Package: ${PKG_NAME}$/,/^$/d" ${PACKAGE_DIR}/Packages
# Adds package info
echo "" >> ${PACKAGE_DIR}/Packages
dpkg-scanpackages ${POOL_DIR} >> ${PACKAGE_DIR}/Packages
cat ${PACKAGE_DIR}/Packages | gzip -9  > ${PACKAGE_DIR}/Packages.gz

cat << EOF > ${DISTS_DIR}/Release
Origin: Samana Monitor Repository
Label: SAMM
Suite: ${VERSION_CODENAME}
Codename: ${VERSION_CODENAME}
Version: ${VERSION_NUMBER}
Architectures: amd64
Components: main
Description: SAMM Samana Advanced Monitoring and Management repository
Date: $(date -Ru)
EOF
do_hash "MD5Sum" "md5sum" >> ${DISTS_DIR}/Release
do_hash "SHA1" "sha1sum" >> ${DISTS_DIR}/Release
do_hash "SHA256" "sha256sum" >> ${DISTS_DIR}/Release
cat ${DISTS_DIR}/Release | gpg --default-key SamanaMonitor -abs > ${DISTS_DIR}/Release.gpg
cat ${DISTS_DIR}/Release | gpg --default-key SamanaMonitor -abs --clearsign > ${DISTS_DIR}/InRelease

# Upload all files to repo
aws s3 cp ${POOL_DIR}/${PKG_FILE} s3://samm-repo/${POOL_DIR}/
aws s3 cp ${PACKAGE_DIR}/Packages ${PACKAGE_DIR}/Packages.gz s3://samm-repo/${PACKAGE_DIR}/
aws s3 cp ${DISTS_DIR}/Release ${DISTS_DIR}/Release.gpg ${DISTS_DIR}/InRelease s3://samm-repo/${DISTS_DIR}/
