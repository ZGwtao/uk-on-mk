#
# Copyright 2023, UNSW
#
# SPDX-License-Identifier: BSD-2-Clause
#
# This Makefile is copied into the build directory
# and operated on from there.
#

ifeq ($(strip $(MICROKIT_SDK)),)
$(error MICROKIT_SDK must be specified)
endif

ifeq ($(strip $(SDDF)),)
$(error SDDF must be specified)
endif

IMAGE_FILE = demikernel.img
REPORT_FILE = report.txt
BUILD_DIR ?= build
MICROKIT_CONFIG ?= debug
TOOLCHAIN ?= clang
PYTHON ?= $(ROOT)/pyenv/bin/python

SUPPORTED_BOARDS := qemu_virt_aarch64

RUST_TARGET := aarch64-sel4-microkit-minimal
RUST_TARGET_JSON := $(EXAMPLE_DIR)/support/targets/$(RUST_TARGET).json

SDDF_CUSTOM_LIBC := 1
include ${SDDF}/tools/make/sddf.mk
include $(ROOT)/dep/demikernel/examples/rust/sddf.mk

TOP := $(ROOT)/examples/demikernel
METAPROGRAM := $(TOP)/meta.py
SYSTEM_FILE := demikernel.system

IMAGES := $(APP_ELF) eth_driver.elf network_virt_rx.elf \
	  network_virt_tx.elf network_copy.elf timer_driver.elf
CFLAGS += -DSDDF_VIRTIO_PCI_TRANSPORT_SKIP_BUS_CHECK

LDFLAGS := -L$(BOARD_DIR)/lib -L$(SDDF)/lib
LIBS := --start-group -lmicrokit -Tmicrokit.ld libsddf_util_debug.a --end-group

CFLAGS += \
	-I${SDDF}/include \
	-I${SDDF}/include/microkit

${IMAGES}: libsddf_util_debug.a

dummy_config_types.o: $(TOP)/dummy_config_types.c
	$(CC) --target=aarch64-none-elf -g -c $< \
		-I$(BOARD_DIR)/include \
		-I$(SDDF)/include \
		-I$(SDDF)/include/microkit \
		-I$(SDDF)/include/sddf/util/custom_libc \
		-o $@

$(SYSTEM_FILE): $(METAPROGRAM) dummy_config_types.o $(IMAGES) $(DTB)
ifneq ($(strip $(DTS)),)
	PYTHONPATH=$(SDDF) $(PYTHON) -B $(METAPROGRAM) --sddf $(SDDF) --board $(MICROKIT_BOARD) --dtb $(DTB) --output . --sdf $(SYSTEM_FILE)
else
	$(error A device tree is required for qemu_virt_aarch64)
endif
	$(OBJCOPY) --update-section .device_resources=eth_driver_device_resources.data eth_driver.elf
	$(OBJCOPY) --update-section .net_driver_config=eth_driver_net_driver_config.data eth_driver.elf
	$(OBJCOPY) --update-section .net_virt_rx_config=network_virt_rx_net_virt_rx_config.data network_virt_rx.elf
	$(OBJCOPY) --update-section .net_virt_tx_config=network_virt_tx_net_virt_tx_config.data network_virt_tx.elf
	$(OBJCOPY) --update-section .net_copy_config=network_copy_net_copy_config.data network_copy.elf
	$(OBJCOPY) --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	$(OBJCOPY) --update-section .timer_client_config=demikernel_timer_client_config.data demikernel.elf
	$(OBJCOPY) --update-section .net_client_config=demikernel_net_client_config.data demikernel.elf
	touch $@

$(IMAGE_FILE) $(REPORT_FILE): $(IMAGES) $(SYSTEM_FILE)
	MICROKIT_SDK=${MICROKIT_SDK} $(MICROKIT_TOOL) $(SYSTEM_FILE) --search-path $(BUILD_DIR) --board $(MICROKIT_BOARD) --config $(MICROKIT_CONFIG) -o $(IMAGE_FILE) -r $(REPORT_FILE)

qemu: ${IMAGE_FILE}
	$(QEMU) $(QEMU_ARCH_ARGS) $(QEMU_NET_ARGS) \
		-nographic \
		-netdev user,id=netdev0,hostfwd=udp::1235-10.0.2.15:1235 \
		-global virtio-mmio.force-legacy=false \
		-d guest_errors -smp 4

clean::
	${RM} -f *.elf
	find . -name '*.[od]' | xargs ${RM} -f

clobber:: clean
	${RM} -f ${IMAGE_FILE} ${REPORT_FILE}
