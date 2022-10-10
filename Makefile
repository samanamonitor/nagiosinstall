BUILD_IMAGE_NAME=nagiosbuild
VOLUME_NAME=usr_local
INSTALL_DIR=/usr/src/install
IMAGE_NAME=samanamon:v2.0

COMPONENTS=build_nagios build_nagios_plugins build_pnp4nagios build_nagiosinstall

nagiosinstall.tar.gz: apps.tar
	docker build -t $(IMAGE_NAME) -f Dockerfile.install .
	docker save $(IMAGE_NAME) | gzip > $@
	docker image rm $(IMAGE_NAME)

publish: nagiosinstall.tar.gz
	aws s3 cp $< s3://monitor.samanagroup.co --acl public-read

apps.tar: $(COMPONENTS)
	docker run --rm --mount source=${VOLUME_NAME},target=/usr/local -v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${BUILD_IMAGE_NAME} build_tarball > $@.log 2>&1


build_image: config.dat
	$(info Checking if build image exists)
	$(eval BI := $(shell docker images ${BUILD_IMAGE_NAME} -q))
ifeq ("$(BI)", "")
	docker build -t ${BUILD_IMAGE_NAME} . > $@
endif

build_volume:
	$(eval VOL_USRL := $(shell docker volume ls -f name=${VOLUME_NAME} -q))
ifeq ("$(VOL_USRL)", "")
	docker volume create ${VOLUME_NAME} > $@
endif

config.dat:
	cp build_config.dat.example config.dat
	
$(COMPONENTS): build_volume build_image
	docker run --rm --mount source=${VOLUME_NAME},target=/usr/local -v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${BUILD_IMAGE_NAME} $@ > $@ 2>&1

clean:
	-docker image rm ${BUILD_IMAGE_NAME}
	-docker volume rm ${VOLUME_NAME}
	rm -f build_image build_volume $(COMPONENTS) config.dat apps.tar
