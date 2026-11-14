#pragma once

#include "solo5.h"

static inline void blk_console_write(const char *text)
{
    size_t l = 0;
    while (text[l]) l++;
    solo5_console_write(text, l);
}
