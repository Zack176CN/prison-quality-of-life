"""Export the x64 COFF .text and RIP-relative relocations produced by ml64."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


def export(data: bytes) -> dict:
    machine, sections, _, symbol_table, symbol_count, optional_header, _ = struct.unpack_from("<HHIIIHH", data)
    if machine != 0x8664 or not sections or optional_header:
        raise ValueError("Expected a Microsoft x64 COFF object")
    section_index, raw_size, raw_at, relocs_at, reloc_count = next(
        (index + 1, raw_size, raw_at, relocs_at, reloc_count)
        for index in range(sections)
        for name, _, _, raw_size, raw_at, relocs_at, _, reloc_count, _, _ in (
            struct.unpack_from("<8sIIIIIIHHI", data, 20 + index * 40),
        )
        if name.startswith(b".text")
    )
    code = data[raw_at:raw_at + raw_size]
    string_table = symbol_table + symbol_count * 18

    symbols = {}
    procedures = {}
    index = 0
    while index < symbol_count:
        name, address, section, _, visibility, auxiliary_count = struct.unpack_from(
            "<8sIhHBB", data, symbol_table + index * 18
        )
        if name[:4] == b"\0" * 4:
            start = string_table + struct.unpack_from("<I", name, 4)[0]
            label = data[start:data.index(b"\0", start)].decode("ascii")
        else:
            label = name.rstrip(b"\0").decode("ascii")
        symbols[index] = (label, section)
        if visibility == 2 and section == section_index:
            procedures[label] = address
        index += 1 + auxiliary_count

    relocations = []
    for index in range(reloc_count):
        offset, symbol, relocation_type = struct.unpack_from("<IIH", data, relocs_at + index * 10)
        label, section = symbols[symbol]
        if section != 0 or not 4 <= relocation_type <= 9:
            raise ValueError(f"Unsupported relocation for {label}")
        if struct.unpack_from("<i", code, offset)[0] != 0:
            raise ValueError(f"Unexpected addend for {label}")
        relocations.append([offset, relocation_type - 4, label])
    return {"code": code.hex(), "procedures": procedures, "relocations": relocations}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object_file", type=Path)
    arg = parser.parse_args()
    dest = Path(__file__).with_name("thunks.json")
    dest.write_text(json.dumps(export(arg.object_file.read_bytes()), indent=2) + "\n", encoding="utf-8")
