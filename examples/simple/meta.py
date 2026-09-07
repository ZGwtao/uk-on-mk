# Copyright 2026, UNSW
# SPDX-License-Identifier: BSD-2-Clause

import sys
import argparse
import importlib
from pathlib import Path
from typing import Optional
from sdfgen import SystemDescription, Sddf, DeviceTree, LionsOs
from importlib.metadata import version

assert version("sdfgen").split(".")[1] == "35", "Unexpected sdfgen version"

SDF = SystemDescription
PD = SDF.ProtectionDomain
MR = SDF.MemoryRegion
MAP = SDF.Map
IOPORT = SDF.IoPort
IRQIOAPIC = SDF.IrqIoapic


def create_unikernel(name: str):
    unikernel = PD(f"{name}", f"{name}.elf", priority=50, stack_size=0x10000)
    uk_heap = MR(sdf, f"{name}/uk_heap", 0x4000000)
    sdf.add_mr(uk_heap)
    unikernel.add_map(MAP(uk_heap, 0x200000000, perms="rw", cached="true"))
    return unikernel


def generate(
    sdf_path: str,
    output_dir: str,
    dtb: Optional[DeviceTree]
):
    serial_node = None
    timer_node = None
    ethernet_node = None
    
    if dtb is not None:
        serial_node = dtb.node(board.serial)
        assert serial_node is not None
        timer_node = dtb.node(board.timer)
        assert timer_node is not None
        ethernet_node = dtb.node(board.ethernet)
        assert ethernet_node is not None

    timer_driver = PD("timer_driver", "timer_driver.elf", priority=254)
    timer_system = Sddf.Timer(sdf, timer_node, timer_driver)

    if board.arch == SystemDescription.Arch.X86_64:
        hpet_irq = IRQIOAPIC(
            ioapic_id=0,
            pin=2,
            vector=107,
            id=0,
            trigger=IRQIOAPIC.Trigger.EDGE,
        )
        timer_driver.add_irq(hpet_irq)
        hpet_regs = MR(sdf, "hpet_regs", 0x1000, paddr=0xFED00000)
        hpet_regs_map = MAP(hpet_regs, 0x5000_0000, "rw", cached=False)
        timer_driver.add_map(hpet_regs_map)
        sdf.add_mr(hpet_regs)

    serial_driver = PD("serial_driver", "serial_driver.elf", priority=100)
    serial_virt_tx = PD("serial_virt_tx", "serial_virt_tx.elf", priority=99)
    serial_virt_rx = PD("serial_virt_rx", "serial_virt_rx.elf", priority=99)
    serial_system = Sddf.Serial(sdf, serial_node, serial_driver,
                                serial_virt_tx, virt_rx=serial_virt_rx)
    if board.arch == SystemDescription.Arch.X86_64:
        serial_port = IOPORT(0x3F8, 8, 0)
        serial_driver.add_ioport(serial_port)
        serial_driver.add_irq(
            IRQIOAPIC(ioapic_id=0, pin=4, vector=0, id=1)
        )

    ethernet_driver = PD(
        "ethernet_driver",
        "eth_driver.elf",
        priority=101,
        budget=100,
        period=400,
    )

    if board.arch == SystemDescription.Arch.X86_64:
        hw_net_rings = MR(
            sdf, "hw_net_rings", 65536, paddr=0x7A000000
        )
        sdf.add_mr(hw_net_rings)
        hw_net_rings_map = MAP(
            hw_net_rings, 0x7000_0000, "rw", cached=False
        )
        ethernet_driver.add_map(hw_net_rings_map)

        virtio_net_regs = MR(
            sdf, "virtio_net_regs", 0x4000, paddr=0xFE000000
        )
        sdf.add_mr(virtio_net_regs)
        virtio_net_regs_map = MAP(
            virtio_net_regs, 0x6000_0000, "rw", cached=False
        )
        ethernet_driver.add_map(virtio_net_regs_map)

        virtio_net_irq = IRQIOAPIC(
            ioapic_id=0,
            pin=10,
            vector=1,
            id=16,
            trigger=IRQIOAPIC.Trigger.LEVEL,
            polarity=IRQIOAPIC.Polarity.ACTIVELOW,
        )
        ethernet_driver.add_irq(virtio_net_irq)

    net_virt_tx = PD(
        "net_virt_tx",
        "network_virt_tx.elf",
        priority=100,
        budget=20000,
    )
    net_virt_rx = PD("net_virt_rx", "network_virt_rx.elf", priority=99)
    net_system = Sddf.Net(
        sdf, ethernet_node, ethernet_driver, net_virt_tx, net_virt_rx
    )
    net_copier = PD(
        "net_copier", "network_copy.elf", priority=98, budget=20000
    )

    unikernel = create_unikernel("unikraft")

    serial_system.add_client(unikernel)
    timer_system.add_client(unikernel)
    net_system.add_client_with_copier(unikernel, net_copier)

    pds = [
        serial_driver,
        serial_virt_tx,
        serial_virt_rx,
        timer_driver,
        ethernet_driver,
        net_virt_tx,
        net_virt_rx,
        net_copier,
        unikernel,
    ]
    for pd in pds:
        sdf.add_pd(pd)

    assert serial_system.connect()
    assert serial_system.serialise_config(output_dir)
    assert timer_system.connect()
    assert timer_system.serialise_config(output_dir)
    assert net_system.connect()
    assert net_system.serialise_config(output_dir)

    with open(f"{output_dir}/{sdf_path}", "w+") as f:
        f.write(sdf.render())


def load_boards(sddf_root: str):
    meta_dir = Path(sddf_root).resolve() / "tools" / "meta"
    sys.path.insert(0, str(meta_dir))
    board_mod = importlib.import_module("board")
    BOARDS = getattr(board_mod, "BOARDS")
    return BOARDS


if __name__ == "__main__":
    board_parser = argparse.ArgumentParser(add_help=False)
    board_parser.add_argument("--sddf", required=True)
    board_args, _ = board_parser.parse_known_args()
    sddf = Sddf(board_args.sddf)
    BOARDS = load_boards(board_args.sddf)
    parser = argparse.ArgumentParser(parents=[board_parser])
    parser.add_argument("--dtb", required=False)
    parser.add_argument("--board", required=True, choices=[b.name for b in BOARDS])
    parser.add_argument("--output", required=True)
    parser.add_argument("--sdf", required=True)
    parser.add_argument("--objcopy", required=True)

    args = parser.parse_args()

    board = next(filter(lambda b: b.name == args.board, BOARDS))

    sdf = SDF(board.arch, board.paddr_top)

    dtb = None
    if board.arch != SystemDescription.Arch.X86_64:
        with open(args.dtb, "rb") as f:
            dtb = DeviceTree(f.read())

    generate(args.sdf, args.output, dtb)
