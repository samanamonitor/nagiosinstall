IMAGE_NAME=nagiosbuild
VOLUME_NAME=nagios_opt


build_image:
	$(info Checking if build image exists)
	$(eval BUILD_IMAGE := $(shell docker images ${IMAGE_NAME} -q))
ifeq ("$(BUILD_IMAGE)", "")
	docker build -t ${IMAGE_NAME} . > $@
	$(info Build image created)
endif

build_volume:
	$(eval VOL_OPT := $(shell docker volume ls -f name=${VOLUME_NAME} -q))
ifeq ($(VOL_OPT), "")
	docker volume create ${VOLUME_NAME} > $@
endif
	
wmi: build_volume build_image
	docker run --rm --mount source=${VOLUME_NAME},target=/opt ${IMAGE_NAME} wmi

clean:
	-docker image rm ${IMAGE_NAME}
	rm -f build_image
	-docker volume rm ${VOLUME_NAME}
	rm -f build_volume