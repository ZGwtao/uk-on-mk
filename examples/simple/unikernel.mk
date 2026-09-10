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
	network_copy.elf \
	blk_driver.elf \
	blk_virt.elf

SUPPORTED_BOARDS:= \
	qemu_virt_aarch64 \
	x86_64_generic

TOOLCHAIN ?= clang

MICROKIT_TOOL ?= $(MICROKIT_SDK)/bin/microkit
SDDF ?= $(ROOT)/dep/sddf
SYSTEM_FILE := uk-on-mk.system
IMAGE_FILE := uk-on-mk.img
REPORT_FILE := report.txt
QEMU_HOST_PORT ?= 8080
QEMU_GUEST_PORT ?= 80
# Only network services need a host forwarding rule.  Omitting it for
# non-network applications avoids failing QEMU when a host service owns 8080.
QEMU_HOSTFWD :=
ifneq ($(filter c-http nginx,$(BM_UK_APPLICATION)),)
QEMU_HOSTFWD := ,hostfwd=tcp::$(QEMU_HOST_PORT)-:$(QEMU_GUEST_PORT)
endif

all: ${IMAGE_FILE}

include ${SDDF}/tools/make/board/common.mk

ifeq ($(ARCH),aarch64)
OBJCOPY = aarch64-none-elf-objcopy
else ifeq ($(ARCH),x86_64)
OBJCOPY = x86_64-linux-gnu-objcopy
else
$(error Unsupported ARCH)
endif

METAPROGRAM := $(UK_DIR)/meta.py
ETHERNET_DRIVER := $(SDDF)/drivers/network/$(NET_DRIV_DIR)
NETWORK_COMPONENTS := $(SDDF)/network/components

CFLAGS += \
	-DSDDF_VIRTIO_PCI_TRANSPORT_SKIP_BUS_CHECK \
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
include ${SDDF}/drivers/blk/${BLK_DRIV_DIR}/blk_driver.mk
include ${SDDF}/blk/components/blk_components.mk


%.py: ${UK_DIR}/%.py
	cp $< $@

include $(ROOT)/uk.mk

${IMAGES}: libsddf_util_debug.a

FORCE:

$(SYSTEM_FILE): $(METAPROGRAM) $(IMAGES) $(DTB)
ifneq ($(strip $(DTS)),)
	$(PYTHON) -B \
	    $(METAPROGRAM) --sddf $(SDDF) --board $(MICROKIT_BOARD) \
	    --dtb $(DTB) --output . --sdf $(SYSTEM_FILE) --objcopy $(OBJCOPY)
else
	$(PYTHON) -B \
	    $(METAPROGRAM) --sddf $(SDDF) --board $(MICROKIT_BOARD) \
	    --output . --sdf $(SYSTEM_FILE) --objcopy $(OBJCOPY)
endif
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
	$(OBJCOPY) --update-section .serial_client_config=serial_client_unikraft.data unikraft.elf
	$(OBJCOPY) --update-section .timer_client_config=timer_client_unikraft.data unikraft.elf
	$(OBJCOPY) --update-section .net_client_config=net_client_unikraft.data unikraft.elf
	$(OBJCOPY) --update-section .device_resources=blk_driver_device_resources.data blk_driver.elf
	$(OBJCOPY) --update-section .blk_driver_config=blk_driver.data blk_driver.elf
	$(OBJCOPY) --update-section .blk_virt_config=blk_virt.data blk_virt.elf
	$(OBJCOPY) --update-section .blk_client_config=blk_client_unikraft.data unikraft.elf

$(IMAGE_FILE) $(REPORT_FILE): $(IMAGES) $(SYSTEM_FILE)
	$(MICROKIT_TOOL) $(SYSTEM_FILE) \
		--search-path $(BUILD_DIR) --board $(MICROKIT_BOARD) 	\
		--config $(MICROKIT_CONFIG) -o $(IMAGE_FILE) -r $(REPORT_FILE)

qemu: ${IMAGE_FILE}
	$(QEMU) $(QEMU_ARCH_ARGS) $(QEMU_NET_ARGS) $(QEMU_BLK_ARGS) \
		-nographic \
		-netdev user,id=netdev0$(QEMU_HOSTFWD) \
		-drive file=$(BLK_IMAGE),if=none,format=raw,id=hd \
		-global virtio-mmio.force-legacy=false \
		-d guest_errors -smp 4

BLK_IMAGE ?= disk.img
BLK_IMAGE_SIZE ?= 67108864

$(BLK_IMAGE):
	$(SDDF)/tools/mkvirtdisk $@ 1 512 $(BLK_IMAGE_SIZE) GPT

qemu: $(BLK_IMAGE)

${SDDF}/tools/make/board/common.mk ${SDDF_MAKEFILES} ${SDDF}/include &:
	SDDF="$(SDDF)" $(ROOT)/scripts/ensure-sddf.sh
