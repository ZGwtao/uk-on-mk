// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

/// Returns a stable numeric identifier derived from the Microkit PD name.
pub fn id() -> u32 {
    sel4_microkit_base::pd_name()
        .expect("Microkit PD name is not UTF-8")
        .bytes()
        .fold(0x811c9dc5_u32, |hash, byte| {
            (hash ^ u32::from(byte)).wrapping_mul(0x01000193)
        })
}
