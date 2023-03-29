*Samana Nagios Installer*

Requirements: Ubuntu 16.04 (xenial)

Instructions:

* sudo apt install -y git
* git clone https://github.com/samanamonitor/nagiosinstall.git
* cd nagiosinstall
* cp config.dat.example config.dat
* *Modify config.dat file with necessary data*
* sudo ./install_container.sh

*deb Package Creation*
https://earthly.dev/blog/creating-and-hosting-your-own-deb-packages-and-apt-repo/

*Create container to build*
docker run -it --rm -e DEBIAN_FRONTEND="noninteractive" -e SAMM_IP=192.1678.69.11 --mount type=bind,source=$(pwd),target=/usr/src/nagiosinstall -p 8080:80 -w /usr/src/nagiosinstall ubuntu:bionic /bin/bash
