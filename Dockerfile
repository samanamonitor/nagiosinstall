FROM ubuntu:bionic AS nagiosbuild
RUN mkdir /usr/src/samanamonitor
WORKDIR /usr/src/samanamonitor
COPY build_container.sh /usr/src/samanamonitor
COPY config.dat /usr/src/samanamonitor
ENTRYPOINT [ "./build_container.sh" ]