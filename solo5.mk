BM_SOLO5_SOURCE_DIR := $(ROOT)/dep/solo5
STAGE_DIR := $(BUILD_DIR)/solo5

# Set this to an absolute path to package an already-linked Solo5 application
# instead of one of the in-tree Solo5 tests.
BM_SOLO5_APP_ELF ?=

BM_SOLO5_TARGET_CC ?= $(CC) -target $(TARGET)
BM_SOLO5_TARGET_LD ?= $(LD)
BM_SOLO5_TARGET_OBJCOPY ?= $(OBJCOPY)

BM_SOLO5_MKT_CPPFLAGS := \
	-I$(BOARD_DIR)/include \
	-isystem $(SDDF)/include \
	-isystem $(SDDF)/include/microkit \
	-isystem $(SDDF)/include/sddf/util/custom_libc

.PHONY: \
	solo5-app \
	solo5-clean \
	solo5-config \
	solo5-core \
	solo5-src 

# Solo5 does not support out-of-tree builds. Stage a copy of its source tree
# in the build directory so generated files and build artifacts do not modify
# the dependency source tree.
solo5-src:
	mkdir -p $(STAGE_DIR)
	rsync -a --delete --exclude=.git --filter=':- .gitignore' \
		$(BM_SOLO5_SOURCE_DIR)/ $(STAGE_DIR)/
solo5-clean:
	rm -r $(STAGE_DIR)


solo5-config: export TARGET_CC := $(BM_SOLO5_TARGET_CC)
solo5-config: export TARGET_LD := $(BM_SOLO5_TARGET_LD)
solo5-config: export TARGET_OBJCOPY := $(BM_SOLO5_TARGET_OBJCOPY)
solo5-config: solo5-src
	cd $(STAGE_DIR) && ./configure.sh --disable-tenders

solo5-core solo5-app: export TOPDIR := $(STAGE_DIR)
solo5-core: solo5-config
# Generate version.h, which is required by "bindings" and "elftool"
	@cd $(BM_SOLO5_SOURCE_DIR) && \
		scripts/gen_version_h.sh $(STAGE_DIR)/include/version.h
# Generate wrappers of the Solo5 target for generic compiler/linker/objcopy
# This wrappers help generic toolchain builds codes for Solo5 without
# having to explicitly specify information needed by the Solo5 codes
	@make -C $(STAGE_DIR)/toolchain
# Build elftool, which helps generate ELF information like Solo5 manifest,
# which contains information about what devices the unikernel needs
	@make -C $(STAGE_DIR)/elftool solo5-elftool
# Build bindings, which is the core for building Solo5 images
# MKT_CPPFLAGS contains information like where to include microkit headers...
	@make -C $(STAGE_DIR)/bindings \
		MKT_CPPFLAGS="$(BM_SOLO5_MKT_CPPFLAGS)" solo5_stub.o solo5_mkt.o


# Other available built-in Solo5 apps
# @test_net, @test_blk, @test_time, @test_tls, etc.
# Checkout at $(SOLO5)/tests/
APP ?= test_hello
APP_OUT := $(APP).mkt

APP_DIR := $(STAGE_DIR)/tests/$(APP)

solo5-app: solo5-core
	@make -C $(APP_DIR) -B $(APP_OUT)
	cp $(APP_DIR)/$(APP_OUT) solo5.elf

ifeq ($(strip $(BM_SOLO5_APP_ELF)),)
solo5.elf: solo5-app
else
solo5.elf: $(BM_SOLO5_APP_ELF)
	cp $< $@
endif
