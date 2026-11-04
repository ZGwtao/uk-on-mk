// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

#![no_std]
#![feature(allocator_api)]

extern crate alloc as rust_alloc;

pub use core::{
    any, borrow, cell, cmp, convert, error, ffi, fmt, future, hash, iter, marker, mem, net, num,
    ops, option, pin, ptr, result, slice, str, task,
};
pub use rust_alloc::{boxed, collections, rc, string, sync, vec};

pub mod alloc {
    pub use crate::rust_alloc::alloc::{alloc, dealloc, handle_alloc_error, Global};
    pub use core::alloc::*;
}

pub mod time {
    pub use core::time::Duration;
}
