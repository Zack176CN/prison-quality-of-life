"""Queue native vegetation clearance before accepted wall and small-door plans."""

from __future__ import annotations

import json
import struct
from pathlib import Path

from patch_image import near_jump


HOOKS = (
    (0x4D0A48, "F6 81 88 00 00 00 01", "AllowTreeInWallPlan", True),
    (0x4C5D38, "41 83 3E FF 0F 84 91 00 00 00", "AllowTreeInDoorPlan", True),
    (0x4DBEE0, "8B 02 83 C0 0A", "DispatchClearance", False),
    (0x4D2E30, "48 8B 05 C9 4A 88 00", "CancelPendingClearance", True),
)

SYMBOLS = {
    "Game": 0xD57900,
    "ObjectDefCount": 0xE085CC,
    "ObjectDefTable": 0xDECCA0,
    "MaterialValidatorReturn": 0x4C1D73,
    "OrdinaryWallValidatorReturn": 0x4C07AB,
    "ReadStockWallFlags": 0x4D0A4F,
    "ContinueWallObjectLoop": 0x4D0A78,
    "ContinueDoorObjectLoop": 0x4C5F87,
    "CheckNativeMoveSlot": 0x4C5D42,
    "CheckNativeDoorCollisions": 0x4C5DD3,
    "ContinueCommandDispatch": 0x4DBEE5,
    "ContinuePendingCancellation": 0x4D2E37,
    "FinishPendingCancellation": 0x4D2E55,
    "IsWallMaterial": 0x60A800,
    "GetObjectFootprint": 0x7DA6B0,
    "ResolveObjectHandle": 0x7BADC0,
    "IsObjectCarried": 0x7DF1C0,
    "FindObjectJob": 0x795210,
    "ScheduleDismantle": 0x79CC90,
    "ScheduleStumpRemoval": 0x79DA70,
    "CancelWorkBatch": 0x7995F0,
    "CancelConstructionBatch": 0x4CE230,
}

STACK_SIZES = {
    "CancelMatchedBatch": 0x38,
    "ClearBeforeDispatch": 0x68,
    "ClearTileVegetation": 0x68,
}


def apply(image) -> None:
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]

    def link(base: int) -> bytes:
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            displacement_end = base + offset + 4 + adjustment
            struct.pack_into("<i", linked, offset, SYMBOLS[name] - displacement_end)
        return bytes(linked)

    base = image.add_code(link)
    starts = sorted(procedures.values())
    ends = dict(zip(starts, starts[1:] + [len(code)]))
    for site, signature, procedure, chain_original_frame in HOOKS:
        start = procedures[procedure]
        destination = base + start
        expected = bytes.fromhex(signature)
        image.patch(site, expected, near_jump(site, destination).ljust(len(expected), b"\x90"))
        if chain_original_frame:
            image.add_runtime_function(destination, base + ends[start], unwind_from=site)

    for procedure, stack_size in STACK_SIZES.items():
        start = procedures[procedure]
        # The Win64 prologue is four bytes of sub rsp, imm8.
        allocation = ((stack_size - 8) // 8 << 4) | 2
        unwind = bytes((1, 4, 1, 0, 4, allocation, 0, 0))
        image.add_runtime_function(base + start, base + ends[start], unwind=unwind)
