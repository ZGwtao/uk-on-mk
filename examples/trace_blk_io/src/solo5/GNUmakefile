
# This makefile will be copied to the source directory of solo5

include $(TOPDIR)/Makefile.common

test_NAME := solo5_bench
CONFIG_MUEN :=
CFLAGS += \
	-DCOROS=$(COROS) \
	-DCOMPUTE_COROS=$(COMPUTE_COROS) \
	-DCOREMARK_ITERS_PER_YIELD=$(COREMARK_ITERS_PER_YIELD) \
	-DBENCH_SECONDS=$(BENCH_SECONDS) \
	-I$(COREMARK_DIR)

include $(TOPDIR)/tests/Makefile.tests

libco.o: libco.c aarch64.c settings.h libco.h
	$(CC) $(CFLAGS) -Wno-cast-qual $(CPPFLAGS) -c $< -o $@

solo5_bench.mkt: solo5_bench.o solo5_coremark.o manifest.o libco.o coremark.o
	$(CC) -z solo5-abi=mkt $^ -o $@
