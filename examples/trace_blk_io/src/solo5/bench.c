#include "solo5.h"
#include "libco.h"
#include "block_io.h"
#include "coremark_runner.h"

#define CO_STACK_SIZE 8192u

/* I/O coroutines, CoreMark workers, then the CoreMark controller. */
static uint8_t stacks[COROS + COMPUTE_COROS + 1][CO_STACK_SIZE]
    __attribute__((aligned(16)));

static cothread_t coros[COROS];
static cothread_t scheduler;

static solo5_handle_t blk_dev;

/* co_derive() does not accept an argument. The scheduler sets this before a
 * coroutine's first switch; coro_entry saves the ID on its own stack.
 */
static int running_coro;

static read_run_state_t read_run;

void bench_io_start(uint64_t now_ns)
{
    read_run_start(&read_run, now_ns);
}

read_run_state_t bench_io_stop(void)
{
    return read_run_stop(&read_run);
}

static void coro_entry(void)
{
    int coro = running_coro;
    uint8_t block_data[BLOCK_SIZE];

    for (uint64_t op = 0;; op++) {
        uint64_t block = (uint64_t)coro * BLOCKS_PER_CORO +
                         (op % BLOCKS_PER_CORO);
        if (solo5_block_read(blk_dev, block * BLOCK_SIZE, block_data,
                             BLOCK_SIZE) != SOLO5_R_OK)
            solo5_abort();

        co_switch(scheduler);
    }
}

int solo5_app_main(const struct solo5_start_info *start_info)
{
    (void)start_info;

    struct solo5_block_info blk_info;

    if (solo5_block_acquire("storage", &blk_dev, &blk_info) != SOLO5_R_OK) {
        solo5_abort();
    }
    if (blk_info.block_size != BLOCK_SIZE) {
        solo5_abort();
    }
    if (blk_info.capacity < COROS * BLOCKS_PER_CORO * BLOCK_SIZE) {
        solo5_abort();
    }

    // Initiliase the first coroutine as scheduler.
    scheduler = co_active();

    // Spawn other coroutines which should blocked reading separately.
    for (int coro = 0; coro < COROS; coro++)
        coros[coro] = co_derive(stacks[coro], CO_STACK_SIZE, coro_entry);

    coremark_runner_init(scheduler, stacks[COROS], CO_STACK_SIZE);

    while (!coremark_runner_done()) {
        // Schedule the main func of coremark, which waits for the completion
        // of the computation coroutine. The computation coroutine will use
        // port.done to synchronise state with coremark controller, while the
        // controller will set 'controller_done' to TRUE to make coremark_runner_done
        // return true and break the loop here.
        coremark_runner_resume_controller();

        // Schedule block I/O coros to execute
        for (int coro = 0; coro < COROS && read_run_is_active(&read_run); coro++) {
            running_coro = coro;
            co_switch(coros[coro]);
            read_run_complete(&read_run);
#if SOLO5_INTERLEAVE_COMPUTE
            // Run one computation slice before submitting the next I/O.
            coremark_runner_resume_workers();
#endif
        }
#if SOLO5_INTERLEAVE_COMPUTE
        // CoreMark may still need to finish after the timed I/O run stops.
        if (!read_run_is_active(&read_run))
            coremark_runner_resume_workers();
#else
        // Schedule computation coro to execute
        coremark_runner_resume_workers();
#endif
    }
    for (;;) {}
}
