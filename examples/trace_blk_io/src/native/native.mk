# SPDX-License-Identifier: BSD-2-Clause

NATIVE_SRC := \
	$(TOP)/src/native/bench.c \
	$(TOP)/include/common/block_io.h \
	$(TOP)/include/native/serial_output.h \
	$(TOP)/include/native/coremark_runner.h

NATIVE_COREMARK_SRC := \
	$(TOP)/src/native/coremark.c \
	$(TOP)/include/common/block_io.h \
	$(TOP)/include/common/result.h \
	$(TOP)/include/native/coremark_runner.h \
	$(TOP)/include/native/serial_output.h

CORO_OPTS := $(TOP)/include/common/libmicrokitco_opts.h

NATIVE_OBJ := client.o
NATIVE_COREMARK_OBJ := native_coremark.o
NATIVE_ELF := client.elf
NATIVE_LIB := libmicrokitco.a

NATIVE_CFLAGS := \
	-DCOROS=$(COROS) \
	-DCOMPUTE_COROS=$(COMPUTE_COROS) \
	-DCOREMARK_ITERS_PER_YIELD=$(COREMARK_ITERS_PER_YIELD) \
	-DBENCH_SECONDS=$(BENCH_SECONDS) \
	-I$(TOP)/include/common \
	-I$(TOP)/include/native \
	-I$(LIBMICROKITCO_PATH) \
	-I$(COREMARK_DIR)

include $(TOP)/coremark.mk

# libmicrokitco.mk builds libco and the Microkit coroutine API into
# libmicrokitco.a. Its options header sets the maximum coroutine count.
LIBMICROKITCO_CFLAGS := \
	-DCOROS=$(COROS) \
	-DCOMPUTE_COROS=$(COMPUTE_COROS) \
	-I$(TOP)/include/common

LIBMICROKITCO_LIBC_INCLUDE := $(SDDF_LIBC_INCLUDE)
include $(LIBMICROKITCO_PATH)/libmicrokitco.mk

$(BUILD_DIR)/libmicrokitco/libmicrokitco.o: $(CORO_OPTS)

$(NATIVE_OBJ): $(NATIVE_SRC) $(CORO_OPTS)
	$(CC) $(CFLAGS) $(NATIVE_CFLAGS) -c $< -o $@

$(NATIVE_COREMARK_OBJ): $(NATIVE_COREMARK_SRC) $(CM_HDRS)
	$(CC) $(CFLAGS) $(NATIVE_CFLAGS) -c $< -o $@

# Link the native client after its application object and coroutine library.
$(NATIVE_ELF): $(NATIVE_OBJ) $(NATIVE_COREMARK_OBJ) coremark.o $(NATIVE_LIB)
	$(LD) $(LDFLAGS) $(NATIVE_OBJ) $(NATIVE_COREMARK_OBJ) coremark.o $(NATIVE_LIB) $(LIBS) -o $@

clean::
	$(RM) $(NATIVE_OBJ) $(NATIVE_COREMARK_OBJ) $(NATIVE_ELF)
