"""Link the native old-door packing helper shared by door and wall jobs."""

import json
from pathlib import Path
import struct


SYMBOLS = {
    "ResolveObjectHandle": 0x7BADC0,
    "GetWorldCell": 0x17FF00,
    "GetCellMaterial": 0x7B1CB0,
    "CreateDismantledItem": 0x608780,
    "RotateDismantledItem": 0x11FDA0,
    "DismantledRotation": 0xB1B378,
    "RemoveWorldObject": 0x7BAC70,
}


def apply(image) -> int:
    payload = json.loads(Path(__file__).with_name("recovery_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])

    def link(base: int) -> bytes:
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            end = base + offset + 4 + adjustment
            struct.pack_into("<i", linked, offset, SYMBOLS[name] - end)
        return bytes(linked)

    base = image.add_code(link)
    recovery = base + payload["procedures"]["RecoverOldDoor"]
    # Four-byte sub rsp, 78h, UWOP_ALLOC_SMALL.
    image.add_runtime_function(recovery, base + len(code), unwind=bytes((1, 4, 1, 0, 4, 0xE2, 0, 0)))
    return recovery
