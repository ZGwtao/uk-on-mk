#include <microkit.h>
#include <sddf/timer/client.h>
#include <sddf/timer/config.h>

__attribute__((section(".timer_client_config"), used))
timer_client_config_t demi_sddf_timer_config;

int demi_sddf_timer_init(void)
{
    return timer_config_check_magic(&demi_sddf_timer_config) ? 0 : -1;
}

unsigned demi_sddf_timer_channel(void)
{
    return demi_sddf_timer_config.driver_id;
}

uint64_t demi_sddf_timer_now(void)
{
    return sddf_timer_time_now(demi_sddf_timer_channel());
}
