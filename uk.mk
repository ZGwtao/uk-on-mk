BM_UNIKRAFT_DIR := $(ROOT)/dep/unikraft
BM_CATALOG_CORE_DIR := $(ROOT)/dep/catalog-core
BM_UK_MKCPIO := $(BM_UNIKRAFT_DIR)/support/scripts/mkcpio

UK_CONFIG_DIR := $(ROOT)/config/uk

BM_UK_MUSL_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/musl
BM_UK_SQLITE_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/sqlite
BM_UK_NGINX_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/nginx
BM_UK_LWIP_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/lwip

BM_UK_APPLICATION ?= sqlite
BM_UK_APPLICATIONS := c-hello sqlite nginx

BM_UK_CONFIG_c-hello := uk-carrels-c-hello-arm.config
BM_UK_LIBS_c-hello :=

BM_UK_CONFIG_sqlite := uk-carrels-sqlite-arm.config
BM_UK_LIBS_sqlite := $(BM_UK_MUSL_DIR):$(BM_UK_SQLITE_DIR)

BM_UK_CONFIG_nginx := uk-carrels-nginx-arm.config
BM_UK_LIBS_nginx := \
	$(BM_UK_MUSL_DIR):$(BM_UK_NGINX_DIR):$(BM_UK_LWIP_DIR)

BM_UK_MAIN_SRC_sqlite := $(ROOT)/apps/main_sqlite.c
BM_UK_MAIN_DST_sqlite := $(BM_UK_SQLITE_DIR)/main.c

BM_UK_MAIN_SRC_nginx := $(ROOT)/apps/main_nginx.c
BM_UK_MAIN_DST_nginx := $(BM_UK_NGINX_DIR)/main.c

BM_UK_INITRD_APPLICATIONS := sqlite nginx

ifeq ($(filter $(BM_UK_APPLICATION),$(BM_UK_APPLICATIONS)),)
$(error Unsupported BM_UK_APPLICATION '$(BM_UK_APPLICATION)'; choose one of: $(BM_UK_APPLICATIONS))
endif

BM_UK_CONFIG := $(BM_UK_CONFIG_$(BM_UK_APPLICATION))
BM_UK_LIBS := $(BM_UK_LIBS_$(BM_UK_APPLICATION))
BM_UK_MAIN_SRC := $(BM_UK_MAIN_SRC_$(BM_UK_APPLICATION))
BM_UK_MAIN_DST := $(BM_UK_MAIN_DST_$(BM_UK_APPLICATION))
BM_UK_PAYLOAD_ELF := $(BM_UK_APPLICATION)_default-arm64

BM_UK_APP_DIR := $(BM_CATALOG_CORE_DIR)/$(BM_UK_APPLICATION)
BM_UK_BUILD_DIR := $(BUILD_DIR)/uk/$(BM_UK_APPLICATION)
BM_UK_BUILT_ELF := $(BM_UK_BUILD_DIR)/$(BM_UK_PAYLOAD_ELF)
BM_UK_CONFIG_SRC := $(UK_CONFIG_DIR)/$(BM_UK_CONFIG)
BM_UK_CONFIGURED := $(BM_UK_BUILD_DIR)/.configured

BM_UK_ROOTFS_DIR := $(BM_UK_APP_DIR)/rootfs
BM_UK_INITRD := $(BM_UK_BUILD_DIR)/initrd.cpio

BM_UK_MAKE_ARGS := \
	A=$(BM_UK_APP_DIR) \
	O=$(BM_UK_BUILD_DIR) \
	C=$(BM_UK_BUILD_DIR)/.config \
	L=$(BM_UK_LIBS) \
	SDDF=$(SDDF) \
	MICROKIT_SDK=$(MICROKIT_SDK) \
	MICROKIT_BOARD=$(MICROKIT_BOARD) \
	MICROKIT_CONFIG=$(MICROKIT_CONFIG) \
	BOARD_DIR=$(BOARD_DIR) \
	SDDF_UTIL_LIB=$(abspath libsddf_util.a)

ifneq ($(filter $(BM_UK_APPLICATION),$(BM_UK_INITRD_APPLICATIONS)),)
BM_UK_INITRD_PREREQUISITE := uk-initrd
BM_UK_MAKE_ARGS += \
	CONFIG_LIBVFSCORE_AUTOMOUNT_EINITRD_PATH=$(BM_UK_INITRD)
endif

.PHONY: uk-build uk-initrd uk-prepare-main

uk-build: $(BM_UK_CONFIGURED) libsddf_util.a $(BM_UK_INITRD_PREREQUISITE) uk-prepare-main
	$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS)

ifneq ($(BM_UK_MAIN_SRC),)
uk-prepare-main: $(BM_UK_MAIN_SRC)
	cp $< $(BM_UK_MAIN_DST)
else
uk-prepare-main:
	@:
endif

ifneq ($(filter $(BM_UK_APPLICATION),$(BM_UK_INITRD_APPLICATIONS)),)
uk-initrd:
	rm -f $(BM_UK_INITRD)
	$(BM_UK_MKCPIO) $(BM_UK_INITRD) $(BM_UK_ROOTFS_DIR)
else
uk-initrd:
	@:
endif

$(BM_UK_CONFIGURED): $(BM_UK_CONFIG_SRC) $(ROOT)/uk.mk
	mkdir -p $(BM_UK_BUILD_DIR)
	$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS) \
		UK_DEFCONFIG=$(BM_UK_CONFIG_SRC) defconfig
	touch $@

unikraft.elf: uk-build
	cp $(BM_UK_BUILT_ELF) $@

initrd.cpio: uk-initrd
ifneq ($(filter $(BM_UK_APPLICATION),$(BM_UK_INITRD_APPLICATIONS)),)
	cp $(BM_UK_INITRD) $@
endif
