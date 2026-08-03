# Copyright 2026, UNSW
# SPDX-License-Identifier: BSD-2-Clause

import sys
import argparse
import importlib
from pathlib import Path
from sdfgen import SystemDescription, Sddf, DeviceTree, LionsOs
from importlib.metadata import version

assert version("sdfgen").split(".")[1] == "33", "Unexpected sdfgen version"

SDF = SystemDescription
PD = SDF.ProtectionDomain
MR = SDF.MemoryRegion
MAP = SDF.Map


def create_unikernel(name: str):
    unikernel = PD(f"{name}", f"{name}.elf", priority=50, stack_size=0x10000)
    uk_heap = MR(sdf, f"{name}/uk_heap", 0x1000000)
    sdf.add_mr(uk_heap)
    unikernel.add_map(MAP(uk_heap, 0xfff50000, perms="rw", cached="true"))
    return unikernel


def generate(sdf_path: str, output_dir: str, dtb: DeviceTree):
    serial_node = dtb.node(board.serial)
    assert serial_node is not None
    timer_node = dtb.node(board.timer)
    assert timer_node is not None
    ethernet_node = dtb.node(board.ethernet)
    assert ethernet_node is not None

    timer_driver = PD("timer_driver", "timer_driver.elf", priority=254)
    timer_system = Sddf.Timer(sdf, timer_node, timer_driver)

    serial_driver = PD("serial_driver", "serial_driver.elf", priority=100)
    serial_virt_tx = PD("serial_virt_tx", "serial_virt_tx.elf", priority=99)
    serial_virt_rx = PD("serial_virt_rx", "serial_virt_rx.elf", priority=99)
    serial_system = Sddf.Serial(sdf, serial_node, serial_driver,
                                serial_virt_tx, virt_rx=serial_virt_rx)


    ethernet_driver = PD(
        "ethernet_driver",
        "eth_driver.elf",
        priority=101,
        budget=100,
        period=400,
    )
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
    parser.add_argument("--dtb", required=True)
    parser.add_argument("--board", required=True, choices=[b.name for b in BOARDS])
    parser.add_argument("--output", required=True)
    parser.add_argument("--sdf", required=True)
    parser.add_argument("--objcopy", required=True)

    args = parser.parse_args()

    board = next(filter(lambda b: b.name == args.board, BOARDS))

    sdf = SDF(board.arch, board.paddr_top)

    with open(args.dtb, "rb") as f:
        dtb = DeviceTree(f.read())

    generate(args.sdf, args.output, dtb)
