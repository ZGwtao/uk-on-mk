# Copyright 2025, UNSW
# SPDX-License-Identifier: BSD-2-Clause
import argparse
import os
import shutil
from pathlib import Path

from acacia import DeviceTreeBlob, ProtectionDomain, System
from acacia_sddf import BOARDS, sDDFEthernet, sDDFTimer
from acacia_sddf.net import sDDFMAC


def make_config_structs_with_c_types(sdf: System, output_dir: str):
    """Give Acacia C type layouts while keeping the Rust ELF as the PD image."""
    config_types = Path(output_dir) / "dummy_config_types.o"
    client_elf = Path(output_dir) / "demikernel.elf"
    saved_elf = client_elf.with_suffix(".rust.elf")

    # Acacia reads DWARF from the configured PD image path. The Rust ELF has
    # the config sections, but its DWARF cannot be parsed by Acacia.
    os.replace(client_elf, saved_elf)
    try:
        shutil.copyfile(config_types, client_elf)
        sdf.make_config_structs(build_dir=output_dir)
    finally:
        # The generated blobs are inserted into the real Rust ELF by the Makefile.
        os.replace(saved_elf, client_elf)


def generate(sdf_file: str, output_dir: str):
    client = ProtectionDomain(
        sdf, "demikernel", "demikernel.elf", priority=50,
        stack_size=0x10000,
    )
    copier = ProtectionDomain(sdf, "network_copy", "network_copy.elf", priority=98)

    timer = sDDFTimer(sdf, board.timer.compatible, board.timer.node_path)
    timer.add_client(client)

    ethernet = sDDFEthernet(
        sdf, board.ethernet.compatible, board.ethernet.node_path,
        driver_prio=101, virt_tx_prio=100, virt_rx_prio=99,
    )
    ethernet.add_client(client, copier=copier, mac_addr=sDDFMAC([2, 0, 0, 0, 0, 0x15]))

    make_config_structs_with_c_types(sdf, output_dir)

    out_file = f"{output_dir}/{sdf_file}"
    sdf.write_xml_file(out_file)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dtb", required=False)
    parser.add_argument("--sddf", required=True)
    parser.add_argument("--board", required=True, choices=[b.name for b in BOARDS])
    parser.add_argument("--output", required=True)
    parser.add_argument("--sdf", required=True)

    args = parser.parse_args()

    board = next((b for b in BOARDS if b.name == args.board), None)
    if board is None:
        parser.error(f"unknown board: {args.board}")

    sdf = System(board.arch, board.paddr_top, DeviceTreeBlob(args.dtb))

    generate(args.sdf, args.output)
