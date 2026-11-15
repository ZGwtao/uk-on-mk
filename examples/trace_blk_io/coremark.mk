# SPDX-License-Identifier: BSD-2-Clause

# Build the shared CoreMark sources once. Each mode links this relocatable
# object with its own coroutine runner and block I/O client.
CM_OBJ_DIR := coremark-obj
CM_HDRS := 	$(COREMARK_DIR)/coremark.h $(COREMARK_DIR)/core_portme.h \
			$(COREMARK_DIR)/trace_platform.h
CM_CFLAGS := \
	-DCOMPUTE_COROS=$(COMPUTE_COROS) \
	-DCOREMARK_ITERS_PER_YIELD=$(COREMARK_ITERS_PER_YIELD) \
	-DBENCH_SECONDS=$(BENCH_SECONDS) \
	-I$(COREMARK_DIR)

CM_ROOT_OBJS := \
	$(CM_OBJ_DIR)/core_list_join.o \
	$(CM_OBJ_DIR)/core_main.o \
	$(CM_OBJ_DIR)/core_matrix.o \
	$(CM_OBJ_DIR)/core_state.o \
	$(CM_OBJ_DIR)/core_util.o \
	$(CM_OBJ_DIR)/core_portme.o

CM_BB_OBJS := \
	$(CM_OBJ_DIR)/ee_printf.o \
	$(CM_OBJ_DIR)/cvt.o

CM_OBJS := $(CM_ROOT_OBJS) $(CM_BB_OBJS)

$(CM_OBJ_DIR)/core_main.o: CFLAGS += -Dmain=coremark_main


$(CM_ROOT_OBJS): $(CM_OBJ_DIR)/%.o: $(COREMARK_DIR)/%.c $(CM_HDRS)
	mkdir -p $(CM_OBJ_DIR)
	$(CC) $(CFLAGS) $(CM_CFLAGS) -c $< -o $@

# barebones/ supplies CoreMark's libc-free report formatter and the floating-
# point conversion it uses for elapsed time and scores.
$(CM_BB_OBJS): $(CM_OBJ_DIR)/%.o: $(COREMARK_DIR)/barebones/%.c $(CM_HDRS)
	mkdir -p $(CM_OBJ_DIR)
	$(CC) $(CFLAGS) $(CM_CFLAGS) -c $< -o $@

coremark.o: $(CM_OBJS)
	$(LD) -r $^ -o $@

clean::
	$(RM) coremark.o
	$(RM) -r $(CM_OBJ_DIR)
