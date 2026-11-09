#include "buffer.h"
#include <microkit.h>
#include <sddf/network/config.h>
#include <sddf/network/constants.h>
#include <sddf/network/queue.h>

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

size_t demi_sddf_net_tx_buffer_count(void)
{
    return demi_sddf_net_config.tx.num_buffers;
}

size_t demi_sddf_net_rx_buffer_count(void)
{
    return demi_sddf_net_config.rx.num_buffers;
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

    if (demi_sddf_tx_init(&demi_sddf_net_config, &tx) != 0 ||
        demi_sddf_rx_init(&demi_sddf_net_config, &rx) != 0)
        return -1;

    net_queue_init(&rx, demi_sddf_net_config.rx.free_queue.vaddr,
                   demi_sddf_net_config.rx.active_queue.vaddr,
                   demi_sddf_net_config.rx.num_buffers);
    net_queue_init(&tx, demi_sddf_net_config.tx.free_queue.vaddr,
                   demi_sddf_net_config.tx.active_queue.vaddr,
                   demi_sddf_net_config.tx.num_buffers);
    net_buffers_init(&tx, 0);

    // Populate all available TX buffer from TX free queue to the tx_ready_queue,
    // so the reference-counting mechanism can be enforced on the TX buffers.
    demi_sddf_tx_init_ready();

    return 0;
}
