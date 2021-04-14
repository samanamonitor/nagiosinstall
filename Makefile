
build_image:
	$(info Checking if build image exists)
	$(eval BUILD_IMAGE := $(shell docker images nagiosbuild -q))
ifeq ("$(BUILD_IMAGE)", "")
	docker build -t nagiosbuild . > $@
	$(info Build image created)
endif

build_volume:
	$(eval VOL_OPT := $(shell docker volume ls -f name=nagios_opt -q))
ifeq ($(VOL_OPT), "")
	docker volume create nagios_opt > $@
endif
	
wmi: build_volume build_image
	docker run --rm --mount source=nagios_opt,target=/opt nagiosbuild wmi

clean:
	docker image rm nagiosbuild
	rm build_image
	docker volume rm nagios_opt
	rm build_volume