FROM ubuntu:bionic AS wmi
RUN mkdir /usr/src/samanamonitor
WORKDIR /usr/src/samanamonitor
COPY build.sh /usr/src/samanamonitor
ENTRYPOINT [ "./build.sh" ]