#![no_std]
#![no_main]

extern crate alloc;

use core::net::{Ipv4Addr, SocketAddr, SocketAddrV4};
use demikernel::{demikernel::config::Config, LibOS, LibOSName, MacAddress};

// Reuse Demikernel's original UDP echo example through the local symlink.
mod udp_echo;

// Let rust-seL4 set up the Microkit runtime before calling our main function.
sel4_microkit::_private::declare_entrypoint!();
// Reserve heap space for Demikernel's allocations.
sel4_microkit::declare_heap!(8 * 1024 * 1024);

// QEMU forwards host UDP port 1235 to this guest address and port.
const GUEST_IP: Ipv4Addr = Ipv4Addr::new(10, 0, 2, 15);
const GUEST_PORT: u16 = 1235;


#[unsafe(no_mangle)]
fn __sel4_microkit__main() {

    let config = Config {
        local_ipv4_addr: GUEST_IP,
        local_link_addr: MacAddress::new(sddf_rs::net_mac()),
        tcp_keepalive: false,
        linger: None,
        no_delay: true,
        mtu: 1500,
        mss: 1460,
        tcp_checksum_offload: false,
        udp_checksum_offload: false,
        enable_jumbo_frames: false,
    };

    let libos = LibOS::new_with_config(LibOSName::Catlions, None, config).expect("catlions init");
    let local_addr = SocketAddr::V4(SocketAddrV4::new(GUEST_IP, GUEST_PORT));

    udp_echo::run_with_libos(libos, local_addr).expect("udp-echo failed");
}
