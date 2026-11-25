# SPDX-License-Identifier: BSD-2-Clause

UKF_CATALOG_DIR := $(UK_ON_MK_DIR)/apps/catalog
CATALOG_REPO 	:= $(UK_ON_MK_DIR)/dep/catalog-core
CATALOG_LIB_DIR := $(CATALOG_REPO)/repos/libs

TARGET_APP 		?= sqlite
# We provide out-of-tree entry (i.e., a main.c outside dep/catalog-core)
# for each application to build. By doing so, we can make customisation
# to the app while keeping dep/catalog-core clean.
# The out-of-tree entries are in $(UK_ON_MK)/apps/catalog/$(YOUR_APP)
UKF_APP_ENTRY 	:= $(UKF_CATALOG_DIR)/$(TARGET_APP)
UKF_APP_MK 		:= $(UKF_APP_ENTRY)/$(TARGET_APP).mk

ifeq ($(wildcard $(UKF_APP_MK)),)
$(error Unsupported TARGET_APP '$(TARGET_APP)')
endif
include $(UKF_APP_MK)

UKF_APP_DIR 	:= $(CATALOG_REPO)/$(TARGET_APP)
UKF_APP_BUILD 	:= $(BUILD_DIR)/uk/$(TARGET_APP)
UKF_APP_CFG 	:= $(UKF_APP_BUILD)/.cfg

UKF_APP_INITRD 	:= $(UKF_APP_BUILD)/initrd.cpio
UKF_APP_ROOTFS 	?= $(UKF_APP_DIR)/rootfs
UKF_APP_ELF 	?= unikraft-$(TARGET_APP).elf
ifneq ($(strip $(UKF_APP_NEEDS_INITRD)),)
uk-catalog-build: uk-catalog-initrd
endif

.PHONY: \
	uk-catalog-build \
	uk-catalog-setup \
	uk-catalog-initrd

uk-catalog-build: $(UKF_APP_CFG) libsddf_util.a $(UKF_APP_ENTRY)/main.c
	$(call ukf_make,		\
		$(UKF_APP_DIR),		\
		$(UKF_APP_BUILD),	\
		$(UKF_APP_LIBS),	\
		$(UKF_APP_MAIN_VAR)=$(UKF_APP_ENTRY)/main.c)
	cp $(UKF_APP_BUILD)/$(TARGET_APP)_default-$(UKF_ELF_ARCH) \
		$(UKF_APP_BUILD)/$(TARGET_APP).elf


uk-catalog-setup:
	mkdir -p $(CATALOG_REPO)/repos/libs \
				$(CATALOG_REPO)/repos/apps
	cd $(CATALOG_REPO) && ./setup.sh
	cd $(UKF_APP_DIR) && ./setup.sh

uk-catalog-initrd:
	mkdir -p $(dir $(UKF_APP_INITRD))
	rm -f $(UKF_APP_INITRD)
	$(UKF_MKCPIO) $(UKF_APP_INITRD) $(UKF_APP_ROOTFS)


$(UKF_APP_CFG): $(UKF_APP_ENTRY)/config/$(UKF_ARCH)/defconfig \
				$(UKF_CATALOG_DIR)/catalog.mk 	\
				$(UK_ON_MK_DIR)/uk.mk			\
				$(UKF_APP_MK) | uk-catalog-setup
	$(call ukf_cfg,				\
		$(UKF_APP_ENTRY)/config/$(UKF_ARCH)/defconfig, \
		$(UKF_APP_DIR),			\
		$(UKF_APP_BUILD),		\
		$(UKF_APP_LIBS),		\
		$(UKF_APP_INITRD),		\
		$@,							\
		$(UKF_APP_MAIN_VAR)=$(UKF_APP_ENTRY)/main.c)

$(UKF_APP_ELF): uk-catalog-build
	cp $(UKF_APP_BUILD)/$(TARGET_APP).elf $@
