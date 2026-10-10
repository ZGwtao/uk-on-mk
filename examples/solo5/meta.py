# SPDX-License-Identifier: BSD-2-Clause

import argparse
import importlib
import sys
from pathlib import Path

from sdfgen import DeviceTree, Sddf, SystemDescription


SDF = SystemDescription
SOLO5_HEAP_BASE = 0x200000000
SOLO5_HEAP_SIZE = 0x4000000


def generate(
    sdf_path: str, output_dir: str, board, dtb: DeviceTree, cmdline: str
) -> None:
    sdf = SDF(board.arch, board.paddr_top)
    serial_node = dtb.node(board.serial)
    if serial_node is None:
        raise ValueError(f"serial device '{board.serial}' is absent from the DTB")

    serial_driver = SDF.ProtectionDomain(
        "serial_driver", "serial_driver.elf", priority=100
    )
    serial_virt_tx = SDF.ProtectionDomain(
        "serial_virt_tx", "serial_virt_tx.elf", priority=99
    )
    serial_virt_rx = SDF.ProtectionDomain(
        "serial_virt_rx", "serial_virt_rx.elf", priority=99
    )
    serial_system = Sddf.Serial(
        sdf, serial_node, serial_driver, serial_virt_tx, virt_rx=serial_virt_rx
    )

    timer_node = dtb.node(board.timer)
    if timer_node is None:
        raise ValueError(f"timer device '{board.timer}' is absent from the DTB")
    timer_driver = SDF.ProtectionDomain(
        "timer_driver", "timer_driver.elf", priority=254
    )
    timer_system = Sddf.Timer(sdf, timer_node, timer_driver)

    ethernet_node = dtb.node(board.ethernet)
    if ethernet_node is None:
        raise ValueError(f"ethernet device '{board.ethernet}' is absent from the DTB")
    ethernet_driver = SDF.ProtectionDomain(
        "ethernet_driver", "eth_driver.elf", priority=101,
        budget=100, period=400
    )
    net_virt_tx = SDF.ProtectionDomain(
        "net_virt_tx", "network_virt_tx.elf", priority=100,
        budget=20000
    )
    net_virt_rx = SDF.ProtectionDomain(
        "net_virt_rx", "network_virt_rx.elf", priority=99
    )
    net_system = Sddf.Net(
        sdf, ethernet_node, ethernet_driver, net_virt_tx, net_virt_rx
    )
    net_copier = SDF.ProtectionDomain(
        "net_copier", "network_copy.elf", priority=98, budget=20000
    )

    blk_node = dtb.node(board.blk)
    if blk_node is None:
        raise ValueError(f"block device '{board.blk}' is absent from the DTB")
    blk_driver = SDF.ProtectionDomain(
        "blk_driver", "blk_driver.elf", priority=200, stack_size=0x2000
    )
    blk_virt = SDF.ProtectionDomain(
        "blk_virt", "blk_virt.elf", priority=199, stack_size=0x2000
    )
    blk_system = Sddf.Blk(sdf, blk_node, blk_driver, blk_virt)

    solo5 = SDF.ProtectionDomain(
        "solo5", "solo5.elf", priority=50, stack_size=0x10000
    )
    # This private region backs both bindings initialization allocations and
    # the heap subsequently handed to the Solo5 application.
    heap = SDF.MemoryRegion(sdf, "solo5/heap", SOLO5_HEAP_SIZE)
    sdf.add_mr(heap)
    solo5.add_map(
        SDF.Map(
            heap,
            SOLO5_HEAP_BASE,
            perms="rw",
            cached=True,
            setvar_vaddr="microkit_heap_base",
            setvar_size="microkit_heap_size",
        )
    )
    serial_system.add_client(solo5)
    timer_system.add_client(solo5)
    net_system.add_client_with_copier(solo5, net_copier)
    blk_system.add_client(solo5, partition=board.partition)

    for pd in (timer_driver, serial_driver, serial_virt_tx, serial_virt_rx,
               ethernet_driver, net_virt_tx, net_virt_rx, net_copier,
               blk_driver, blk_virt, solo5):
        sdf.add_pd(pd)

    assert serial_system.connect()
    assert serial_system.serialise_config(output_dir)
    assert timer_system.connect()
    assert timer_system.serialise_config(output_dir)
    assert net_system.connect()
    assert net_system.serialise_config(output_dir)
    assert blk_system.connect()
    assert blk_system.serialise_config(output_dir)

    cmdline_data = cmdline.encode("utf-8")
    cmdline_size = 8192
    if len(cmdline_data) >= cmdline_size:
        raise ValueError("Solo5 command line must be at most 8191 bytes")
    with open(f"{output_dir}/solo5_cmdline.data", "wb+") as f:
        f.write(cmdline_data)
        f.write(bytes(cmdline_size - len(cmdline_data)))

    with open(f"{output_dir}/{sdf_path}", "w+") as f:
        f.write(sdf.render())


def load_boards(sddf_root: str):
    meta_dir = Path(sddf_root).resolve() / "tools" / "meta"
    sys.path.insert(0, str(meta_dir))
    board_module = importlib.import_module("board")
    return getattr(board_module, "BOARDS")


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
    parser.add_argument("--cmdline", default="")
    args = parser.parse_args()

    board = next(filter(lambda b: b.name == args.board, BOARDS))

    with open(args.dtb, "rb") as f:
        dtb = DeviceTree(f.read())
    generate(args.sdf, args.output, board, dtb, args.cmdline)
