#include "buffer.h"
#include <microkit.h>
#include <sddf/network/constants.h>

static net_client_config_t *net_config;
static net_queue_handle_t *rx_queue;

/*
 * The life-cycle of RX buffer on client side is way simpler than TX buffers'.
 * The client acquire a RX buffer from the RX active queue, where the client serves
 * as a consumer, and use the data within the RX buffer, then enqueue it back
 * to the RX free buffer if the reference count is zero.
 * No outstanding I/O needs to be perform when consuming the RX buffer, hence
 * serialised buffer processing life-cycle.
 */
static rx_slot_t rx_slots[SDDF_RS_MAX_RX_BUFFERS];

/* The last RX reference returns its descriptor and wakes the producer if needed. */
static void rx_return(net_buff_desc_t desc)
{
    desc.len = 0;
    net_enqueue_free(rx_queue, desc);
    if (net_require_signal_free(rx_queue)) {
        net_cancel_signal_free(rx_queue);
        microkit_notify(net_config->rx.id);
    }
}

static bool rx_desc_fits(net_buff_desc_t desc)
{
    return desc.len > 0 && desc.len <= NET_BUFFER_SIZE &&
           desc.io_or_offset % NET_BUFFER_SIZE == 0 &&
           desc.io_or_offset / NET_BUFFER_SIZE < net_config->rx.num_buffers &&
           desc.io_or_offset <= net_config->rx_data.size &&
           desc.len <= net_config->rx_data.size - desc.io_or_offset;
}

int demi_sddf_rx_init(net_client_config_t *config, net_queue_handle_t *rx)
{
    if (config->rx.num_buffers > SDDF_RS_MAX_RX_BUFFERS)
        return -1;
    net_config = config;
    rx_queue = rx;
    return 0;
}

int demi_sddf_net_rx_acquire(uint64_t *offset, uint8_t **data, uint16_t *len)
{
    net_buff_desc_t desc;
    if (net_dequeue_active(rx_queue, &desc) != 0)
        return 0;

    if (!rx_desc_fits(desc)) {
        rx_return(desc);
        return -1;
    }

    uint16_t index = desc.io_or_offset / NET_BUFFER_SIZE;
    rx_slots[index].references = 1;
    rx_slots[index].desc = desc;

    *offset = desc.io_or_offset;
    *data = (uint8_t *)net_config->rx_data.vaddr + *offset;
    *len = desc.len;

    return 1;
}

void demi_sddf_net_rx_retain(uint64_t offset)
{
    rx_slots[offset / NET_BUFFER_SIZE].references++;
}

void demi_sddf_net_rx_release(uint64_t offset)
{
    rx_slot_t *slot = &rx_slots[offset / NET_BUFFER_SIZE];
    if (--slot->references == 0)
        rx_return(slot->desc);
}
