# SPDX-License-Identifier: BSD-2-Clause

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from acacia import DeviceTreeBlob, Map, MemoryRegion, ProtectionDomain, System
from acacia_sddf import sDDFBlk, sDDFSerial, sDDFTimer


def set_solo5_heap_size(sdf_file: Path):
    # Acacia's Map exposes setvar_vaddr, but not setvar_size. The Solo5
    # Microkit binding needs both symbols to initialise its heap.
    tree = ET.parse(sdf_file)
    heap_map = tree.find(".//map[@mr='solo5/heap']")
    if heap_map is None:
        raise RuntimeError("Solo5 heap map missing from system description")
    heap_map.set("setvar_size", "microkit_heap_size")
    tree.write(sdf_file, encoding="unicode")


def generate(sdf_file, output_dir, board, dtb, mode):
    sdf = System(board.arch, board.paddr_top, DeviceTreeBlob(dtb))
    client = ProtectionDomain(sdf, "client", "client.elf", priority=50,
                              stack_size=0x10000)

    if mode == "solo5":
        heap = MemoryRegion(sdf, "solo5/heap", 0x4000000)
        client.add_map(Map(heap, 0x200000000, "rw",
                           setvar_vaddr="microkit_heap_base"))

    serial = sDDFSerial(
        sdf, board.serial.compatible, board.serial.node_path,
        driver_prio=100, virt_tx_prio=99, allow_rx=True,
        virt_rx_prio=99, enable_color=False,
        baud_rate=board.baud_rate or 115200,
    )
    serial.add_client(client)

    timer = sDDFTimer(sdf, board.timer.compatible, board.timer.node_path)
    timer.add_client(client)

    blk = sDDFBlk(sdf, board.blk.compatible, board.blk.node_path, 200, 199)
    blk.add_client(client, board.partition)
    if board.name == "maaxboard":
        # The MaaXBoard block driver uses the timer for request timeouts.
        timer.add_client(blk.driver)

    sdf.make_config_structs()

    out_file = Path(output_dir) / sdf_file
    sdf.write_xml_file(out_file)

    if mode == "solo5":
        set_solo5_heap_size(out_file)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sddf", required=True)
    parser.add_argument("--board", required=True)
    parser.add_argument("--dtb", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--sdf", required=True)
    parser.add_argument("--mode", choices=("native", "solo5"), required=True)
    args = parser.parse_args()

    sys.path.insert(0, str(Path(args.sddf).resolve()))
    from acacia_sddf import BOARDS

    board = next((b for b in BOARDS if b.name == args.board), None)
    if board is None:
        parser.error(f"unknown board: {args.board}")

    generate(args.sdf, args.output, board, args.dtb, args.mode)
