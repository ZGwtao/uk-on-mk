#pragma once

#include <stdbool.h>
#include <stdint.h>

// Number of I/O coroutines
#ifndef COROS
#define COROS 8
#endif

// Number of Computation coroutines
// (We use sing-thread computation)
#ifndef COMPUTE_COROS
#define COMPUTE_COROS 1
#endif

// Each time CoreMark coroutine (compute coro) decides to yield,
// it must have been finished an iteration of a set of calculation
#ifndef COREMARK_ITERS_PER_YIELD
#define COREMARK_ITERS_PER_YIELD 1
#endif

// How long will the benchmark last
#ifndef BENCH_SECONDS
#define BENCH_SECONDS 10
#endif

#if COROS < 1 || COMPUTE_COROS < 1 || COREMARK_ITERS_PER_YIELD < 1 || BENCH_SECONDS < 1
#error Coroutine counts and batch size must be positive
#endif

#define BLOCK_SIZE 4096u
#define BLOCKS_PER_CORO 128u

/* State shared by the two modes for one timed block-read run. */
typedef struct {
    uint64_t completed;
    uint64_t start_ns;
    bool active;
} read_run_state_t;

static inline void read_run_start(read_run_state_t *run, uint64_t now_ns)
{
    *run = (read_run_state_t) { .start_ns = now_ns, .active = true };
}

/* Stop new reads and return a stable copy for reporting. A native response
 * arriving later still wakes its coroutine but does not change this count.
 */
static inline read_run_state_t read_run_stop(read_run_state_t *run)
{
    run->active = false;
    return *run;
}

static inline bool read_run_is_active(const read_run_state_t *run)
{
    return run->active;
}

static inline void read_run_complete(read_run_state_t *run)
{
    if (run->active)
        run->completed++;
}

static inline uint64_t read_run_completed(const read_run_state_t *run)
{
    return run->completed;
}

static inline uint64_t read_run_elapsed_ns(const read_run_state_t *run,
                                           uint64_t now_ns)
{
    return now_ns - run->start_ns;
}

/* bench.c owns I/O coroutines and counters. The CoreMark port starts the
 * timed run and reads a snapshot after stopping it for the final report.
 */
void bench_io_start(uint64_t now_ns);
read_run_state_t bench_io_stop(void);
