#include <stdio.h>
#include <uk/console.h>
#include <uk/sched.h>

int uk_app_main(void)
{
	char buf[128];
	__ssz n;

	puts("Hello from Unikraft!");
	puts("Type input (Ctrl-A X exits QEMU):");
	for (;;) {
		n = uk_console_in(buf, sizeof(buf));
		if (n > 0) {
			uk_console_out("Received: ", 10);
			uk_console_out(buf, (__sz)n);
			uk_console_out("\n", 1);
		}
		uk_sched_yield();
	}
}
