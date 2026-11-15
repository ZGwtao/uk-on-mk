# SPDX-License-Identifier: BSD-2-Clause

ifeq ($(strip $(MICROKIT_SDK)),)
$(error MICROKIT_SDK must be specified)
endif

ifeq ($(strip $(MICROKIT_BOARD)),)
$(error MICROKIT_BOARD must be specified)
endif
BUILD_DIR ?= build
override BUILD_DIR := $(abspath ${BUILD_DIR})
override MICROKIT_SDK := $(abspath ${MICROKIT_SDK})

export ROOT := $(abspath ../..)
export EXAMPLE_DIR := $(abspath .)
export MICROKIT_CONFIG ?= debug
export DEMKI_APP ?= udp-echo

IMAGE_FILE := $(BUILD_DIR)/demikernel.img

.PHONY: all qemu clean FORCE
all: $(IMAGE_FILE)

qemu $(IMAGE_FILE): $(BUILD_DIR)/Makefile FORCE
	$(MAKE) -C $(BUILD_DIR) $(notdir $@)

$(BUILD_DIR)/Makefile: unikernel.mk
	mkdir -p $(BUILD_DIR)
	cp $< $@

clean:
	rm -rf $(BUILD_DIR)

FORCE:
