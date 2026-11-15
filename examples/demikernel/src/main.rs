#![no_std]
#![no_main]

extern crate alloc;

use core::net::{Ipv4Addr, SocketAddr, SocketAddrV4};
use demikernel::{demikernel::config::Config, LibOS, LibOSName, MacAddress};

// Reuse Demikernel's original Rust examples through local symlinks.
#[cfg(feature = "app-udp-echo")]
mod udp_echo;
#[cfg(feature = "app-udp-dump")]
mod udp_dump;
#[cfg(feature = "app-udp-ping-pong")]
mod udp_ping_pong;
#[cfg(feature = "app-udp-pktgen")]
mod udp_pktgen;
#[cfg(feature = "app-udp-push-pop")]
mod udp_push_pop;
#[cfg(feature = "app-udp-relay")]
mod udp_relay;

// Let rust-seL4 set up the Microkit runtime before calling our main function.
sel4_microkit::_private::declare_entrypoint!();
// Reserve heap space for Demikernel's allocations.
sel4_microkit::declare_heap!(8 * 1024 * 1024);

// QEMU forwards host UDP port 1235 to this guest address and port.
const GUEST_IP: Ipv4Addr = Ipv4Addr::new(10, 0, 2, 15);
const GUEST_PORT: u16 = 1235;
// QEMU's user network exposes the host at this address.
#[cfg(any(feature = "app-udp-ping-pong", feature = "app-udp-pktgen", feature = "app-udp-push-pop", feature = "app-udp-relay"))]
const HOST_IP: Ipv4Addr = Ipv4Addr::new(10, 0, 2, 2);
#[cfg(any(feature = "app-udp-ping-pong", feature = "app-udp-pktgen", feature = "app-udp-push-pop", feature = "app-udp-relay"))]
const HOST_PORT: u16 = 1236;


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

    #[cfg(feature = "app-udp-echo")]
    udp_echo::run_with_libos(libos, local_addr).expect("udp-echo failed");
    #[cfg(feature = "app-udp-dump")]
    udp_dump::run_with_libos(libos, local_addr).expect("udp-dump failed");
    #[cfg(any(feature = "app-udp-ping-pong", feature = "app-udp-pktgen", feature = "app-udp-push-pop", feature = "app-udp-relay"))]
    let remote_addr = SocketAddr::V4(SocketAddrV4::new(HOST_IP, HOST_PORT));

    #[cfg(feature = "app-udp-ping-pong")]
    udp_ping_pong::run_with_libos(libos, local_addr, remote_addr, cfg!(feature = "mode-client"))
        .expect("udp-ping-pong failed");
    #[cfg(feature = "app-udp-pktgen")]
    udp_pktgen::run_with_libos(libos, local_addr, remote_addr, 1024, 100)
        .expect("udp-pktgen failed");
    #[cfg(feature = "app-udp-push-pop")]
    udp_push_pop::run_with_libos(libos, local_addr, remote_addr, cfg!(feature = "mode-client"))
        .expect("udp-push-pop failed");
    #[cfg(feature = "app-udp-relay")]
    udp_relay::run_with_libos(libos, local_addr, remote_addr).expect("udp-relay failed");

    // Microkit PD entrypoints must not return after a finite application completes.
    loop {
        let _ = sel4_microkit::ipc::recv();
    }
}
