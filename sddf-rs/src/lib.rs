#![no_std]

unsafe extern "C" {
    fn demi_sddf_net_buffer_size() -> usize;
    fn demi_sddf_net_init() -> i32;
    fn demi_sddf_net_send(data: *const u8, len: usize) -> i32;
    fn demi_sddf_net_recv_copy(data: *mut u8, capacity: usize) -> i32;
}

pub fn net_buffer_size() -> usize {
    unsafe { demi_sddf_net_buffer_size() }
}

pub fn net_init() -> i32 {
    unsafe { demi_sddf_net_init() }
}

pub fn net_send(data: &[u8]) -> i32 {
    unsafe { demi_sddf_net_send(data.as_ptr(), data.len()) }
}

pub fn net_recv(data: &mut [u8]) -> i32 {
    unsafe { demi_sddf_net_recv_copy(data.as_mut_ptr(), data.len()) }
}
