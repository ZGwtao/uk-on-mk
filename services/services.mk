# SPDX-License-Identifier: BSD-2-Clause

BM_UK_SERVICE ?=

# $(1): service name; $(2): service-specific make arguments supplied by the
# caller. Service requirements (for example LIONSOS for RAMFS) therefore do
# not leak into the shared Unikraft or catalog-application interfaces.
define uk_build_service
	$(MAKE) -f $(UK_ON_MK_DIR)/uk.mk \
		$(BM_UK_COMMON_MAKE_ARGS) \
		UK_ON_MK_DIR=$(UK_ON_MK_DIR) \
		BUILD_DIR=$(BUILD_DIR) \
		ARCH=$(ARCH) \
		BM_UK_SERVICE=$(1) $(2) uk-service-build -j4
endef

# Service makefiles publish their own top-level build units. Their selected
# service identity and requirements remain guarded below, so merely exposing a
# RAMFS target does not impose RAMFS inputs on catalog applications.
include $(UK_ON_MK_DIR)/services/ramfs/ramfs.mk

# Validate a concrete service only for a service build. Keeping an empty
# selection empty means catalog applications do not inherit service inputs.
ifneq ($(strip $(BM_UK_SERVICE)),)
ifneq ($(BM_UK_SERVICE),ramfs)
$(error Unsupported BM_UK_SERVICE '$(BM_UK_SERVICE)')
endif
endif

ifneq ($(strip $(BM_UK_SERVICE)),)
UK_SERVICE_BUILD 		?= $(BUILD_DIR)/uk/$(BM_UK_SERVICE)
UK_SERVICE_ROOTFS_DIR 	?= $(UK_SERVICE_DIR)/rootfs
UK_SERVICE_INITRD 		:= $(UK_SERVICE_BUILD)/initrd.cpio
UK_SERVICE_CONFIG_STAMP := $(UK_SERVICE_BUILD)/.configured
UK_SERVICE_PAYLOAD_ELF 	:= $(UK_SERVICE_BUILD)/$(UK_SERVICE_PAYLOAD_NAME)
UK_SERVICE_ELF 			:= $(UK_SERVICE_BUILD)/$(UK_SERVICE_OUTPUT_NAME).elf

.PHONY: uk-service-build uk-service-initrd
uk-service-build: $(UK_SERVICE_CONFIG_STAMP) libsddf_util.a uk-service-initrd
	$(call uk_unikraft_make, 	\
		$(UK_SERVICE_DIR), 		\
		$(UK_SERVICE_BUILD), 	\
		$(UK_SERVICE_LIBS), 	\
		CONFIG_LIBVFSCORE_AUTOMOUNT_EINITRD_PATH=$(UK_SERVICE_INITRD) \
		$(UK_SERVICE_MAKE_ARGS))
	cp $(UK_SERVICE_PAYLOAD_ELF) $(UK_SERVICE_ELF)

uk-service-initrd:
	mkdir -p $(dir $(UK_SERVICE_INITRD))
	rm -f $(UK_SERVICE_INITRD)
	$(BM_UK_MKCPIO) $(UK_SERVICE_INITRD) $(UK_SERVICE_ROOTFS_DIR)

$(UK_SERVICE_CONFIG_STAMP): $(UK_SERVICE_CONFIG) $(UK_SERVICE_DIR)/Makefile.uk $(UK_ON_MK_DIR)/uk.mk
	$(call uk_unikraft_configure,	\
		$(UK_SERVICE_CONFIG),		\
		$(UK_SERVICE_DIR),			\
		$(UK_SERVICE_BUILD),		\
		$(UK_SERVICE_LIBS),			\
		$(UK_SERVICE_INITRD),		\
		$@,							\
		$(UK_SERVICE_MAKE_ARGS))
endif
