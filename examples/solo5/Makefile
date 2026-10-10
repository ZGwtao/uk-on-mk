# SPDX-License-Identifier: BSD-2-Clause

ifeq ($(strip $(MICROKIT_SDK)),)
$(error MICROKIT_SDK must be specified)
endif
override MICROKIT_SDK := $(abspath $(MICROKIT_SDK))

export ROOT ?= $(abspath ../..)
export EXAMPLE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export MICROKIT_CONFIG ?= debug
export BUILD_DIR ?= $(abspath build)
export MICROKIT_BOARD ?= qemu_virt_aarch64

IMAGE_FILE := $(BUILD_DIR)/solo5-on-mk.img
REPORT_FILE := $(BUILD_DIR)/report.txt

.PHONY: all qemu system clean FORCE

all: $(IMAGE_FILE)

qemu system clean: $(BUILD_DIR)/Makefile FORCE
	$(MAKE) -C $(BUILD_DIR) MICROKIT_SDK=$(MICROKIT_SDK) $(notdir $@)

$(IMAGE_FILE) $(REPORT_FILE): $(BUILD_DIR)/Makefile FORCE
	$(MAKE) -C $(BUILD_DIR) MICROKIT_SDK=$(MICROKIT_SDK) $(notdir $@)

$(BUILD_DIR)/Makefile: unikernel.mk Makefile
	mkdir -p $(BUILD_DIR)
	echo "export ROOT ?= $(ROOT)" > $@
	echo "export EXAMPLE_DIR ?= $(EXAMPLE_DIR)" >> $@
	echo "export BUILD_DIR := $(BUILD_DIR)" >> $@
	echo "export MICROKIT_BOARD ?= $(MICROKIT_BOARD)" >> $@
	echo "export MICROKIT_SDK ?= $(MICROKIT_SDK)" >> $@
	echo "export MICROKIT_CONFIG ?= $(MICROKIT_CONFIG)" >> $@
	cat unikernel.mk >> $@

FORCE:
