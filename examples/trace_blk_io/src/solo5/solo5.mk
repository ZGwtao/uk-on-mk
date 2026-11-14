# SPDX-License-Identifier: BSD-2-Clause

APP := solo5_bench
export COROS READS_PER_CORO LIBMICROKITCO_PATH
include $(ROOT)/solo5.mk

TAR_DIR := $(STAGE_DIR)/tests/$(APP)
SRC_MK  := $(TOP)/src/solo5/GNUmakefile
TAR_MK  := $(TAR_DIR)/GNUmakefile
APP_SRC := \
	$(TOP)/src/solo5/bench.c \
	$(TOP)/src/solo5/manifest.json \
	$(TOP)/include/common/block_io.h \
	$(TOP)/include/solo5/console.h

LIBCO_FILES := $(addprefix $(LIBMICROKITCO_PATH)/libco/,libco.c libco.h aarch64.c settings.h)

.PHONY: stage-app stage-libco


stage-app: solo5-core $(APP_SRC)
	mkdir -p $(TAR_DIR)
	cp $(APP_SRC) $(TAR_DIR)/
	mv $(TAR_DIR)/bench.c $(TAR_DIR)/solo5_bench.c

stage-libco: stage-app $(LIBCO_FILES)
	cp $(LIBCO_FILES) $(TAR_DIR)/
# libco stores AArch64 context-switch instructions in a const uint32_t
# array and calls it through a function pointer. Clang places its custom
# section in non-executable data; .text makes those instruction words
# executable in the Solo5 ELF. Patch only the staged settings.h copy.
	sed -i 's@#define section(name).*@#define section(name) __attribute__((section(".text")))@' $(TAR_DIR)/settings.h

$(TAR_MK): stage-libco $(SRC_MK)
	cp $(SRC_MK) $@

# $(ROOT)/solo5.mk defines solo5-app: it builds the application in the staged
# tests/$(APP) directory and copies the result to solo5.elf. Depend on TAR_MK
# so the application's sources and GNUmakefile are in place before that build.
solo5-app: $(TAR_MK)


client.elf: solo5.elf
	cp solo5.elf $@

clean::
	$(RM) client.elf
