#![no_std]

unsafe extern "C" {
    fn demi_sddf_net_get_mac() -> *const u8;
    fn demi_sddf_net_buffer_size() -> usize;
    fn demi_sddf_net_tx_buffer_count() -> usize;
    fn demi_sddf_net_rx_buffer_count() -> usize;
    fn demi_sddf_net_init() -> i32;
    fn demi_sddf_net_tx_acquire(offset: *mut u64, data: *mut *mut u8) -> i32;
    fn demi_sddf_net_tx_retain(offset: u64);
    fn demi_sddf_net_tx_is_returned(offset: u64) -> bool;
    fn demi_sddf_net_tx_release(offset: u64);
    fn demi_sddf_net_tx_publish(offset: u64, len: u16) -> i32;
    fn demi_sddf_net_rx_acquire(offset: *mut u64, data: *mut *mut u8, len: *mut u16) -> i32;
    fn demi_sddf_net_rx_retain(offset: u64);
    fn demi_sddf_net_rx_release(offset: u64);
    fn demi_sddf_timer_init() -> i32;
    fn demi_sddf_timer_channel() -> u32;
    fn demi_sddf_timer_now() -> u64;
}

/// Offset is the index of the Rx buffer (i.e., io_or_offset)
/// Data is the pointer (vaddr) that points to the base of the Rx buffer
/// Len is the length of the valid bytes of the frame in the Rx buffer
pub struct RxReference {
    offset: u64,
    data: *mut u8,
    len: u16,
}

impl RxReference {
    pub fn data_ptr(&self) -> *mut u8 {
        self.data
    }

    pub fn len(&self) -> usize {
        self.len as usize
    }
}

pub fn rx_acquire() -> Result<Option<RxReference>, ()> {
    let mut offset = 0;
    let mut data = core::ptr::null_mut();
    let mut len = 0;
    match unsafe { demi_sddf_net_rx_acquire(&mut offset, &mut data, &mut len) } {
        0 => Ok(None),
        1 => Ok(Some(RxReference { offset, data, len })),
        _ => Err(()),
    }
}

impl Clone for RxReference {
    fn clone(&self) -> Self {
        unsafe { demi_sddf_net_rx_retain(self.offset) };
        Self { offset: self.offset, data: self.data, len: self.len }
    }
}

impl Drop for RxReference {
    fn drop(&mut self) {
        unsafe { demi_sddf_net_rx_release(self.offset) };
    }
}

/// Offset is the index of the TX buffer (i.e., io_or_offset)
/// Data is the pointer (vaddr) that points to the base of the TX buffer
/// (No length is provided, as the TX buffer is empty when acquired)
pub struct TxReference {
    offset: Option<u64>,
    data: *mut u8,
}

impl TxReference {
    pub fn data_ptr(&self) -> *mut u8 {
        self.data
    }

    /// Access the slot while no other holder or sDDF is reading it.
    pub fn as_mut_slice(&mut self) -> &mut [u8] {
        unsafe { core::slice::from_raw_parts_mut(self.data, net_buffer_size()) }
    }

    /// Whether the buffer is not occupied by any outstanding I/O request.
    pub fn is_returned(&self) -> bool {
        unsafe { demi_sddf_net_tx_is_returned(self.offset.unwrap()) }
    }

    /// len: length of available bytes of frame within the TX buffer to transmit.
    pub fn try_publish(&mut self, len: usize) -> bool {
        assert!(len <= net_buffer_size());
        if unsafe { demi_sddf_net_tx_publish(self.offset.unwrap(), len as u16) } != 0 {
            return false;
        }
        self.offset = None;
        true
    }

}

pub fn tx_acquire() -> Option<TxReference> {
    let mut offset = 0;
    let mut data = core::ptr::null_mut();
    if unsafe { demi_sddf_net_tx_acquire(&mut offset, &mut data) } != 0 {
        return None;
    }
    Some(TxReference { offset: Some(offset), data })
}

impl Clone for TxReference {
    fn clone(&self) -> Self {
        unsafe { demi_sddf_net_tx_retain(self.offset.unwrap()) };
        Self { offset: self.offset, data: self.data }
    }
}

impl Drop for TxReference {
    fn drop(&mut self) {
        if let Some(offset) = self.offset.take() {
            unsafe { demi_sddf_net_tx_release(offset) };
        }
    }
}

pub fn net_buffer_size() -> usize {
    unsafe { demi_sddf_net_buffer_size() }
}

pub fn tx_buffer_count() -> usize {
    unsafe { demi_sddf_net_tx_buffer_count() }
}

pub fn rx_buffer_count() -> usize {
    unsafe { demi_sddf_net_rx_buffer_count() }
}

pub fn net_mac() -> [u8; 6] {
    let mut mac = [0; 6];
    unsafe { core::ptr::copy_nonoverlapping(demi_sddf_net_get_mac(), mac.as_mut_ptr(), mac.len()) };
    mac
}

pub fn net_init() -> i32 {
    unsafe { demi_sddf_net_init() }
}

pub fn net_send_copy(data: &[u8]) -> i32 {
    if data.len() > net_buffer_size() {
        return -1;
    }
    let Some(mut buffer) = tx_acquire() else {
        return -1;
    };
    buffer.as_mut_slice()[..data.len()].copy_from_slice(data);
    if buffer.try_publish(data.len()) { 0 } else { -1 }
}

pub fn net_recv_copy(data: &mut [u8]) -> i32 {
    match rx_acquire() {
        Ok(Some(buffer)) if buffer.len() <= data.len() => {
            let len = buffer.len();
            unsafe { core::ptr::copy_nonoverlapping(buffer.data_ptr(), data.as_mut_ptr(), len) };
            len as i32
        },
        Ok(None) => 0,
        _ => -1,
    }
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
