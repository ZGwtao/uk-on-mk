# SPDX-License-Identifier: BSD-2-Clause

IMAGES := solo5.elf timer_driver.elf \
	serial_driver.elf serial_virt_rx.elf serial_virt_tx.elf \
	eth_driver.elf network_virt_rx.elf network_virt_tx.elf network_copy.elf \
	blk_driver.elf blk_virt.elf
SUPPORTED_BOARDS := qemu_virt_aarch64
TOOLCHAIN ?= clang
BM_SOLO5_CMDLINE ?=

MICROKIT_TOOL ?= $(MICROKIT_SDK)/bin/microkit
SDDF ?= $(ROOT)/dep/sddf
PYTHON ?= /home/hope/wsp/microkit/pyenv/bin/python
include $(SDDF)/tools/make/board/common.mk

BOARD_DIR := $(MICROKIT_SDK)/board/$(MICROKIT_BOARD)/$(MICROKIT_CONFIG)
SYSTEM_FILE := solo5-on-mk.system
IMAGE_FILE := solo5-on-mk.img
REPORT_FILE := report.txt

CFLAGS += -I$(SDDF)/include -I$(SDDF)/include/microkit
LDFLAGS := -L$(BOARD_DIR)/lib
LIBS := -lmicrokit -Tmicrokit.ld libsddf_util_debug.a

SDDF_CUSTOM_LIBC := 1
include $(SDDF)/util/util.mk
include $(SDDF)/drivers/timer/$(TIMER_DRIV_DIR)/timer_driver.mk
include $(SDDF)/drivers/serial/$(UART_DRIV_DIR)/serial_driver.mk
include $(SDDF)/serial/components/serial_components.mk
ETHERNET_DRIVER := $(SDDF)/drivers/network/$(NET_DRIV_DIR)
include $(SDDF)/network/components/network_components.mk
include $(ETHERNET_DRIVER)/eth_driver.mk
include $(SDDF)/drivers/blk/$(BLK_DRIV_DIR)/blk_driver.mk
include $(SDDF)/blk/components/blk_components.mk

all: $(IMAGE_FILE)

include $(ROOT)/solo5.mk

METAPROGRAM := $(EXAMPLE_DIR)/meta.py

$(IMAGES): libsddf_util_debug.a

$(SYSTEM_FILE): $(METAPROGRAM) $(IMAGES) $(DTB)
	$(PYTHON) -B $(METAPROGRAM) --sddf $(SDDF) --board $(MICROKIT_BOARD) \
		--dtb $(DTB) --output . --sdf $(SYSTEM_FILE) \
		--cmdline "$(BM_SOLO5_CMDLINE)"
	$(OBJCOPY) --update-section .device_resources=serial_driver_device_resources.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_driver_config=serial_driver_config.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_virt_tx_config=serial_virt_tx.data serial_virt_tx.elf
	$(OBJCOPY) --update-section .serial_virt_rx_config=serial_virt_rx.data serial_virt_rx.elf
	$(OBJCOPY) --update-section .serial_client_config=serial_client_solo5.data solo5.elf
	$(OBJCOPY) --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	$(OBJCOPY) --update-section .timer_client_config=timer_client_solo5.data solo5.elf
	$(OBJCOPY) --update-section .device_resources=ethernet_driver_device_resources.data eth_driver.elf
	$(OBJCOPY) --update-section .net_driver_config=net_driver.data eth_driver.elf
	$(OBJCOPY) --update-section .net_virt_rx_config=net_virt_rx.data network_virt_rx.elf
	$(OBJCOPY) --update-section .net_virt_tx_config=net_virt_tx.data network_virt_tx.elf
	$(OBJCOPY) --update-section .net_copy_config=net_copy_net_copier.data network_copy.elf
	$(OBJCOPY) --update-section .net_client_config=net_client_solo5.data solo5.elf
	$(OBJCOPY) --update-section .device_resources=blk_driver_device_resources.data blk_driver.elf
	$(OBJCOPY) --update-section .blk_driver_config=blk_driver.data blk_driver.elf
	$(OBJCOPY) --update-section .blk_virt_config=blk_virt.data blk_virt.elf
	$(OBJCOPY) --update-section .blk_client_config=blk_client_solo5.data solo5.elf
	$(OBJCOPY) --update-section .solo5_cmdline=solo5_cmdline.data solo5.elf

$(IMAGE_FILE) $(REPORT_FILE): $(IMAGES) $(SYSTEM_FILE)
	$(MICROKIT_TOOL) $(SYSTEM_FILE) --search-path $(BUILD_DIR) \
		--board $(MICROKIT_BOARD) --config $(MICROKIT_CONFIG) \
		-o $(IMAGE_FILE) -r $(REPORT_FILE)

.PHONY: qemu system clean

disk:
	$(SDDF)/tools/mkvirtdisk $@ 1 512 16777216 GPT

qemu: $(IMAGE_FILE) disk
	qemu-system-aarch64 -machine virt,virtualization=on -cpu cortex-a53 \
		-m size=2G -nographic \
		-netdev user,id=netdev0 \
		-device virtio-net-device,netdev=netdev0,bus=virtio-mmio-bus.0 \
		-drive file=disk,if=none,format=raw,id=hd \
		-device virtio-blk-device,drive=hd,bus=virtio-mmio-bus.1 \
		-global virtio-mmio.force-legacy=false \
		-device loader,file=$(IMAGE_FILE),addr=0x70000000,cpu-num=0

system: $(SYSTEM_FILE)

clean:: solo5-clean
	$(RM) $(IMAGES) $(SYSTEM_FILE) $(IMAGE_FILE) $(REPORT_FILE) $(DTB)
