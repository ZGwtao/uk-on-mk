#include <microkit.h>
#include <libmicrokitco.h>
#include <sddf/blk/config.h>
#include <sddf/blk/queue.h>
#include <sddf/blk/storage_info.h>
#include <sddf/timer/config.h>
#include <sddf/util/util.h>
#include "block_io.h"
#include "serial_output.h"

#define CO_STACK_SIZE 8192u

__attribute__((section(".blk_client_config"), used))
static blk_client_config_t block_config;
__attribute__((section(".timer_client_config"), used))
static timer_client_config_t timer_config;
__attribute__((section(".serial_client_config"), used))
static serial_client_config_t serial_config;

serial_queue_handle_t output_queue;
microkit_channel output_channel;

static blk_queue_handle_t blk_queue;
static microkit_channel blk_channel;

static co_control_t scheduler;
static uint8_t stacks[COROS][CO_STACK_SIZE] __attribute__((aligned(16)));
/*
 * Each coroutine waits on its own semaphore while a block read is pending.
 * The response handler signals that semaphore when the read completes.
 */
static microkit_cothread_sem_t completed[COROS];
static unsigned coro_ids[COROS];

static unsigned reads_done;

// Read one device block into this coro's buffer, then suspend the
// current cothread until its response arrives.
static void coro_blocked_on_blk_read(unsigned coro, uint64_t blk_id, uint64_t blk_cnt)
{
    uintptr_t blk_read_buf_region = coro * BLOCK_SIZE;
    assert(blk_enqueue_req(&blk_queue, BLK_REQ_READ,
                           blk_read_buf_region, blk_id, blk_cnt, coro) == 0);

    microkit_notify(blk_channel);
    microkit_cothread_semaphore_wait(&completed[coro]);

    /* Once finished read, the coroutine will return from here. */
}

static void coro_entry(void)
{
    unsigned coro = *(unsigned *)microkit_cothread_my_arg();
    uint64_t blk_base_global = (uint64_t)coro * BLOCKS_PER_CORO;

    for (int op = 0; op < READS_PER_CORO; op++) {
        uint64_t blk = blk_base_global + (op % BLOCKS_PER_CORO);
        /*
         * Let the coroutine block synchronously on the blk_read until
         * the event dispatcher (notified) release the semaphore when
         * the block data is read from the block device.
         */
        coro_blocked_on_blk_read(coro, blk, 1);
        reads_done++;
    }

    /* When the final read is finished by any coroutine */
    if (reads_done == COROS * READS_PER_CORO)
        output_puts("READS_DONE mode=native\n");
}

void init(void)
{
    output_init(&serial_config);

    assert(blk_config_check_magic(&block_config));

    blk_queue_init(&blk_queue, block_config.virt.req_queue.vaddr,
                   block_config.virt.resp_queue.vaddr,
                   block_config.virt.num_buffers);

    blk_channel = block_config.virt.id;

    blk_storage_info_t *storage = block_config.virt.storage_info.vaddr;

    while (!blk_storage_is_ready(storage)) {
        seL4_Yield();
    }

    assert(storage->capacity >= COROS * BLOCKS_PER_CORO);
    assert(blk_queue.capacity >= COROS);

    stack_ptrs_arg_array_t stack_ptrs;

    for (unsigned coro = 0; coro < COROS; coro++) {
        stack_ptrs[coro] = (uintptr_t)stacks[coro];
        coro_ids[coro] = coro;
        microkit_cothread_semaphore_init(&completed[coro]);
    }

    microkit_cothread_init(&scheduler, CO_STACK_SIZE, stack_ptrs);

    for (unsigned coro = 0; coro < COROS; coro++)
        microkit_cothread_spawn(coro_entry, &coro_ids[coro]);

    microkit_cothread_yield();
}

void notified(microkit_channel channel)
{
    if (channel != blk_channel) {
        return;
    }

    while (!blk_queue_empty_resp(&blk_queue)) {
        blk_resp_status_t status;
        uint16_t count;
        uint32_t coro;

        assert(blk_dequeue_resp(&blk_queue, &status, &count, &coro) == 0);
        assert(status == BLK_RESP_OK && count == 1);

        // Release a coroutine which is blocked on the data that is read from this buffer.
        microkit_cothread_semaphore_signal(&completed[coro]);
    }

    microkit_cothread_yield();
}
