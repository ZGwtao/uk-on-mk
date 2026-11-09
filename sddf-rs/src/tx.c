#include "buffer.h"
#include <microkit.h>
#include <sddf/network/constants.h>

#define NO_TX_BUFFER UINT16_MAX

static net_client_config_t *net_config;
static net_queue_handle_t *tx_queue;

static tx_slot_t tx_slots[SDDF_RS_MAX_TX_BUFFERS];

/*
 * Keep track of all available TX buffer dequeued from TX free queue.
 * The available TX buffers form a FIFO ready queue where each buffer
 * has zero reference count and is not occupied by any outstanding I/O
 * request.
 */
typedef struct {
    uint16_t head;
    uint16_t tail;
} tx_ready_queue_t;

static tx_ready_queue_t ready_tx = {NO_TX_BUFFER, NO_TX_BUFFER};


static uint16_t tx_index(uint64_t offset)
{
    return offset / NET_BUFFER_SIZE;
}

/* FIFO order lets returned slots rotate instead of reusing the newest one. */
static void tx_ready_enqueue(uint16_t index)
{
    tx_slots[index].next_ready = NO_TX_BUFFER;

    if (ready_tx.tail == NO_TX_BUFFER)
        ready_tx.head = index;
    else
        tx_slots[ready_tx.tail].next_ready = index;

    ready_tx.tail = index;
}

static uint16_t tx_ready_dequeue(void)
{
    uint16_t index = ready_tx.head;
    if (index == NO_TX_BUFFER)
        return index;

    ready_tx.head = tx_slots[index].next_ready;
    if (ready_tx.head == NO_TX_BUFFER)
        ready_tx.tail = NO_TX_BUFFER;

    return index;
}

static void tx_drop_reference(uint16_t index)
{
    tx_slot_t *slot = &tx_slots[index];
    // When ref is zero and in_flight is false, it's common when there's no buffer
    // copying happening on this slot, so we can recycle the buffer right after
    // the server/virt enqueue it back to the TX free queue.
    if (--slot->references == 0 && !slot->in_flight)
        tx_ready_enqueue(index);
}

/* sDDF returns transmitted descriptors through the TX free queue. */
static void tx_reclaim(void)
{
    // Trying to populate all available TX buffer from free queue,
    // which is to bookkeep all available buffers via the tx_ready_queue
    // for reference-counting purpose.
    net_buff_desc_t desc;
    while (net_dequeue_free(tx_queue, &desc) == 0) {
        uint16_t index = tx_index(desc.io_or_offset);
        tx_slots[index].in_flight = false;
        if (tx_slots[index].references == 0)
            tx_ready_enqueue(index);
    }
}

int demi_sddf_tx_init(net_client_config_t *config, net_queue_handle_t *tx)
{
    if (config->tx.num_buffers > SDDF_RS_MAX_TX_BUFFERS)
        return -1;
    net_config = config;
    tx_queue = tx;
    return 0;
}

void demi_sddf_tx_init_ready(void)
{
    tx_reclaim();
}

int demi_sddf_net_tx_acquire(uint64_t *offset, uint8_t **data)
{
    // Before trying to acquire available TX buffers, try recycling
    // what's been returned by the server/virt in TX free queue.
    if (ready_tx.head == NO_TX_BUFFER)
        tx_reclaim();

    // At this point, all TX buffer from TX free queue should reside
    // in the tx_ready_queue with either zero or not reference.
    // If the attempt to dequeue from the ready queue still fails,
    // it simply means there is no available TX buffer at the moment,
    // i.e., either occupied by other coroutines or haven't been returned
    // by the server/virt.
    uint16_t index = tx_ready_dequeue();
    if (index == NO_TX_BUFFER)
        return -1;

    tx_slots[index].references = 1;

    *offset = (uint64_t)index * NET_BUFFER_SIZE;
    *data = (uint8_t *)net_config->tx_data.vaddr + *offset;

    return 0;
}

void demi_sddf_net_tx_retain(uint64_t offset)
{
    tx_slots[tx_index(offset)].references++;
}

bool demi_sddf_net_tx_is_returned(uint64_t offset)
{
    tx_reclaim();
    // If the tx buffer pointed by offset is returned by the server (virt),
    // it will appear in the TX free queue, which means it will be processed
    // by 'tx_reclaim' above and had the attribute of 'in_flight' set to false.
    // Otherwise, if in_flight is true, the buffer has then not been returned
    // by the virt/server yet.
    return !tx_slots[tx_index(offset)].in_flight;
}

void demi_sddf_net_tx_release(uint64_t offset)
{
    tx_drop_reference(tx_index(offset));
}

int demi_sddf_net_tx_publish(uint64_t offset, uint16_t len)
{
    tx_reclaim();

    if (tx_slots[tx_index(offset)].in_flight)
        return -1;

    tx_slots[tx_index(offset)].in_flight = true;

    net_buff_desc_t desc = {
        .io_or_offset = offset,
        .len = len,
        .oid = 0
    };

    net_enqueue_active(tx_queue, desc);
    if (net_require_signal_active(tx_queue)) {
        net_cancel_signal_active(tx_queue);
        microkit_notify(net_config->tx.id);
    }

    tx_drop_reference(tx_index(offset));

    return 0;
}
