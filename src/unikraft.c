#include <microkit.h>

#include <sddf/timer/client.h>
#include <sddf/timer/config.h>
#include <sddf/serial/queue.h>
#include <sddf/serial/config.h>

#include <sddf/util/printf.h>

__attribute__((__section__(".serial_client_config")))
serial_client_config_t serial_config;
__attribute__((__section__(".timer_client_config")))
timer_client_config_t timer_config;

serial_queue_handle_t serial_rx_queue_handle;
serial_queue_handle_t serial_tx_queue_handle;


sddf_channel timer_channel;


void init(void)
{
    assert(serial_config_check_magic(&serial_config));
    if (serial_config.rx.queue.vaddr != NULL) {
        serial_queue_init(&serial_rx_queue_handle,
                          serial_config.rx.queue.vaddr,
                          serial_config.rx.data.size,
                          serial_config.rx.data.vaddr);
    }
    serial_queue_init(&serial_tx_queue_handle,
                      serial_config.tx.queue.vaddr,
                      serial_config.tx.data.size,
                      serial_config.tx.data.vaddr);
    serial_putchar_init(serial_config.tx.id, &serial_tx_queue_handle);

    assert(timer_config_check_magic(&timer_config));

    timer_channel = timer_config.driver_id;

    sddf_printf("bench_simple: point of exit\n");
    sddf_timer_set_timeout(timer_channel, NS_IN_S * 2);
}

void notified(microkit_channel ch)
{
    if (ch == timer_channel) {
        sddf_timer_set_timeout(timer_channel, NS_IN_S * 2);
        uint64_t time = sddf_timer_time_now(timer_channel);
        sddf_printf("CLIENT|INFO: timer: %lu ns\n", time);
    }
}
