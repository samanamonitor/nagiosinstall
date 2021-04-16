FROM ubuntu:bionic AS samanamon
COPY apps.tar /opt
COPY start.sh /
WORKDIR /
RUN tar -xvf /opt/apps.tar; \
    rm /opt/apps.tar
ENTRYPOINT [ "./start.sh" ]