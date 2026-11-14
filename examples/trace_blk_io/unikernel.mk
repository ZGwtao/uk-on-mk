# SPDX-License-Identifier: BSD-2-Clause

ifneq ($(filter $(MODE),native solo5),$(MODE))
$(error MODE must be native or solo5)
endif
ifneq ($(MICROKIT_CONFIG),debug)
$(error This first version supports MICROKIT_CONFIG=debug only)
endif

TOP := $(ROOT)/examples/trace_blk_io
MICROKIT_TOOL ?= $(MICROKIT_SDK)/bin/microkit

SUPPORTED_BOARDS := \
	qemu_virt_aarch64 \
	maaxboard

TOOLCHAIN ?= clang
SDDF ?= $(ROOT)/dep/sddf
PYTHON ?= $(ROOT)/pyenv/bin/python

SYSTEM_FILE := trace-blk-io.system
IMAGE_FILE := $(MODE).img
REPORT_FILE := report-$(MODE).txt
DISK_IMAGE := $(BUILD_DIR)/disk
include $(SDDF)/tools/make/board/common.mk

CFLAGS += \
	-I$(SDDF)/include \
	-I$(SDDF)/include/microkit

LDFLAGS := -L$(BOARD_DIR)/lib
LIBS := -lmicrokit -Tmicrokit.ld libsddf_util_debug.a

SDDF_CUSTOM_LIBC := 1
include $(SDDF)/util/util.mk
include $(SDDF)/serial/components/serial_components.mk
include $(SDDF)/blk/components/blk_components.mk

all: $(IMAGE_FILE)

# Both modes share a build directory and the client.elf filename. Keep only
# the current mode stamp so switching modes rebuilds client.elf before the
# system configuration and image are regenerated.
.mode-$(MODE):
	$(RM) .mode-native .mode-solo5
	touch $@
client.elf: .mode-$(MODE)

include $(TOP)/src/$(MODE)/$(MODE).mk

IMAGES := client.elf timer_driver.elf serial_driver.elf \
          serial_virt_tx.elf serial_virt_rx.elf blk_driver.elf blk_virt.elf

$(IMAGES): libsddf_util_debug.a

$(SYSTEM_FILE): $(TOP)/meta.py $(IMAGES) $(DTB)
	$(PYTHON) -B $(TOP)/meta.py --sddf $(SDDF) --board $(MICROKIT_BOARD) \
		--dtb $(DTB) --output . --sdf $(SYSTEM_FILE) --mode $(MODE)
	$(OBJCOPY) --update-section .device_resources=serial_driver_device_resources.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_driver_config=serial_driver_serial_driver_config.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_virt_tx_config=serial_virt_tx_serial_virt_tx_config.data serial_virt_tx.elf
	$(OBJCOPY) --update-section .serial_virt_rx_config=serial_virt_rx_serial_virt_rx_config.data serial_virt_rx.elf
	$(OBJCOPY) --update-section .serial_client_config=client_serial_client_config.data client.elf
	$(OBJCOPY) --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	$(OBJCOPY) --update-section .timer_client_config=client_timer_client_config.data client.elf
ifdef BLK_NEED_TIMER
	$(OBJCOPY) --update-section .timer_client_config=blk_driver_timer_client_config.data blk_driver.elf
endif
	$(OBJCOPY) --update-section .device_resources=blk_driver_device_resources.data blk_driver.elf
	$(OBJCOPY) --update-section .blk_driver_config=blk_driver_blk_driver_config.data blk_driver.elf
	$(OBJCOPY) --update-section .blk_virt_config=blk_virt_blk_virt_config.data blk_virt.elf
	$(OBJCOPY) --update-section .blk_client_config=client_blk_client_config.data client.elf

$(IMAGE_FILE): $(IMAGES) $(SYSTEM_FILE)
	$(MICROKIT_TOOL) $(SYSTEM_FILE) --search-path $(BUILD_DIR) \
		--board $(MICROKIT_BOARD) --config $(MICROKIT_CONFIG) \
		-o $(IMAGE_FILE) -r $(REPORT_FILE)

$(DISK_IMAGE):
	$(SDDF)/tools/mkvirtdisk $@ 1 512 16777216 GPT

.PHONY: qemu disk clean
ifeq ($(MICROKIT_BOARD),qemu_virt_aarch64)
qemu: $(IMAGE_FILE) $(DISK_IMAGE)
	$(QEMU) $(QEMU_ARCH_ARGS) $(QEMU_BLK_ARGS) \
		-nographic \
		-drive file=$(DISK_IMAGE),if=none,format=raw,id=hd,readonly=on
else
qemu:
	$(error qemu target requires MICROKIT_BOARD=qemu_virt_aarch64)
endif

disk: $(DISK_IMAGE)
clean::
	$(RM) $(IMAGES) $(SYSTEM_FILE) native.img solo5.img report-*.txt \
		.mode-native .mode-solo5 $(DTB)
