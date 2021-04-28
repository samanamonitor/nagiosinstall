IMAGE_NAME=nagiosbuild
VOLUME_NAME=nagios_opt
INSTALL_DIR=/usr/src/install

COMPONENTS=build_wmi build_nagios build_nagios_plugins build_pnp4nagios build_check_wmi_plus build_nagiosinstall

nagiosinstall.tar: apps.tar
	docker build -t samanamon:v1 -f Dockerfile.install --output $@ .

apps.tar: $(COMPONENTS)
	docker run --rm --mount source=${VOLUME_NAME},target=/opt -v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${IMAGE_NAME} build_tarball > $@.log 2>&1


build_image: config.dat
	$(info Checking if build image exists)
	$(eval BUILD_IMAGE := $(shell docker images ${IMAGE_NAME} -q))
ifeq ("$(BUILD_IMAGE)", "")
	docker build -t ${IMAGE_NAME} . > $@
endif

build_volume:
	$(eval VOL_OPT := $(shell docker volume ls -f name=${VOLUME_NAME} -q))
ifeq ("$(VOL_OPT)", "")
	docker volume create ${VOLUME_NAME} > $@
endif

config.dat:
	cp config.dat.example config.dat
	
$(COMPONENTS): build_volume build_image
	docker run --rm --mount source=${VOLUME_NAME},target=/opt -v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${IMAGE_NAME} $@ > $@ 2>&1

clean:
	-docker image rm ${IMAGE_NAME}
	rm -f build_image
	-docker volume rm ${VOLUME_NAME}
	rm -f build_volume
	rm -f $(COMPONENTS)
	rm -f config.dat
	rm -f apps.tar