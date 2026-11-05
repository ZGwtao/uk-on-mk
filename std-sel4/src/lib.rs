// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

#![no_std]
#![feature(allocator_api)]

extern crate alloc as rust_alloc;

pub use core::{
    any, borrow, cell, cmp, convert, error, ffi, fmt, future, iter, marker, mem, net, num, ops,
    option, pin, ptr, result, slice, str, task,
};
pub use rust_alloc::{boxed, rc, string, sync, vec};

pub mod collections {
    pub use crate::rust_alloc::collections::*;
    pub use hashbrown::{hash_map, hash_set, HashMap, HashSet};
}

pub mod hash {
    pub use core::hash::*;
    pub type RandomState = hashbrown::DefaultHashBuilder;
}

pub mod alloc {
    pub use crate::rust_alloc::alloc::{alloc, dealloc, handle_alloc_error, Global};
    pub use core::alloc::*;
}

pub mod time {
    pub use core::time::Duration;
    mod instant;
    pub use instant::Instant;
}
