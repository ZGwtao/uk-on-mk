#include <microkit.h>
#include <sddf/network/config.h>
#include <sddf/network/constants.h>
#include <sddf/network/queue.h>
#include <stdbool.h>
#include <string.h>

// The rust-seL4 Microkit runtime uses this same fixed IPC buffer address.
seL4_IPCBuffer *__sel4_ipc_buffer =
    (seL4_IPCBuffer *)(seL4_UserVSpaceTop & ~((1UL << seL4_PageBits) - 1));

__attribute__((section(".net_client_config"), used))
net_client_config_t demi_sddf_net_config;

static net_queue_handle_t rx;
static net_queue_handle_t tx;

const uint8_t *demi_sddf_net_get_mac(void)
{
    return demi_sddf_net_config.mac_addr.addr;
}

size_t demi_sddf_net_buffer_size(void)
{
    return NET_BUFFER_SIZE;
}

static const uint8_t *get_rx_data(net_buff_desc_t desc)
{
    return (const uint8_t *)demi_sddf_net_config.rx_data.vaddr + desc.io_or_offset;
}

static uint8_t *get_tx_data(net_buff_desc_t desc)
{
    return (uint8_t *)demi_sddf_net_config.tx_data.vaddr + desc.io_or_offset;
}

static bool rx_desc_fits(net_buff_desc_t desc, size_t capacity)
{
    return desc.len <= capacity && desc.len <= NET_BUFFER_SIZE &&
           desc.io_or_offset <= demi_sddf_net_config.rx_data.size &&
           desc.len <= demi_sddf_net_config.rx_data.size - desc.io_or_offset;
}

void _assert_fail(const char *expression, const char *file, unsigned line,
                  const char *function)
{
    (void)expression;
    (void)file;
    (void)line;
    (void)function;
    __builtin_trap();
}

int demi_sddf_net_init(void)
{
    if (!net_config_check_magic(&demi_sddf_net_config))
        return -1;
    net_queue_init(&rx, demi_sddf_net_config.rx.free_queue.vaddr,
                   demi_sddf_net_config.rx.active_queue.vaddr,
                   demi_sddf_net_config.rx.num_buffers);
    net_queue_init(&tx, demi_sddf_net_config.tx.free_queue.vaddr,
                   demi_sddf_net_config.tx.active_queue.vaddr,
                   demi_sddf_net_config.tx.num_buffers);
    net_buffers_init(&tx, 0);
    return 0;
}

int demi_sddf_net_send(const uint8_t *tx_packet, size_t len)
{
    net_buff_desc_t desc;
    if (len > NET_BUFFER_SIZE || net_dequeue_free(&tx, &desc) != 0)
        return -1;

    // @gt A copy from demibuffer to an sddf buffer is not necessary,
    //     but for now just keep it like this for implementing the
    //     ad-hoc physical layer for catlions.
    memcpy(get_tx_data(desc), tx_packet, len);

    desc.len = len;
    desc.oid = 0;

    net_enqueue_active(&tx, desc);
    if (net_require_signal_active(&tx)) {
        net_cancel_signal_active(&tx);
        microkit_notify(demi_sddf_net_config.tx.id);
    }
    return 0;
}

int demi_sddf_net_recv_copy(uint8_t *rx_packet, size_t capacity)
{
    net_buff_desc_t desc;
    if (net_dequeue_active(&rx, &desc) != 0)
        return 0;

    int len = -1;

    if (rx_desc_fits(desc, capacity)) {
        // @gt Same as above.
        memcpy(
            rx_packet,
            get_rx_data(desc),
            desc.len
        );
        len = desc.len;
    }

    desc.len = 0;
    net_enqueue_free(&rx, desc);

    if (net_require_signal_free(&rx)) {
        net_cancel_signal_free(&rx);
        microkit_notify(demi_sddf_net_config.rx.id);
    }
    return len;
}
