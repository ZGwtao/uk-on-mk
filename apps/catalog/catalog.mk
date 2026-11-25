# SPDX-License-Identifier: BSD-2-Clause

# catalog-core application integration.
UK_CATALOG_APP_DIR := $(UK_ON_MK_DIR)/apps/catalog
BM_CATALOG_CORE_DIR := $(UK_ON_MK_DIR)/dep/catalog-core
UK_CATALOG_CONFIG_DIR := $(UK_CATALOG_APP_DIR)/config
BM_UK_LIBRARY_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs
BM_UK_LIB_DIR_musl := $(BM_UK_LIBRARY_DIR)/musl
BM_UK_LIB_DIR_sqlite := $(BM_UK_LIBRARY_DIR)/sqlite
BM_UK_LIB_DIR_nginx := $(BM_UK_LIBRARY_DIR)/nginx
BM_UK_LIB_DIR_lwip := $(BM_UK_LIBRARY_DIR)/lwip

BM_UK_APPLICATION ?= sqlite
BM_UK_APPLICATIONS := c-hello c-fs c-http c-nginx-client sqlite nginx
BM_UK_DEPS_c-http := lwip
BM_UK_DEPS_c-nginx-client := lwip
BM_UK_DEPS_sqlite := musl sqlite
BM_UK_DEPS_nginx := musl nginx lwip
BM_UK_MAIN_SRC_c-hello := $(UK_CATALOG_APP_DIR)/c-hello.c
BM_UK_MAIN_VAR_c-hello := APPCHELLO_MAIN
BM_UK_MAIN_SRC_c-fs := $(UK_CATALOG_APP_DIR)/c-fs.c
BM_UK_MAIN_VAR_c-fs := APPCFS_MAIN
BM_UK_MAIN_SRC_c-http := $(UK_CATALOG_APP_DIR)/c-http.c
BM_UK_MAIN_VAR_c-http := APPCHTTP_MAIN
BM_UK_MAIN_SRC_c-nginx-client := $(UK_CATALOG_APP_DIR)/nginx-client.c
BM_UK_MAIN_VAR_c-nginx-client := APPCNGINXCLIENT_MAIN
BM_UK_MAIN_SRC_sqlite := $(UK_CATALOG_APP_DIR)/sqlite.c
BM_UK_MAIN_VAR_sqlite := LIBSQLITE_MAIN
BM_UK_MAIN_SRC_nginx := $(UK_CATALOG_APP_DIR)/nginx.c
BM_UK_MAIN_VAR_nginx := LIBNGINX_MAIN
BM_UK_INITRD_APPLICATIONS := c-fs sqlite nginx

BM_UK_SERVICE ?=
ifeq ($(strip $(BM_UK_SERVICE)),)
ifeq ($(filter $(BM_UK_APPLICATION),$(BM_UK_APPLICATIONS)),)
$(error Unsupported BM_UK_APPLICATION '$(BM_UK_APPLICATION)'; choose one of: $(BM_UK_APPLICATIONS))
endif
endif

empty :=
space := $(empty) $(empty)
BM_UK_CONFIG_SRC := $(UK_CATALOG_CONFIG_DIR)/$(BM_UK_ARCH)/uk-carrels-$(BM_UK_APPLICATION).config
BM_UK_DEPS := $(BM_UK_DEPS_$(BM_UK_APPLICATION))
BM_UK_UNKNOWN_DEPS := $(foreach dep,$(BM_UK_DEPS),$(if $(BM_UK_LIB_DIR_$(dep)),,$(dep)))
ifneq ($(strip $(BM_UK_UNKNOWN_DEPS)),)
$(error Unknown dependencies for $(BM_UK_APPLICATION): $(BM_UK_UNKNOWN_DEPS))
endif
BM_UK_LIBS := $(subst $(space),:,$(strip $(foreach dep,$(BM_UK_DEPS),$(BM_UK_LIB_DIR_$(dep)))))
BM_UK_MAIN_SRC := $(BM_UK_MAIN_SRC_$(BM_UK_APPLICATION))
BM_UK_MAIN_VAR := $(BM_UK_MAIN_VAR_$(BM_UK_APPLICATION))
BM_UK_MAIN_MAKE_ARG := $(BM_UK_MAIN_VAR)=$(BM_UK_MAIN_SRC)
BM_UK_APP_DIR := $(BM_CATALOG_CORE_DIR)/$(BM_UK_APPLICATION)
BM_UK_BUILD_DIR := $(BUILD_DIR)/uk/$(BM_UK_APPLICATION)
BM_UK_INITRD := $(BM_UK_BUILD_DIR)/initrd.cpio
BM_UK_CONFIGURED := $(BM_UK_BUILD_DIR)/.configured
BM_UK_ROOTFS_DIR ?= $(BM_UK_APP_DIR)/rootfs
BM_UK_PAYLOAD_ELF := $(BM_UK_APPLICATION)_default-$(BM_APP_ARCH)
BM_UK_BUILT_ELF := $(BM_UK_BUILD_DIR)/$(BM_UK_PAYLOAD_ELF)
BM_UK_OUTPUT_ELF := $(BM_UK_BUILD_DIR)/$(BM_UK_APPLICATION).elf

ifneq ($(filter $(BM_UK_APPLICATION),$(BM_UK_INITRD_APPLICATIONS)),)
BM_UK_INITRD_PREREQUISITE := uk-catalog-initrd
endif

.PHONY: uk-catalog-build uk-catalog-setup uk-catalog-initrd
uk-catalog-build: $(BM_UK_CONFIGURED) libsddf_util.a $(BM_UK_INITRD_PREREQUISITE) $(BM_UK_MAIN_SRC)
	$(call uk_unikraft_make,$(BM_UK_APP_DIR),$(BM_UK_BUILD_DIR),$(BM_UK_LIBS),CONFIG_LIBVFSCORE_AUTOMOUNT_EINITRD_PATH=$(BM_UK_INITRD) $(BM_UK_MAIN_MAKE_ARG))
	cp $(BM_UK_BUILT_ELF) $(BM_UK_OUTPUT_ELF)

uk-catalog-setup:
	mkdir -p $(BM_CATALOG_CORE_DIR)/repos/libs $(BM_CATALOG_CORE_DIR)/repos/apps
	cd $(BM_CATALOG_CORE_DIR) && ./setup.sh
	cd $(BM_UK_APP_DIR) && ./setup.sh

uk-catalog-initrd:
	mkdir -p $(dir $(BM_UK_INITRD))
	rm -f $(BM_UK_INITRD)
	$(BM_UK_MKCPIO) $(BM_UK_INITRD) $(BM_UK_ROOTFS_DIR)

$(BM_UK_CONFIGURED): $(BM_UK_CONFIG_SRC) $(UK_CATALOG_APP_DIR)/catalog.mk $(UK_ON_MK_DIR)/uk.mk | uk-catalog-setup
	$(call uk_unikraft_configure,$(BM_UK_CONFIG_SRC),$(BM_UK_APP_DIR),$(BM_UK_BUILD_DIR),$(BM_UK_LIBS),$(BM_UK_INITRD),$@,$(BM_UK_MAIN_MAKE_ARG))

# Compatibility aliases for existing uk-on-mk consumers.
.PHONY: uk-build uk-initrd
uk-build: uk-catalog-build
uk-initrd: uk-catalog-initrd
unikraft.elf: uk-catalog-build
	cp $(BM_UK_BUILT_ELF) $@
