#pragma once

#ifndef COROS
#define COROS 16
#endif

#ifndef COMPUTE_COROS
#define COMPUTE_COROS 1
#endif

// One extra computation coroutine for CoreMark's Controller
#define LIBMICROKITCO_MAX_COTHREADS (COROS + (COMPUTE_COROS + 1) + 1)
