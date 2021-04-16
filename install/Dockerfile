FROM ubuntu:bionic AS samanamon
COPY apps.tar /opt
COPY start.sh /
WORKDIR /opt
RUN tar -xvf apps.tar
RUN rm apps.tar
WORKDIR /
ENTRYPOINT [ "./start.sh" ]