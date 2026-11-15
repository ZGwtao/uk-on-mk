#pragma once

#include <stdint.h>

static inline char *result_append_text(char *out, const char *text)
{
    while (*text)
        *out++ = *text++;

    return out;
}

static inline char *result_append_number(char *out, uint64_t value)
{
    char digits[20];
    unsigned count = 0;

    do {
        digits[count++] = '0' + value % 10;
        value /= 10;
    } while (value);

    while (count)
        *out++ = digits[--count];

    return out;
}

static inline char *result_append_field(char *out, const char *name, uint64_t value)
{
    out = result_append_text(out, name);

    return result_append_number(out, value);
}

static inline void result_end_line(char *out)
{
    *out++ = '\n';
    *out = '\0';
}

static inline void format_io_result(char out[128], const char *mode,
                                    uint64_t elapsed_ns, uint64_t reads)
{
    uint64_t iops = elapsed_ns ? reads * UINT64_C(1000000000) / elapsed_ns : 0;

    char *p = result_append_text(out, "RESULT mode=");

    p = result_append_text(p, mode);
    p = result_append_field(p, " reads=", reads);
    p = result_append_field(p, " elapsed_ns=", elapsed_ns);
    p = result_append_field(p, " iops=", iops);

    result_end_line(p);
}

