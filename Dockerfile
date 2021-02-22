FROM ubuntu:bionic AS samanamon
EXPOSE 80
EXPOSE 443
EXPOSE 2379
RUN apt update
RUN apt install -y git
RUN mkdir /usr/src/samanamonitor
RUN git clone https://github.com/samanamonitor/nagiosinstall.git /usr/src/samanamonitor/nagiosinstall
WORKDIR /usr/src/samanamonitor/nagiosinstall/
RUN cp build_config.dat.example config.dat
RUN ./install_openstack.sh installall