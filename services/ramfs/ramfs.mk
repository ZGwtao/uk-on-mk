# SPDX-License-Identifier: BSD-2-Clause
#
# Unikraft RAMFS service build rules. This service implements the LionsOS
# filesystem protocol but is otherwise independent of the LionsOS build tree.

UK_ON_MK_DIR ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
UKF_RAMFS_DIR := $(UK_ON_MK_DIR)/services/ramfs

RAMFS_SRC := $(UKF_RAMFS_DIR)/ramfs-server.c
RAMFS_DEP := \
	$(UKF_RAMFS_DIR)/Makefile.uk \
	$(UK_ON_MK_DIR)/uk.mk

ifeq ($(TARGET_SVC),ramfs)
ifndef LIONSOS
$(error LIONSOS must name the LionsOS source tree for the RAMFS protocol headers)
endif

# Service-specific build identity. The generic service lifecycle is defined
# by services.mk; these values are consumed only for a RAMFS invocation.
UKF_SVC_DIR := $(UKF_RAMFS_DIR)
UKF_SVC_CFG_SRC := $(UKF_RAMFS_DIR)/config/$(UKF_ARCH)/ramfs-server.config
UKF_SVC_LIBS :=
UKF_SVC_PAYLOAD_NAME := ramfs_default-$(UKF_ELF_ARCH)
UKF_SVC_OUTPUT_NAME := ramfs-server
UKF_SVC_ARGS := LIONSOS=$(LIONSOS)
endif

ramfs_server.elf: libsddf_util.a $(RAMFS_SRC) $(RAMFS_DEP)
	$(call ukf_build_svc,ramfs,LIONSOS=$(LIONSOS))
	cp $(BUILD_DIR)/uk/ramfs/ramfs-server.elf $@
