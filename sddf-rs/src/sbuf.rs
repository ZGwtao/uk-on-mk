use alloc::boxed::Box;
use core::{mem::MaybeUninit, ptr::NonNull};

use crate::{net_buffer_size, RxBufferHandle, TxBufferHandle};

// Keep this prefix in step with Demikernel's DPDK-compatible MetaData.
#[repr(C, align(64))]
struct BufferMeta {
    data: *mut u8,
    _iova: MaybeUninit<u64>,
    data_off: u16,
    references: u16,
    segments: u16,
    _port: MaybeUninit<u16>,
    flags: u64,
    _packet_type: MaybeUninit<u32>,
    packet_len: u32,
    data_len: u16,
    _vlan: MaybeUninit<u16>,
    _various1: MaybeUninit<u32>,
    _various2: MaybeUninit<u32>,
    _outer_vlan: MaybeUninit<u16>,
    capacity: u16,
    pool: *mut (),
    next: Option<NonNull<BufferMeta>>,
    _tx_offload: MaybeUninit<u64>,
    _shared_info: MaybeUninit<u64>,
    _priv_size: MaybeUninit<u16>,
    _timesync: MaybeUninit<u16>,
    _dynfield: MaybeUninit<[u32; 9]>,
}

const _: () = assert!(core::mem::size_of::<BufferMeta>() == 128);
const _: () = assert!(core::mem::align_of::<BufferMeta>() == 64);
const _: () = assert!(core::mem::offset_of!(SBuf, meta) == 0);

impl BufferMeta {
    fn new(data: *mut u8, size: u16, headroom: u16) -> Self {
        Self {
            data,
            _iova: MaybeUninit::uninit(),
            data_off: headroom,
            references: 1,
            segments: 1,
            _port: MaybeUninit::uninit(),
            flags: 0,
            _packet_type: MaybeUninit::uninit(),
            packet_len: size as u32,
            data_len: size,
            _vlan: MaybeUninit::uninit(),
            _various1: MaybeUninit::uninit(),
            _various2: MaybeUninit::uninit(),
            _outer_vlan: MaybeUninit::uninit(),
            capacity: net_buffer_size() as u16,
            pool: core::ptr::null_mut(),
            next: None,
            _tx_offload: MaybeUninit::uninit(),
            _shared_info: MaybeUninit::uninit(),
            _priv_size: MaybeUninit::new(0),
            _timesync: MaybeUninit::uninit(),
            _dynfield: MaybeUninit::uninit(),
        }
    }
}

#[derive(Clone)]
enum BufferHandle {
    Tx(TxBufferHandle),
    Rx(RxBufferHandle),
}

/// An sDDF buffer handle with DPDK-compatible packet metadata.
/// The metadata is first so Demikernel can wrap an `SBuf*` like an `rte_mbuf*`.
/// Ref: `dep/demikernel/src/runtime/memory/demibuffer.rs` (`from_sddf` and `as_metadata`).
#[repr(C)]
pub struct SBuf {
    meta: BufferMeta,
    // Owns one TX/RX buffer handle used to check TX return, clone, publish, or release the buffer.
    // Cloned SBufs have separate handles to the same data, so callers must coordinate writes and publication.
    handle: BufferHandle,
}

impl SBuf {
    fn new(handle: BufferHandle, size: u16, headroom: u16) -> *mut Self {
        let data = match &handle {
            BufferHandle::Tx(r) => r.data_ptr(),
            BufferHandle::Rx(r) => r.data_ptr(),
        };
        Box::into_raw(Box::new(Self { meta: BufferMeta::new(data, size, headroom), handle }))
    }

    pub fn tx(handle: TxBufferHandle, size: u16, headroom: u16) -> *mut Self {
        Self::new(BufferHandle::Tx(handle), size, headroom)
    }

    pub fn rx(handle: RxBufferHandle) -> *mut Self {
        let size = handle.len() as u16;
        Self::new(BufferHandle::Rx(handle), size, 0)
    }

    pub fn clone_raw(&self, size: u16, headroom: u16) -> *mut Self {
        Self::new(self.handle.clone(), size, headroom)
    }

    pub fn is_tx(&self) -> bool {
        matches!(self.handle, BufferHandle::Tx(_))
    }

    pub fn is_returned(&self) -> bool {
        match &self.handle {
            BufferHandle::Tx(r) => r.is_returned(),
            BufferHandle::Rx(_) => true,
        }
    }

    pub fn try_publish(&mut self, len: usize) -> bool {
        match &mut self.handle {
            BufferHandle::Tx(r) => r.try_publish(len),
            BufferHandle::Rx(_) => false,
        }
    }

    /// Releases one owned sDDF reference and its metadata.
    ///
    /// # Safety
    /// `ptr` must come from `SBuf::tx`, `SBuf::rx`, or `SBuf::clone_raw` exactly once.
    pub unsafe fn drop_raw(ptr: *mut Self) {
        drop(Box::from_raw(ptr));
    }
}
