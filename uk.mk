BM_UNIKRAFT_DIR := $(ROOT)/dep/unikraft
BM_CATALOG_CORE_DIR := $(ROOT)/dep/catalog-core
BM_UK_MKCPIO := $(BM_UNIKRAFT_DIR)/support/scripts/mkcpio

UK_CONFIG_DIR := $(ROOT)/config/uk
BM_UK_LIBRARY_DIR := $(BM_CATALOG_CORE_DIR)/repos/libs

BM_UK_LIB_DIR_musl := $(BM_UK_LIBRARY_DIR)/musl
BM_UK_LIB_DIR_sqlite := $(BM_UK_LIBRARY_DIR)/sqlite
BM_UK_LIB_DIR_nginx := $(BM_UK_LIBRARY_DIR)/nginx
BM_UK_LIB_DIR_lwip := $(BM_UK_LIBRARY_DIR)/lwip

BM_UK_APPLICATION ?= sqlite
BM_UK_APPLICATIONS := c-hello c-fs c-http sqlite nginx

BM_UK_DEPS_c-http := lwip
BM_UK_DEPS_sqlite := musl sqlite
BM_UK_DEPS_nginx := musl nginx lwip

BM_UK_MAIN_SRC_c-hello := $(ROOT)/apps/c-hello.c
BM_UK_MAIN_DST_c-hello := $(BM_CATALOG_CORE_DIR)/c-hello/hello.c

BM_UK_MAIN_SRC_c-fs := $(ROOT)/apps/c-fs.c
BM_UK_MAIN_DST_c-fs := $(BM_CATALOG_CORE_DIR)/c-fs/cat.c

BM_UK_MAIN_SRC_c-http := $(ROOT)/apps/c-http.c
BM_UK_MAIN_DST_c-http := $(BM_CATALOG_CORE_DIR)/c-http/server.c

BM_UK_MAIN_SRC_sqlite := $(ROOT)/apps/sqlite.c
BM_UK_MAIN_DST_sqlite := $(BM_UK_LIB_DIR_sqlite)/main.c

BM_UK_MAIN_SRC_nginx := $(ROOT)/apps/nginx.c
BM_UK_MAIN_DST_nginx := $(BM_UK_LIB_DIR_nginx)/main.c

BM_UK_INITRD_APPLICATIONS := c-fs sqlite nginx

ifeq ($(filter $(BM_UK_APPLICATION),$(BM_UK_APPLICATIONS)),)
$(error Unsupported BM_UK_APPLICATION '$(BM_UK_APPLICATION)'; choose one of: $(BM_UK_APPLICATIONS))
endif

empty :=
space := $(empty) $(empty)

BM_UK_CONFIG := uk-carrels-$(BM_UK_APPLICATION)-arm.config
BM_UK_DEPS := $(BM_UK_DEPS_$(BM_UK_APPLICATION))
BM_UK_UNKNOWN_DEPS := \
	$(foreach dep,$(BM_UK_DEPS),$(if $(BM_UK_LIB_DIR_$(dep)),,$(dep)))

ifneq ($(strip $(BM_UK_UNKNOWN_DEPS)),)
$(error Unknown dependencies for $(BM_UK_APPLICATION): $(BM_UK_UNKNOWN_DEPS))
endif

BM_UK_LIBS := $(subst $(space),:,$(strip \
	$(foreach dep,$(BM_UK_DEPS),$(BM_UK_LIB_DIR_$(dep)))))
BM_UK_MAIN_SRC := $(BM_UK_MAIN_SRC_$(BM_UK_APPLICATION))
BM_UK_MAIN_DST := $(BM_UK_MAIN_DST_$(BM_UK_APPLICATION))
BM_UK_PAYLOAD_ELF := $(BM_UK_APPLICATION)_default-arm64

BM_UK_APP_DIR := $(BM_CATALOG_CORE_DIR)/$(BM_UK_APPLICATION)
BM_UK_BUILD_DIR := $(BUILD_DIR)/uk/$(BM_UK_APPLICATION)
BM_UK_BUILT_ELF := $(BM_UK_BUILD_DIR)/$(BM_UK_PAYLOAD_ELF)
BM_UK_CONFIG_SRC := $(UK_CONFIG_DIR)/$(BM_UK_CONFIG)
BM_UK_CONFIGURED := $(BM_UK_BUILD_DIR)/.configured
BM_UK_DEFCONFIG := $(BM_UK_BUILD_DIR)/defconfig

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

.PHONY: uk-build uk-catalog-setup uk-initrd uk-prepare-main

# Keep Carrels' recursive Make variables out of Unikraft's build directory.
# So, "env -u variables"...
uk-build: $(BM_UK_CONFIGURED) libsddf_util.a $(BM_UK_INITRD_PREREQUISITE) uk-prepare-main
	env -u BUILD_DIR -u MAKEFLAGS -u MAKEOVERRIDES \
		$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS)

uk-catalog-setup:
	mkdir -p $(BM_CATALOG_CORE_DIR)/repos/libs
	mkdir -p $(BM_CATALOG_CORE_DIR)/repos/apps
	cd $(BM_CATALOG_CORE_DIR) && ./setup.sh
	cd $(BM_UK_APP_DIR) && ./setup.sh

uk-prepare-main: $(BM_UK_MAIN_SRC) | uk-catalog-setup
	cp $< $(BM_UK_MAIN_DST)

ifneq ($(filter $(BM_UK_APPLICATION),$(BM_UK_INITRD_APPLICATIONS)),)
uk-initrd:
	mkdir -p $(dir $(BM_UK_INITRD))
	rm -f $(BM_UK_INITRD)
	$(BM_UK_MKCPIO) $(BM_UK_INITRD) $(BM_UK_ROOTFS_DIR)
else
uk-initrd:
	@:
endif

# Keep Carrels' recursive Make variables out of Unikraft's build directory.
# So, "env -u variables"...
$(BM_UK_CONFIGURED): $(BM_UK_CONFIG_SRC) $(ROOT)/uk.mk | uk-catalog-setup
	mkdir -p $(BM_UK_BUILD_DIR)
	cp $(BM_UK_CONFIG_SRC) $(BM_UK_DEFCONFIG)
	printf 'CONFIG_LIBVFSCORE_AUTOMOUNT_EINITRD_PATH="%s"\n' \
		'$(BM_UK_INITRD)' >> $(BM_UK_DEFCONFIG)
	env -u BUILD_DIR -u MAKEFLAGS -u MAKEOVERRIDES \
		$(MAKE) -C $(BM_UNIKRAFT_DIR) $(BM_UK_MAKE_ARGS) \
		UK_DEFCONFIG=$(BM_UK_DEFCONFIG) defconfig
	touch $@

unikraft.elf: uk-build
	cp $(BM_UK_BUILT_ELF) $@

initrd.cpio: uk-initrd
ifneq ($(filter $(BM_UK_APPLICATION),$(BM_UK_INITRD_APPLICATIONS)),)
	cp $(BM_UK_INITRD) $@
endif
