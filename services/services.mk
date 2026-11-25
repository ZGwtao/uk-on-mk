# SPDX-License-Identifier: BSD-2-Clause

TARGET_SVC ?=

# $(1): service name; $(2): service-specific make arguments supplied by the
# caller. Service requirements (for example LIONSOS for RAMFS) therefore do
# not leak into the shared Unikraft or catalog-application interfaces.
define ukf_build_svc
	$(MAKE) -f $(UK_ON_MK_DIR)/uk.mk \
		$(UKF_COMMON_ARGS) \
		UK_ON_MK_DIR=$(UK_ON_MK_DIR) \
		BUILD_DIR=$(BUILD_DIR) \
		ARCH=$(ARCH) \
		TARGET_SVC=$(1) $(2) uk-service-build -j4
endef

# Service makefiles publish their own top-level build units. Their selected
# service identity and requirements remain guarded below, so merely exposing a
# RAMFS target does not impose RAMFS inputs on catalog applications.
include $(UK_ON_MK_DIR)/services/ramfs/ramfs.mk

# Validate a concrete service only for a service build. Keeping an empty
# selection empty means catalog applications do not inherit service inputs.
ifneq ($(strip $(TARGET_SVC)),)
ifneq ($(TARGET_SVC),ramfs)
$(error Unsupported TARGET_SVC '$(TARGET_SVC)')
endif
endif

ifneq ($(strip $(TARGET_SVC)),)
UKF_SVC_BUILD 	?= $(BUILD_DIR)/uk/$(TARGET_SVC)
UKF_SVC_ROOTFS 	?= $(UKF_SVC_DIR)/rootfs
UKF_SVC_INITRD 	:= $(UKF_SVC_BUILD)/initrd.cpio
UKF_SVC_CFG 		:= $(UKF_SVC_BUILD)/.cfg
UKF_SVC_PAYLOAD 	:= $(UKF_SVC_BUILD)/$(UKF_SVC_PAYLOAD_NAME)
UKF_SVC_ELF 		:= $(UKF_SVC_BUILD)/$(UKF_SVC_OUTPUT_NAME).elf

.PHONY: uk-service-build uk-service-initrd
uk-service-build: $(UKF_SVC_CFG) libsddf_util.a uk-service-initrd
	$(call ukf_make, 			\
		$(UKF_SVC_DIR), 		\
		$(UKF_SVC_BUILD), 	\
		$(UKF_SVC_LIBS), 	\
		$(UKF_SVC_ARGS))
	cp $(UKF_SVC_PAYLOAD) $(UKF_SVC_ELF)

uk-service-initrd:
	mkdir -p $(dir $(UKF_SVC_INITRD))
	rm -f $(UKF_SVC_INITRD)
	$(UKF_MKCPIO) $(UKF_SVC_INITRD) $(UKF_SVC_ROOTFS)

$(UKF_SVC_CFG): $(UKF_SVC_CFG_SRC) $(UKF_SVC_DIR)/Makefile.uk $(UK_ON_MK_DIR)/uk.mk
	$(call ukf_cfg,				\
		$(UKF_SVC_CFG_SRC),		\
		$(UKF_SVC_DIR),			\
		$(UKF_SVC_BUILD),		\
		$(UKF_SVC_LIBS),		\
		$(UKF_SVC_INITRD),		\
		$@,							\
		$(UKF_SVC_ARGS))
endif
