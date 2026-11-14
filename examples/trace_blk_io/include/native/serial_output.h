#pragma once

#include <microkit.h>
#include <sddf/serial/config.h>
#include <sddf/serial/queue.h>

extern serial_queue_handle_t output_queue;
extern microkit_channel output_channel;

static inline void output_init(const serial_client_config_t *config)
{
    serial_queue_init(&output_queue, config->tx.queue.vaddr,
                      config->tx.data.size, config->tx.data.vaddr);
    output_channel = config->tx.id;
}

static inline void output_puts(const char *text)
{
    uint32_t old_tail = output_queue.queue->tail;
    uint32_t tail = old_tail;

    while (*text) {
        if (*text == '\n') serial_enqueue_local(&output_queue, &tail, '\r');
        serial_enqueue_local(&output_queue, &tail, *text++);
    }

    if (tail != old_tail) {
        serial_update_shared_tail(&output_queue, tail);
        microkit_notify(output_channel);
    }
}
