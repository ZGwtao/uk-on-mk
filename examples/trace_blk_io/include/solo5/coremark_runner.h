#pragma once

#include <stddef.h>
#include "libco.h"

void coremark_runner_init(cothread_t scheduler,
                          void *compute_stacks, size_t stack_size);
void coremark_runner_resume_controller(void);
void coremark_runner_resume_workers(void);
int coremark_runner_done(void);
