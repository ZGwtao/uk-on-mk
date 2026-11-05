// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

use core::fmt;

#[derive(Debug)]
pub struct Error;

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("unexpected end of buffer")
    }
}

impl core::error::Error for Error {}

pub trait Read {
    fn read_exact(&mut self, buf: &mut [u8]) -> Result<(), Error>;
}

pub struct Cursor<T> {
    inner: T,
    position: u64,
}

impl<T> Cursor<T> {
    pub fn new(inner: T) -> Self {
        Self { inner, position: 0 }
    }

    pub fn position(&self) -> u64 {
        self.position
    }
}

impl Read for Cursor<&[u8]> {
    fn read_exact(&mut self, buf: &mut [u8]) -> Result<(), Error> {
        let start = self.position as usize;
        let end = start + buf.len();
        if end > self.inner.len() {
            return Err(Error);
        }
        buf.copy_from_slice(&self.inner[start..end]);
        self.position = end as u64;
        Ok(())
    }
}
