#!/bin/bash

VERSION_CODENAME=bionic
NP_PATH=/usr/src/sources/samanamonitor/nagios-plugins

cat Dockerfile.deb | docker build --tag sammbuild:${VERSION_CODENAME} --build-arg UBUNTU_VERSION=${VERSION_CODENAME} -

# -e SAMM_IP=${SAMM_IP} -p 8080:80 
docker run -it --rm -e SAMM_PWD=${SAMM_PWD} \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild:${VERSION_CODENAME} ./create-samm-deb.sh

docker build --tag sammbuild2:${VERSION_CODENAME} \
    --build-arg UBUNTU_VERSION=${VERSION_CODENAME} \
    -f ./Dockerfile.build2  .

docker run -it --rm -e SAMM_DEB=/usr/src/nagiosinstall/samm-1.0.1-1_amd64.deb \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    --mount type=bind,source=${NP_PATH},target=/usr/src/nagios-plugins \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-plugins-deb.sh

docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-check-samana-deb.sh

docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-pnp4nagios-deb.sh

docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-nrpe-deb.sh


docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-pywmi-deb.sh

docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-pylib-deb.sh https://github.com/samanamonitor/pynag.git

docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-pylib-deb.sh https://github.com/samanamonitor/pysamana.git

docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall sammbuild2:${VERSION_CODENAME} ./create-samm-pylib-deb.sh https://github.com/samanamonitor/pysammwr.git

mkdir -p apt-repo/pool/main/${VERSION_CODENAME}
docker run -it --rm \
    --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall \
    -w /usr/src/nagiosinstall ubuntu:${VERSION_CODENAME} ./create-repo.sh ${VERSION_CODENAME}
cd apt-repo
aws s3 cp . s3://samm-repo/ --acl public-read --recursive
cd ..

mkdir temp
cp start.sh finalize-image.sh Dockerfile.final temp
cd temp
docker build --build-arg UBUNTU_VERSION=bionic --tag samm:v1.0.0 -f Dockerfile.final .
cd ..
rm -Rf temp

docker save samm:v1.0.0 > samm_v1.0.0.tar
gzip samm_v1.0.0.tar

docker run -it --name sm -p 80:80 -p 443:443 -d samm:v1.0.0
