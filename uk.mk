BM_UNIKRAFT_DIR := $(ROOT)/dep/unikraft
BM_CATALOG_CORE_DIR := $(ROOT)/dep/catalog-core

UK_CONFIG_DIR := $(ROOT)/config

BM_UK_APPLICATION ?= sqlite
# BM_UK_APPLICATION ?= nginx
# BM_UK_APPLICATION ?= c-fs
BM_UK_PAYLOAD_ELF ?= $(BM_UK_APPLICATION)_default-arm64

# BM_UK_CONFIG ?= uk-carrels-arm.config
BM_UK_CONFIG ?= uk-carrels-sqlite-arm.config
BM_UK_CONFIG_SRC := $(UK_CONFIG_DIR)/uk/$(BM_UK_CONFIG)

BM_UK_APP_DIR := $(BM_CATALOG_CORE_DIR)/$(BM_UK_APPLICATION)

BM_UK_MUSL_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/musl
# BM_UK_NGINX_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/nginx
BM_UK_SQLITE_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/sqlite
BM_UK_LWIP_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs/lwip

# Unikraft expects a colon-separated list.
BM_UK_LIBS := \
	$(BM_UK_MUSL_DIR):$(BM_UK_SQLITE_DIR):$(BM_UK_LWIP_DIR)
# BM_UK_LIBS := 

BM_UK_BUILD_DIR := $(BUILD_DIR)/uk
BM_UK_BUILT_ELF := $(BM_UK_BUILD_DIR)/$(BM_UK_PAYLOAD_ELF)
BM_UK_CONFIGURED := $(BM_UK_BUILD_DIR)/.configured

BM_UK_ROOTFS_DIR := $(BM_UK_APP_DIR)/rootfs
BM_UK_INITRD := $(BM_UK_APP_DIR)/initrd.cpio
BM_UK_MKCPIO := $(BM_UNIKRAFT_DIR)/support/scripts/mkcpio

BM_UK_MAKE_ARGS := \
	A=$(BM_UK_APP_DIR) \
	O=$(BM_UK_BUILD_DIR) \
	L=$(BM_UK_LIBS) \
	SDDF=$(SDDF) \
	MICROKIT_SDK=$(MICROKIT_SDK) \
	MICROKIT_BOARD=$(MICROKIT_BOARD) \
	MICROKIT_CONFIG=$(MICROKIT_CONFIG) \
	BOARD_DIR=$(BOARD_DIR) \
	SDDF_UTIL_LIB=$(abspath libsddf_util.a)

.PHONY: uk-build uk-initrd

uk-build: $(BM_UK_CONFIGURED) libsddf_util.a uk-initrd
	$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS) -j$(nproc)
	cp $(BM_UK_BUILT_ELF) $(BM_UK_PAYLOAD_ELF)

uk-initrd:
	rm -f $(BM_UK_INITRD)
	$(BM_UK_MKCPIO) $(BM_UK_INITRD) $(BM_UK_ROOTFS_DIR)

$(BM_UK_CONFIGURED): $(BM_UK_CONFIG_SRC)
	mkdir -p $(BM_UK_BUILD_DIR)
	$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS) distclean
	$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS) UK_DEFCONFIG=$(BM_UK_CONFIG_SRC) defconfig
	touch $@

unikraft.elf: uk-build
	cp $(BM_UK_BUILT_ELF) unikraft.elf

initrd.cpio: uk-initrd
	cp $(BM_UK_INITRD) initrd.cpio