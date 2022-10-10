FROM ubuntu:jammy AS nagiosbuild
RUN apt update; apt install -y build-essential autoconf python wget unzip git
WORKDIR /usr/src/install
ENTRYPOINT [ "./build_container.sh" ]