FROM ubuntu:bionic
EXPOSE 80
EXPOSE 443
EXPOSE 2379
ONBUILD RUN apt update
ONBUILD RUN apt install -y git
ONBUILD RUN mkdir /usr/src/samanamonitor
ONBUILD RUN git clone https://github.com/samanamonitor/nagiosinstall.git /usr/src/samanamonitor/nagiosinstall
ONBUILD WORKDIR /usr/src/samanamonitor/nagiosinstall/
ONBUILD RUN cp config.dat.example config.dat
ONBUILD RUN ./install_openstack.sh installall
RUN /start.sh