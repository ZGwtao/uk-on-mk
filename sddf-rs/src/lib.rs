#![no_std]

unsafe extern "C" {
    fn demi_sddf_net_get_mac() -> *const u8;
    fn demi_sddf_net_buffer_size() -> usize;
    fn demi_sddf_net_init() -> i32;
    fn demi_sddf_net_send(data: *const u8, len: usize) -> i32;
    fn demi_sddf_net_recv_copy(data: *mut u8, capacity: usize) -> i32;
    fn demi_sddf_timer_init() -> i32;
    fn demi_sddf_timer_channel() -> u32;
    fn demi_sddf_timer_now() -> u64;
}

pub fn net_buffer_size() -> usize {
    unsafe { demi_sddf_net_buffer_size() }
}

pub fn net_mac() -> [u8; 6] {
    let mut mac = [0; 6];
    unsafe { core::ptr::copy_nonoverlapping(demi_sddf_net_get_mac(), mac.as_mut_ptr(), mac.len()) };
    mac
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

pub fn timer_init() -> i32 {
    unsafe { demi_sddf_timer_init() }
}

pub fn timer_channel() -> usize {
    unsafe { demi_sddf_timer_channel() as usize }
}

pub fn timer_now() -> u64 {
    unsafe { demi_sddf_timer_now() }
}
