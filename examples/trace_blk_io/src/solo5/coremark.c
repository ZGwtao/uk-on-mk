#include "solo5.h"
#include "libco.h"
#include "coremark.h"
#include "block_io.h"
#include "coremark_runner.h"
#include "console.h"
#include "result.h"

static cothread_t scheduler;
static cothread_t controller;

static cothread_t worker_handles[COMPUTE_COROS];
static core_results *worker_results[COMPUTE_COROS];

static unsigned worker_count;
/* libco has no coroutine arguments, so the scheduler selects the worker
 * before its first switch; the worker keeps its ID on its own stack.
 */
static unsigned running_worker;
static int controller_done;

/* CoreMark emits characters; the Solo5 console helper accepts strings. */
static char console_line[256];
static unsigned console_length;

/* coremark.mk compiles core_main.c with -Dmain=coremark_main, so its main()
 * becomes this callable entry point before linking with our Solo5 app.
 */
int coremark_main(void);

static void coremark_worker(void)
{
    unsigned id = running_worker;
    core_results *res = worker_results[id];
    iterate(res);
    res->port.done = 1;
    /* libco cannot destroy a coroutine; park it after CoreMark is done. */
    for (;;)
        co_switch(scheduler);
}

static void controller_entry(void)
{
    coremark_main();
    blk_console_write("BENCH_DONE mode=solo5\n");
    controller_done = 1;
    /* Keep the finished controller available as a valid libco context. */
    for (;;)
        co_switch(scheduler);
}

void coremark_runner_init(cothread_t scheduler_handle,
                          void *compute_stacks, size_t stack_size)
{
    scheduler = scheduler_handle;

    /* The result contexts are assigned later by core_start_parallel(); libco
     * coroutine creation itself does not need them, so create all handles now.
     */
    uint8_t *stacks = compute_stacks;
    for (unsigned id = 0; id < COMPUTE_COROS; id++)
        worker_handles[id] = co_derive(stacks + id * stack_size, stack_size,
                                       coremark_worker);
    controller = co_derive(stacks + COMPUTE_COROS * stack_size, stack_size,
                           controller_entry);
}

void coremark_runner_resume_controller(void)
{
    co_switch(controller);
}

void coremark_runner_resume_workers(void)
{
    /* Each live worker runs to its next CoreMark yield. The scheduler then
     * gets a chance to run I/O before revisiting that worker.
     */
    for (unsigned id = 0; id < worker_count; id++) {
        if (!worker_results[id]->port.done) {
            running_worker = id;
            co_switch(worker_handles[id]);
        }
    }
}

int coremark_runner_done(void)
{
    return controller_done;
}

/* ---- Implement hooks of trace_platform.h ---- */

void coremark_port_yield(void)
{
    co_switch(scheduler);
}

ee_u8 core_start_parallel(core_results *res)
{
    /* CoreMark may ask for at most COMPUTE_COROS workers. */
    if (worker_count == COMPUTE_COROS)
        return 1;

    unsigned id = worker_count++;
    res->port.done = 0;
    worker_results[id] = res;
    return 0;
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
        blk_console_write(console_line);
        console_length = 0;
    }
}

uint64_t trace_coremark_now_ns(void)
{
    return solo5_clock_monotonic();
}

void trace_coremark_io_start(uint64_t now_ns)
{
    bench_io_start(now_ns);
}

void trace_coremark_io_stop(uint64_t now_ns)
{
    read_run_state_t run = bench_io_stop();
    char line[128];
    format_io_result(line, "solo5", read_run_elapsed_ns(&run, now_ns),
                     read_run_completed(&run));
    blk_console_write(line);
}
