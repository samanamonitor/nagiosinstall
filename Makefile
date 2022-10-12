BUILD_IMAGE_NAME=nagiosbuild
VOLUME_NAME=usr_local
INSTALL_DIR=/usr/src/install
IMAGE_NAME=samanamon:v2.0
IMAGE_URL=s3://monitor.samanagroup.co/$(subst :,_,$(IMAGE_NAME)).tar.gz
DIST_VERSION=ubuntu:jammy
LOG_FILE=build.log

COMPONENTS=build_nagios.done \
	build_nagios_plugins.done \
	build_pnp4nagios.done \
	build_nagiosinstall.done

nagiosinstall.tar.gz: apps.tar Dockerfile.install
	$(info Creating image with all apps)
	docker build -t $(IMAGE_NAME) -f Dockerfile.install . >> $(LOG_FILE) 2>&1
	docker save $(IMAGE_NAME) | gzip > $@
	docker image rm $(IMAGE_NAME)

publish: nagiosinstall.tar.gz
	aws s3 cp $< $(IMAGE_URL) --acl public-read

apps.tar: $(COMPONENTS)
	$(info Creating apps tarball)
	docker run --rm --mount source=${VOLUME_NAME},target=/usr/local \
		-v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${BUILD_IMAGE_NAME} \
		build_tarball >> $(LOG_FILE) 2>&1

build_image.done: build_config.dat Dockerfile.build
	$(info Checking if build image exists)
	$(eval BI := $(shell docker images ${BUILD_IMAGE_NAME} -q))
ifeq ("$(BI)", "")
	docker build -t ${BUILD_IMAGE_NAME} -f Dockerfile.build . >> $(LOG_FILE) 2>&1
endif
	touch $@

Dockerfile.build Dockerfile.install:
	sed -e "s/%DIST_VERSION%/$(DIST_VERSION)/" $@.template > $@

build_config.dat:
	sed -e "s/%IMAGE_NAME%/$(IMAGE_NAME)/" $@.example > $@

build_volume.done:
	$(info Creating build volume)
	$(eval VOL_USRL := $(shell docker volume ls -f name=${VOLUME_NAME} -q))
ifeq ("$(VOL_USRL)", "")
	docker volume create ${VOLUME_NAME} >> $(LOG_FILE) 2>&1
endif
	touch $@
	
$(COMPONENTS): build_volume.done build_image.done
	$(info Building $@)
	docker run --rm --mount source=${VOLUME_NAME},target=/usr/local \
		-v `pwd`:$(INSTALL_DIR) -w $(INSTALL_DIR) ${BUILD_IMAGE_NAME} $(subst .done,,$@) >> $(LOG_FILE) 2>&1
	touch $@

clean:
	-docker image rm ${BUILD_IMAGE_NAME}
	-docker volume rm ${VOLUME_NAME}
	rm -f build_image.done build_volume.done $(COMPONENTS) \
		config.dat apps.tar image_tarball nagiosinstall.tar.gz \
		Dockerfile.build Dockerfile.install \
		build_config.dat $(LOG_FILE)
