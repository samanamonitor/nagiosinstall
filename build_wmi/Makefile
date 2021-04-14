all:
	$(eval VOL_OPT := $(docker volume ls -f name=nagios_opt -q))
	ifeq ($(VOL_OPT), "")
		docker volume create nagios_opt
	endif
	docker build -t wmi .
	docker run --rm --mount source=nagios_opt,target=/opt wmi

