# SPDX-License-Identifier: BSD-2-Clause

NATIVE_SRC := \
	$(TOP)/src/native/bench.c \
	$(TOP)/include/common/block_io.h \
	$(TOP)/include/native/serial_output.h

CORO_OPTS := $(TOP)/include/common/libmicrokitco_opts.h

NATIVE_OBJ := client.o
NATIVE_ELF := client.elf
NATIVE_LIB := libmicrokitco.a

NATIVE_CFLAGS := -DCOROS=$(COROS) -DREADS_PER_CORO=$(READS_PER_CORO) \
	-I$(TOP)/include/common -I$(TOP)/include/native \
	-I$(LIBMICROKITCO_PATH)

# libmicrokitco.mk builds libco and the Microkit coroutine API into
# libmicrokitco.a. Its options header sets the maximum coroutine count.
LIBMICROKITCO_CFLAGS := -I$(TOP)/include/common -DCOROS=$(COROS)
LIBMICROKITCO_LIBC_INCLUDE := $(SDDF_LIBC_INCLUDE)
include $(LIBMICROKITCO_PATH)/libmicrokitco.mk

$(BUILD_DIR)/libmicrokitco/libmicrokitco.o: $(CORO_OPTS)

$(NATIVE_OBJ): $(NATIVE_SRC) $(CORO_OPTS)
	$(CC) $(CFLAGS) $(NATIVE_CFLAGS) -c $< -o $@

# Link the native client after its application object and coroutine library.
$(NATIVE_ELF): $(NATIVE_OBJ) $(NATIVE_LIB)
	$(LD) $(LDFLAGS) $(NATIVE_OBJ) $(NATIVE_LIB) $(LIBS) -o $@

clean::
	$(RM) $(NATIVE_OBJ) $(NATIVE_ELF)
