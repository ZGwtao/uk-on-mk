

UK_SRC_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
UK_CONFIG_DIR := $(UK_SRC_DIR)/config

BM_UNIKRAFT_DIR := $(ROOT)/dep/unikraft
BM_CATALOG_CORE_DIR := $(ROOT)/dep/catalog-core

BM_UK_APPLICATION ?= c-fs
BM_UK_PAYLOAD_ELF ?= $(BM_UK_APPLICATION)_default-arm64

BM_UK_CONFIG ?= uk-carrels-arm.config
BM_UK_CONFIG_SRC := $(UK_CONFIG_DIR)/uk/$(BM_UK_CONFIG)

BM_UK_APP_DIR := $(BM_CATALOG_CORE_DIR)/$(BM_UK_APPLICATION)
BM_UK_BUILD_DIR := $(BUILD_DIR)/uk
BM_UK_BUILT_ELF := $(BM_UK_BUILD_DIR)/$(BM_UK_PAYLOAD_ELF)
BM_UK_CONFIGURED := $(BM_UK_BUILD_DIR)/.configured

BM_UK_MAKE_ARGS := \
	UK_ROOT=$(BM_UNIKRAFT_DIR) \
	UK_APP=$(BM_UK_APP_DIR) \
	UK_BUILD=$(BM_UK_BUILD_DIR) \
	SDDF=$(SDDF) \
	MICROKIT_SDK=$(MICROKIT_SDK) \
	MICROKIT_BOARD=$(MICROKIT_BOARD) \
	MICROKIT_CONFIG=$(MICROKIT_CONFIG) \
	BOARD_DIR=$(BOARD_DIR) \
	SDDF_UTIL_LIB=$(abspath libsddf_util.a)

.PHONY: uk-build
uk-build: $(BM_UK_CONFIGURED) libsddf_util.a
	$(MAKE) -C $(BM_UK_APP_DIR) \
		$(BM_UK_MAKE_ARGS) \
		-j$$(nproc)
	cp $(BM_UK_BUILT_ELF) $(BM_UK_PAYLOAD_ELF)


$(BM_UK_CONFIGURED): $(BM_UK_CONFIG_SRC)
	$(MAKE) -C $(BM_UK_APP_DIR) \
		$(BM_UK_MAKE_ARGS) \
		distclean
	$(MAKE) -C $(BM_UK_APP_DIR) \
		$(BM_UK_MAKE_ARGS) \
		UK_DEFCONFIG=$(BM_UK_CONFIG_SRC) \
		defconfig
	mkdir -p $(BM_UK_BUILD_DIR)
	touch $@

unikraft.elf: uk-build
	cp uk/$(BM_UK_PAYLOAD_ELF) unikraft.elf


-include $(PC_OBJS:.o=.d)