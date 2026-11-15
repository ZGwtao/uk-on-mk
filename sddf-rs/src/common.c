#include <microkit.h>

// The rust-seL4 Microkit runtime uses this same fixed IPC buffer address.
seL4_IPCBuffer *__sel4_ipc_buffer =
    (seL4_IPCBuffer *)(seL4_UserVSpaceTop & ~((1UL << seL4_PageBits) - 1));

__attribute__((weak)) void microkit_dbg_puts(const char *s)
{
    while (*s)
        seL4_DebugPutChar(*s++);
}

/* Match libmicrokit's decimal output for its debug diagnostics. */
__attribute__((weak)) void microkit_dbg_put32(seL4_Uint32 x)
{
    char tmp[11];
    unsigned i = 10;
    tmp[10] = 0;
    do {
        seL4_Uint8 c = x % 10;
        tmp[--i] = '0' + c;
        x /= 10;
    } while (x);
    microkit_dbg_puts(&tmp[i]);
}
