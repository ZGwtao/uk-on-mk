#include <libmicrokitco.h>
#include <sddf/timer/client.h>
#include "coremark.h"
#include "block_io.h"
#include "coremark_runner.h"
#include "result.h"
#include "serial_output.h"

static microkit_channel timer_channel;
/* CoreMark emits characters; the serial output helper accepts strings. */
static char console_line[256];
static unsigned console_length;


/* coremark.mk compiles core_main.c with -Dmain=coremark_main, so its main()
 * becomes this callable entry point before linking with our Microkit app.
 */
int coremark_main(void);

static void coremark_worker(void)
{
    core_results *res = microkit_cothread_my_arg();

    iterate(res);
    /* core_stop_parallel() waits for this worker's complete iteration set. */
    res->port.done = 1;
}

void coremark_runner_init(microkit_channel channel)
{
    timer_channel = channel;
}

void coremark_controller_entry(void)
{
    coremark_main();
    output_puts("BENCH_DONE mode=native\n");
}

/* ---- Implement hooks of trace_platform.h ---- */

void coremark_port_yield(void)
{
    microkit_cothread_yield();
}

ee_u8 core_start_parallel(core_results *res)
{
    res->port.done = 0;
    /* Microkitco passes res directly as the new coroutine's argument. */
    return microkit_cothread_spawn(coremark_worker, res) < 0;
}

/* CoreMark's "stop" means join: yield until this worker finishes iterate()
 * and sets done. It does not interrupt or cancel the computation.
 */
ee_u8 core_stop_parallel(core_results *res)
{
    while (!res->port.done)
        coremark_port_yield();

    return 0;
}

void trace_coremark_putchar(char c)
{
    console_line[console_length++] = c;
    if (c == '\n' || console_length == sizeof(console_line) - 1) {
        console_line[console_length] = '\0';
        output_puts(console_line);
        console_length = 0;
    }
}

uint64_t trace_coremark_now_ns(void)
{
    return sddf_timer_time_now(timer_channel);
}

void trace_coremark_io_start(uint64_t now_ns)
{
    bench_io_start(now_ns);
}

void trace_coremark_io_stop(uint64_t now_ns)
{
    read_run_state_t run = bench_io_stop();

    char line[128];

    format_io_result(line, "native", read_run_elapsed_ns(&run, now_ns),
                     read_run_completed(&run));
    output_puts(line);
}
