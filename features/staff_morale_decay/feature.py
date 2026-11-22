"""Fade the native staff-death morale penalty using elapsed prison time."""

from __future__ import annotations

import json
import struct
from pathlib import Path


HOOKS = (
    (0x73E633, "660F6E82982700000F5BC0F30F5CD8", "ApplyDeathPenalty", 0xE9),
    (0x7553AA, "FF8110020000", "RecordStaffDeath", 0xE8),
    (0x7CD3F6, "E835BBF8FF", "ResetOnLoad", 0xE8),
)


def apply(image) -> None:
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]
    symbols = {
        "ResumeMorale": 0x73E642,
        "LoadVictory": 0x758F30,
        "TrackedWorld": image.add_zeroed_state(8),
        "ForgivenDeaths": image.add_zeroed_state(4, 4),
        "RecoveryStart": image.add_zeroed_state(8),
    }

    def link(base: int) -> bytes:
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            displacement_end = base + offset + 4 + adjustment
            struct.pack_into("<i", linked, offset, symbols[name] - displacement_end)
        return bytes(linked)

    base = image.add_code(link)
    for site, signature, procedure, opcode in HOOKS:
        expected = bytes.fromhex(signature)
        destination = base + procedures[procedure]
        instruction = bytes((opcode,)) + struct.pack("<i", destination - site - 5)
        image.patch(site, expected, instruction.ljust(len(expected), b"\x90"))

    # Both wrappers have a four-byte sub rsp, 28h prologue (UWOP_ALLOC_SMALL).
    wrapper_unwind = bytes((1, 4, 1, 0, 4, 0x42, 0, 0))
    for start, end in (("ApplyDeathPenalty", "RecordStaffDeath"), ("RecordStaffDeath", "ResetOnLoad")):
        image.add_runtime_function(base + procedures[start], base + procedures[end], unwind=wrapper_unwind)
