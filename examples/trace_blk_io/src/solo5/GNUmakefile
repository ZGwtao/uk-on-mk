
# This makefile will be copied to the source directory of solo5

include $(TOPDIR)/Makefile.common

test_NAME := solo5_bench
CONFIG_MUEN :=
CFLAGS += -DCOROS=$(COROS) -DREADS_PER_CORO=$(READS_PER_CORO)
include $(TOPDIR)/tests/Makefile.tests

libco.o: libco.c aarch64.c settings.h libco.h
	$(CC) $(CFLAGS) -Wno-cast-qual $(CPPFLAGS) -c $< -o $@

solo5_bench.mkt: solo5_bench.o manifest.o libco.o
	$(CC) -z solo5-abi=mkt $^ -o $@
