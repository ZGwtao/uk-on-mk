# SPDX-License-Identifier: BSD-2-Clause

# Shared Unikraft build primitives. Application and service policy lives in
# apps/apps.mk and services/services.mk respectively.
ifeq ($(strip $(UK_ON_MK_DIR)),)
UK_ON_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
endif

BM_UNIKRAFT_DIR := $(UK_ON_MK_DIR)/dep/unikraft
BM_UK_MKCPIO := $(BM_UNIKRAFT_DIR)/support/scripts/mkcpio

ifneq ($(filter aarch64 x86_64,$(ARCH)),$(ARCH))
$(error Unsupported ARCH '$(ARCH)'; expected aarch64 or x86_64)
endif

BM_UK_ARCH := $(ARCH)
ifeq ($(BM_UK_ARCH),aarch64)
BM_APP_ARCH := arm64
else
BM_APP_ARCH := $(BM_UK_ARCH)
endif

BM_UK_COMMON_MAKE_ARGS := \
	SDDF=$(SDDF) \
	MICROKIT_SDK=$(MICROKIT_SDK) \
	MICROKIT_BOARD=$(MICROKIT_BOARD) \
	MICROKIT_CONFIG=$(MICROKIT_CONFIG) \
	BOARD_DIR=$(BOARD_DIR) \
	SDDF_UTIL_LIB=$(abspath libsddf_util.a)

# $(1): source directory, $(2): build directory, $(3): libraries,
# $(4): additional Unikraft make arguments.
#
# $(strip ...) removes leading/trailing whitespace and folds internal runs of
# whitespace to one space. This protects arguments passed through a multi-line
# $(call ...), where indentation around $(1)..$(4) can otherwise become part of
# a path or make assignment; for example, "  $(BUILD_DIR)  " becomes
# "$(BUILD_DIR)" before it is used as O= and C=.
#
define uk_unikraft_make
	env -u BUILD_DIR -u MAKEFLAGS -u MAKEOVERRIDES \
		$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_COMMON_MAKE_ARGS) \
		A=$(strip $(1)) O=$(strip $(2)) C=$(strip $(2))/.config \
		L=$(strip $(3)) $(strip $(4)) -j4
endef

# $(1): defconfig, $(2): source directory, $(3): build directory,
# $(4): libraries, $(5): initrd, $(6): configured stamp,
# $(7): component-specific Unikraft make arguments.
define uk_unikraft_configure
	mkdir -p $(strip $(3))
	cp $(strip $(1)) $(strip $(3))/defconfig
	printf 'CONFIG_LIBVFSCORE_AUTOMOUNT_EINITRD_PATH="%s"\n' '$(strip $(5))' >> $(strip $(3))/defconfig
	$(call uk_unikraft_make, \
		$(strip $(2)), \
		$(strip $(3)), \
		$(strip $(4)), \
		CONFIG_LIBVFSCORE_AUTOMOUNT_EINITRD_PATH=$(strip $(5)) UK_DEFCONFIG=$(strip $(3))/defconfig defconfig $(strip $(7)))
	touch $(strip $(6))
endef

include $(UK_ON_MK_DIR)/apps/apps.mk
include $(UK_ON_MK_DIR)/services/services.mk
