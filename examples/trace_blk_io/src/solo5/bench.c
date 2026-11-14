#include "solo5.h"
#include "libco.h"
#include "block_io.h"
#include "console.h"

#define CO_STACK_SIZE 8192u

static uint8_t stacks[COROS][CO_STACK_SIZE] __attribute__((aligned(16)));

static cothread_t coros[COROS];
static cothread_t scheduler;

static solo5_handle_t blk_dev;

static int running_coro;

static void coro_entry(void)
{
    int coro = running_coro;
    uint8_t block_data[BLOCK_SIZE];

    for (int op = 0; op < READS_PER_CORO; op++) {
        uint64_t block = (uint64_t)coro * BLOCKS_PER_CORO +
                         (op % BLOCKS_PER_CORO);
        if (solo5_block_read(blk_dev, block * BLOCK_SIZE, block_data,
                             BLOCK_SIZE) != SOLO5_R_OK)
            solo5_abort();

        co_switch(scheduler);

        // TODO, add computation logic here.
    }
    for (;;) co_switch(scheduler);
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

    /* Each round resumes every coroutine once. Each resumed coroutine
     * completes one block read before yielding to the scheduler.
     * In total, each coroutine will get scheduled for 'READS_PER_CORO' times.
     */
    for (int op = 0; op < READS_PER_CORO; op++) {
        for (int coro = 0; coro < COROS; coro++) {
            running_coro = coro;
            co_switch(coros[coro]);
        }
    }

    blk_console_write("READS_DONE mode=solo5\n");
    for (;;) {}
}
