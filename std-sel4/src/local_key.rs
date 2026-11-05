// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

use core::cell::UnsafeCell;

pub struct LocalKey<T> {
    value: UnsafeCell<Option<T>>,
    init: fn() -> T,
}

// Each LocalKey instance is placed in thread-local storage by thread_local!.
unsafe impl<T> Sync for LocalKey<T> {}

impl<T> LocalKey<T> {
    /// The caller must place this key in thread-local storage.
    pub const unsafe fn new(init: fn() -> T) -> Self {
        Self { value: UnsafeCell::new(None), init }
    }

    pub fn with<R>(&self, f: impl FnOnce(&T) -> R) -> R {
        let value = unsafe { &mut *self.value.get() };
        f(value.get_or_insert_with(self.init))
    }
}
