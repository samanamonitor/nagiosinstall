
build_image:
	$(eval BUILD_IMAGE := $(shell docker images nagiosbuild -q))
ifeq ($(BUILD_IMAGE), "")
	docker build -t nagiosbuild . > build_image
endif

build_volume:
	$(eval VOL_OPT := $(shell docker volume ls -f name=nagios_opt -q))
ifeq ($(VOL_OPT), "")
	docker volume create nagios_opt > build_volume
endif
	
wmi: build_volume build_image
	docker run --rm --mount source=nagios_opt,target=/opt nagiosbuild wmi

