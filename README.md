*Samana Nagios Installer*

Requirements: Ubuntu 16.04 (xenial)

Instructions:

* sudo apt install -y git
* git clone https://github.com/samanamonitor/nagiosinstall.git
* cd nagiosinstall
* cp config.dat.example config.dat
* *Modify config.dat file with necessary data*
* sudo ./install_container.sh