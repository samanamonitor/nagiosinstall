FROM ubuntu:bionic AS nagiosbuild
RUN mkdir /usr/src/samanamonitor
RUN apt update; apt install -y build-essential autoconf python wget unzip
WORKDIR /usr/src/samanamonitor
COPY build_container.sh /usr/src/samanamonitor
COPY config.dat /usr/src/samanamonitor
ENTRYPOINT [ "./build_container.sh" ]