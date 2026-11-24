"""Compile and export freestanding Win64 code and its unwind records."""

import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess


HERE = Path(__file__).resolve().parent


def export(data, entry_points=("WorldStep", "TryCommit")):
    machine, count, _, symbols_at, symbol_count, optional, _ = struct.unpack_from("<HHIIIHH", data)
    if machine != 0x8664 or optional or not count:
        raise ValueError("Expected a regular Windows x64 COFF object")
    strings = symbols_at + symbol_count * 18

    def string(offset):
        start = strings + offset
        return data[start:data.index(b"\0", start)].decode("ascii")

    sections = {}
    for index in range(count):
        raw, _, _, size, start, relocs, _, number, _, flags = struct.unpack_from("<8sIIIIIIHHI", data, 20 + 40*index)
        name = raw.rstrip(b"\0").decode("ascii")
        if name.startswith("/"):
            name = string(int(name[1:]))
        alignment_code = (flags >> 20) & 15
        alignment = 1 << max(alignment_code-1, 0)
        relocations = [struct.unpack_from("<IIH", data, relocs + i*10) for i in range(number)]
        sections[index+1] = (name, data[start:start+size], alignment, relocations)

    symbols = {}
    index = 0
    while index < symbol_count:
        raw, value, section, _, storage, auxiliary = struct.unpack_from("<8sIhHBB", data, symbols_at+index*18)
        label = string(struct.unpack_from("<I", raw, 4)[0]) if raw.startswith(b"\0\0\0\0") else raw.rstrip(b"\0").decode("ascii")
        symbols[index] = (label, value, section, storage)
        index += 1 + auxiliary

    blob = bytearray()
    offsets = {}
    for section, (name, raw, alignment, _) in sections.items():
        if name.startswith((".text", ".rdata")):
            padding = (-len(blob)) % alignment
            blob.extend(b"\xcc" * padding)
            offsets[section] = len(blob)
            blob.extend(raw)
        elif raw and not name.startswith((".pdata", ".xdata", ".drectve", ".llvm_addrsig", ".debug")):
            raise ValueError(f"Unexpected emitted data section {name}")

    fixups = []
    for section, offset in offsets.items():
        _, raw, _, relocations = sections[section]
        for address, symbol, kind in relocations:
            if not 4 <= kind <= 9:
                raise ValueError(f"Unexpected executable relocation {kind:#x}")
            label, value, target, _ = symbols[symbol]
            addend, = struct.unpack_from("<i", raw, address)
            destination = offsets[target] + value + addend if target else label
            fixups.append([offset + address, kind - 4, destination, addend if not target else 0])

    exports = {label: offsets[section]+value for label, value, section, storage in symbols.values()
               if storage == 2 and section in offsets and label in entry_points}
    if set(exports) != set(entry_points):
        raise ValueError("Native entry points are missing")

    runtime = []
    for name, raw, _, relocations in sections.values():
        if not name.startswith(".pdata"):
            continue
        if len(raw) % 12 or len(relocations) * 4 != len(raw):
            raise ValueError("Invalid native runtime-function table")
        resolved = {}
        for address, symbol, kind in relocations:
            if kind != 3 or address % 4 or address in resolved:
                raise ValueError("Unexpected runtime-function relocation")
            _, value, section, _ = symbols[symbol]
            addend, = struct.unpack_from("<I", raw, address)
            resolved[address] = (section, value+addend)
        for i in range(0, len(raw), 12):
            begin, end, unwind = [resolved[i+offset] for offset in (0, 4, 8)]
            if begin[0] != end[0] or begin[0] not in offsets or begin[1] >= end[1]:
                raise ValueError("Invalid native code range in unwind data")
            unwind_name, unwind_data, _, unwind_relocs = sections[unwind[0]]
            at = unwind[1]
            if not unwind_name.startswith(".xdata") or unwind_relocs or unwind_data[at] != 1:
                raise ValueError("Expected plain x64 UNWIND_INFO without handlers")
            size = (4 + 2*unwind_data[at+2] + 3) & ~3
            raw_unwind = unwind_data[at:at+size]
            if len(raw_unwind) != size:
                raise ValueError("Truncated native unwind info")
            runtime.append([offsets[begin[0]] + begin[1], offsets[end[0]] + end[1], raw_unwind.hex()])
    return {"code": blob.hex(), "relocations": fixups, "procedures": exports, "runtime": runtime}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--object", required=True, type=Path)
    parser.add_argument("--source", default=HERE / "bridge_worker.c", type=Path)
    parser.add_argument("--output", default=HERE / "thunks.json", type=Path)
    args = parser.parse_args()
    compiler = shutil.which(args.zig)
    if compiler is None:
        raise SystemExit("Zig C compiler not found")
    subprocess.run([compiler, "cc", "-target", "x86_64-windows-msvc", "-O2", "-ffreestanding",
                    "-fno-builtin", "-fno-stack-protector", "-fno-function-sections", "-fno-data-sections",
                    "-funwind-tables", "-g0", "-Werror", "-c", str(args.source.resolve()), "-o", str(args.object.resolve())], check=True)
    args.output.write_text(json.dumps(export(args.object.read_bytes()), indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
