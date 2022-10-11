BUILD_IMAGE_NAME=nagiosbuild
VOLUME_NAME=usr_local
INSTALL_DIR=/usr/src/install
IMAGE_NAME=samanamon:v2.0
IMAGE_URL=s3://monitor.samanagroup.co/$(subst :,_,$(IMAGE_NAME)).tar.gz
DIST_VERSION=ubuntu:jammy

COMPONENTS=build_nagios build_nagios_plugins build_pnp4nagios build_nagiosinstall

nagiosinstall.tar.gz: apps.tar Dockerfile.install
	$(info Creating image with all apps)
	docker build -t $(IMAGE_NAME) -f Dockerfile.install . > image_tarball 2>&1
	docker save $(IMAGE_NAME) | gzip > $@
	docker image rm $(IMAGE_NAME)

publish: nagiosinstall.tar.gz
	aws s3 cp $< $(IMAGE_URL) --acl public-read

apps.tar: $(COMPONENTS)
	$(info Creating apps tarball)
	docker run --rm --mount source=${VOLUME_NAME},target=/usr/local -v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${BUILD_IMAGE_NAME} build_tarball > $@.log 2>&1

build_image: build_config.dat Dockerfile.build
	$(info Checking if build image exists)
	$(eval BI := $(shell docker images ${BUILD_IMAGE_NAME} -q))
ifeq ("$(BI)", "")
	docker build -t ${BUILD_IMAGE_NAME} -f Dockerfile.build . > $@ 2>&1
endif

Dockerfile.build Dockerfile.install:
	sed -e "s/%DIST_VERSION%/$(DIST_VERSION)/" $@.template > $@

build_config.dat:
	sed -e "s/%IMAGE_NAME%/$(IMAGE_NAME)/" $@.example > $@

build_volume:
	$(info Creating build volume)
	$(eval VOL_USRL := $(shell docker volume ls -f name=${VOLUME_NAME} -q))
ifeq ("$(VOL_USRL)", "")
	docker volume create ${VOLUME_NAME} > $@ 2>&1
endif
	
$(COMPONENTS): build_volume build_image
	$(info Building $@)
	docker run --rm --mount source=${VOLUME_NAME},target=/usr/local -v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${BUILD_IMAGE_NAME} $@ > $@ 2>&1

clean:
	-docker image rm ${BUILD_IMAGE_NAME}
	-docker volume rm ${VOLUME_NAME}
	rm -f build_image build_volume $(COMPONENTS) \
		config.dat apps.tar* image_tarball nagiosinstall.tar.gz \
		Dockerfile.build Dockerfile.install \
		build_config.dat
