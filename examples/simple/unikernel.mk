#
# Copyright 2026, UNSW
#
# SPDX-License-Identifier: BSD-2-Clause
#
IMAGES := \
	unikraft.elf \
	timer_driver.elf \
	serial_driver.elf \
	serial_virt_rx.elf \
	serial_virt_tx.elf \
	eth_driver.elf \
	network_virt_rx.elf \
	network_virt_tx.elf \
	network_copy.elf

SUPPORTED_BOARDS:= \
	qemu_virt_aarch64

TOOLCHAIN ?= clang
OBJCOPY = aarch64-none-elf-objcopy
MICROKIT_TOOL ?= $(MICROKIT_SDK)/bin/microkit
SDDF := $(ROOT)/dep/sddf
SYSTEM_FILE := uk-on-mk.system
IMAGE_FILE := uk-on-mk.img
REPORT_FILE := report.txt


all: ${IMAGE_FILE}

include ${SDDF}/tools/make/board/common.mk

METAPROGRAM := $(UK_DIR)/meta.py
ETHERNET_DRIVER := $(SDDF)/drivers/network/$(NET_DRIV_DIR)
NETWORK_COMPONENTS := $(SDDF)/network/components

CFLAGS += \
	-I$(LIONSOS)/include \
	-I$(SDDF)/include \
	-I$(SDDF)/include/microkit

LDFLAGS := -L$(BOARD_DIR)/lib
LIBS := -lmicrokit -Tmicrokit.ld libsddf_util_debug.a

SDDF_CUSTOM_LIBC := 1
include ${SDDF}/util/util.mk
include ${SDDF}/drivers/timer/${TIMER_DRIV_DIR}/timer_driver.mk
include ${SDDF}/drivers/serial/${UART_DRIV_DIR}/serial_driver.mk
include ${SDDF}/serial/components/serial_components.mk
include ${SDDF}/network/components/network_components.mk
include ${ETHERNET_DRIVER}/eth_driver.mk


%.py: ${UK_DIR}/%.py
	cp $< $@

include $(ROOT)/uk.mk

${IMAGES}: libsddf_util_debug.a

FORCE:

$(SYSTEM_FILE): $(METAPROGRAM) $(IMAGES) $(DTB)
	PYTHONPATH=${SDDF}/tools/meta:$$PYTHONPATH $(PYTHON) -B $(METAPROGRAM) \
	--sddf $(SDDF) --board $(MICROKIT_BOARD) --dtb $(DTB) --objcopy aarch64-none-elf-objcopy \
	--output . --sdf $(SYSTEM_FILE)
	$(OBJCOPY) --update-section .device_resources=ethernet_driver_device_resources.data eth_driver.elf
	$(OBJCOPY) --update-section .net_driver_config=net_driver.data eth_driver.elf
	$(OBJCOPY) --update-section .net_virt_rx_config=net_virt_rx.data network_virt_rx.elf
	$(OBJCOPY) --update-section .net_virt_tx_config=net_virt_tx.data network_virt_tx.elf
	$(OBJCOPY) --update-section .net_copy_config=net_copy_net_copier.data network_copy.elf
	$(OBJCOPY) --update-section .device_resources=serial_driver_device_resources.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_driver_config=serial_driver_config.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_virt_tx_config=serial_virt_tx.data serial_virt_tx.elf
	$(OBJCOPY) --update-section .serial_virt_rx_config=serial_virt_rx.data serial_virt_rx.elf
	$(OBJCOPY) --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	aarch64-none-elf-objcopy --update-section .serial_client_config=serial_client_unikraft.data unikraft.elf
	aarch64-none-elf-objcopy --update-section .timer_client_config=timer_client_unikraft.data unikraft.elf
	aarch64-none-elf-objcopy --update-section .net_client_config=net_client_unikraft.data unikraft.elf

$(IMAGE_FILE) $(REPORT_FILE): $(IMAGES) $(SYSTEM_FILE)
	$(MICROKIT_TOOL) $(SYSTEM_FILE) \
		--search-path $(BUILD_DIR) --board $(MICROKIT_BOARD) 	\
		--config $(MICROKIT_CONFIG) -o $(IMAGE_FILE) -r $(REPORT_FILE)

qemu: ${IMAGE_FILE}
	$(QEMU) -machine virt,virtualization=on \
		-cpu cortex-a53 \
		-serial mon:stdio \
		-device loader,file=$(IMAGE_FILE),addr=0x70000000,cpu-num=0 \
		-m size=2G \
		-nographic \
		-netdev user,id=netdev0,hostfwd=tcp::8080-:8080 \
		-global virtio-mmio.force-legacy=false \
		-d guest_errors \
		$(QEMU_NET_ARGS)

${SDDF}/tools/make/board/common.mk ${SDDF_MAKEFILES} ${ROOT}/dep/sddf/include &:
	cd $(ROOT); git submodule update --init dep/sddf
