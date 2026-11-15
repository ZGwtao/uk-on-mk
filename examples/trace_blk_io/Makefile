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
export MODE ?= native

export COROS ?= 8
export COMPUTE_COROS ?= 1
export COREMARK_ITERS_PER_YIELD ?= 1
export BENCH_SECONDS ?= 10
# Solo5: run a compute slice after each I/O when 1; when 0, run one
# compute slice after all I/O coroutines. Default to exposing the gap
# between synchronous reads while the unikernel computes.
export SOLO5_INTERLEAVE_COMPUTE ?= 1

export LIBMICROKITCO_PATH ?= $(ROOT)/dep/libmicrokitco

.PHONY: all qemu disk clean FORCE
all: $(BUILD_DIR)/$(MODE).img

qemu $(BUILD_DIR)/$(MODE).img disk clean: $(BUILD_DIR)/Makefile FORCE
	$(MAKE) -C $(BUILD_DIR) BUILD_DIR=$(BUILD_DIR) $(notdir $@)

$(BUILD_DIR)/Makefile: unikernel.mk
	mkdir -p $(BUILD_DIR)
	cp $< $@

FORCE:
