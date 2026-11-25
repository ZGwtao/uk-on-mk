# SPDX-License-Identifier: BSD-2-Clause
#
# Unikraft RAMFS service build rules. This service implements the LionsOS
# filesystem protocol but is otherwise independent of the LionsOS build tree.

UK_ON_MK_DIR ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
UK_RAMFS_DIR := $(UK_ON_MK_DIR)/services/ramfs

RAMFS_SRC := $(UK_RAMFS_DIR)/ramfs-server.c
RAMFS_DEP := \
	$(UK_RAMFS_DIR)/Makefile.uk \
	$(UK_ON_MK_DIR)/uk.mk

ifeq ($(BM_UK_SERVICE),ramfs)
ifndef LIONSOS
$(error LIONSOS must name the LionsOS source tree for the RAMFS protocol headers)
endif

# Service-specific build identity. The generic service lifecycle is defined
# by services.mk; these values are consumed only for a RAMFS invocation.
UK_SERVICE_DIR := $(UK_RAMFS_DIR)
UK_SERVICE_CONFIG := $(UK_RAMFS_DIR)/config/$(BM_UK_ARCH)/ramfs-server.config
UK_SERVICE_LIBS :=
UK_SERVICE_PAYLOAD_NAME := ramfs_default-$(BM_APP_ARCH)
UK_SERVICE_OUTPUT_NAME := ramfs-server
UK_SERVICE_MAKE_ARGS := LIONSOS=$(LIONSOS)
endif

ramfs_server.elf: libsddf_util.a $(RAMFS_SRC) $(RAMFS_DEP)
	$(call uk_build_service,ramfs,LIONSOS=$(LIONSOS))
	cp $(BUILD_DIR)/uk/ramfs/ramfs-server.elf $@
