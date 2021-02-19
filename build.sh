#!/bin/bash

apt -y install docker.io
docker build -t samanamon:v1 https://github.com/samanamonitor/nagiosinstall.git
docker save samanamonitor | gzip > samanamonitor.tgz
# upload samanamonitor.tgz to S3 and configure permissions
