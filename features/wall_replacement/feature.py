"""Use native wall selection and construction to replace one- and two-cell doors."""

from __future__ import annotations

import json
import struct
from pathlib import Path

from features.door_replacement.recovery import apply as add_recovery


HOOKS = (
    (0x1F09C8, "E8 63 B7 2C 00", "PreviewWall", True),
    (0x1F0BA4, "E8 E7 98 2D 00", "CommitWall", True),
    (0x4DBC87, "E8 64 44 FE FF", "RevalidateWallPreview", True),
    (0x4D0A72, "41 83 F8 3D 75 0F", "ExcludeWallDoor", False),
    (0x79A05B, "48 8B D3 49 8B CD", "TagMaterialJob", False),
    (0x7A9D9B, "E8 A0 B9 E5 FF", "CompleteWall", True),
)

SYMBOLS = {
    "Game": 0xD57900,
    "InputManager": 0xD57648,
    "ObjectDefCount": 0xE085CC,
    "ObjectDefTable": 0xDECCA0,
    "BuildWall": 0x4BC130,
    "ResolveWorldObject": 0x7BADC0,
    "ObjectFootprint": 0x7DA610,
    "HalfCell": 0xB1B408,
    "IsWallMaterial": 0x60A800,
    "ValidateConstruction": 0x4C00F0,
    "CommitConstruction": 0x4CA490,
    "MaterialValidatorReturn": 0x4C1D73,
    "OrdinaryWallValidatorReturn": 0x4C07AB,
    "ClearToBuild": 0x4D0A87,
    "AdvanceBlocker": 0x4D0A78,
    "MaterialCaller": 0x4CD330,
    "InsertMaterialJob": 0x79A061,
    "ApplyMaterial": 0x605740,
}

STACK_SIZES = {
    "WallDoorCoversCell": 0x58,
    "GetWallDoorAt": 0x48,
    "PreviewWall": 0x68,
    "RevalidateWallPreview": 0x48,
    "CommitWall": 0x48,
    "MatchWallDoor": 0x58,
    "CompleteWall": 0x68,
}


def apply(image, recovery: int | None = None) -> None:
    """Use the door feature's recovery RVA, or link it for standalone use."""
    if recovery is None:
        recovery = add_recovery(image)
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]
    symbols = SYMBOLS | {"ScopedWallWorld": image.add_zeroed_state(8), "RecoverOldDoor": recovery}

    def link(base: int) -> bytes:
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            displacement_end = base + offset + 4 + adjustment
            struct.pack_into("<i", linked, offset, symbols[name] - displacement_end)
        return bytes(linked)

    base = image.add_code(link)
    starts = sorted(procedures.values())
    ends = dict(zip(starts, starts[1:] + [len(code)]))
    for site, signature, procedure, is_call in HOOKS:
        start = procedures[procedure]
        destination = base + start
        expected = bytes.fromhex(signature)
        instruction = bytes((0xE8 if is_call else 0xE9,)) + struct.pack("<i", destination - site - 5)
        image.patch(site, expected, instruction.ljust(len(expected), b"\x90"))
        if not is_call:
            image.add_runtime_function(destination, base + ends[start], unwind_from=site)

    for procedure, stack_size in STACK_SIZES.items():
        start = procedures[procedure]
        # Every standalone wrapper has a four-byte sub rsp, imm8 prologue.
        allocation = ((stack_size - 8) // 8 << 4) | 2
        unwind = bytes((1, 4, 1, 0, 4, allocation, 0, 0))
        image.add_runtime_function(base + start, base + ends[start], unwind=unwind)
