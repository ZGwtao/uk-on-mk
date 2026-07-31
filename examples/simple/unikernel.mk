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
	serial_virt_tx.elf

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


%.py: ${UK_DIR}/%.py
	cp $< $@

include $(ROOT)/uk.mk

${IMAGES}: libsddf_util_debug.a

FORCE:

$(SYSTEM_FILE): $(METAPROGRAM) $(IMAGES) $(DTB)
	PYTHONPATH=${SDDF}/tools/meta:$$PYTHONPATH $(PYTHON) -B $(METAPROGRAM) \
	--sddf $(SDDF) --board $(MICROKIT_BOARD) --dtb $(DTB) --objcopy aarch64-none-elf-objcopy \
	--output . --sdf $(SYSTEM_FILE)
	aarch64-none-elf-objcopy --update-section .device_resources=serial_driver_device_resources.data serial_driver.elf
	aarch64-none-elf-objcopy --update-section .serial_driver_config=serial_driver_config.data serial_driver.elf
	aarch64-none-elf-objcopy --update-section .serial_virt_tx_config=serial_virt_tx.data serial_virt_tx.elf
	aarch64-none-elf-objcopy --update-section .serial_virt_rx_config=serial_virt_rx.data serial_virt_rx.elf
	aarch64-none-elf-objcopy --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	aarch64-none-elf-objcopy --update-section .serial_client_config=serial_client_unikraft.data unikraft.elf
	aarch64-none-elf-objcopy --update-section .timer_client_config=timer_client_unikraft.data unikraft.elf

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
		-global virtio-mmio.force-legacy=false \
		-d guest_errors

${SDDF}/tools/make/board/common.mk ${SDDF_MAKEFILES} ${ROOT}/dep/sddf/include &:
	cd $(ROOT); git submodule update --init dep/sddf
