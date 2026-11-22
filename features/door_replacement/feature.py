"""Let the ordinary object build tool directly replace one- and two-cell doors."""

from __future__ import annotations

import json
import struct
from pathlib import Path

from features.door_replacement.recovery import apply as add_recovery


HOOKS = (
    # RVA, signature, named thunk, call rather than jump
    (0x1F1428, "E8 63 90 2D 00", "CommitDoorWithReplacement", True),
    (0x1F2D65, "0F B6 E8 80 7F 48 00", "CaptureClick", False),
    (0x4CA636, "E8 B5 5A FF FF", "ValidateWithReplacement", True),
    (0x4C5D28, "48 8B C8 E8 90 94 31 00", "ExcludeReplacedDoor", False),
    (0x7AA001, "0F 84 38 21 00 00", "PreserveDoorOnBuildFailure", False),
    (0x7AC1C3, "E8 A8 EA 00 00", "RecoverDoorJob", True),
)

SYMBOLS = {
    "InputManager": 0xD57648,
    "Game": 0xD57900,
    "ObjectDefTable": 0xDECCA0,
    "ObjectDefCount": 0xE085CC,
    "ResolveObjectHandle": 0x7BADC0,
    "GetObjectFootprint": 0x7DA6B0,
    "ValidateConstruction": 0x4C00F0,
    "CommitConstruction": 0x4CA490,
    "IsObjectCarried": 0x7DF1C0,
    "ResumeObjectTool": 0x1F2D6C,
    "ResumeCollisionCheck": 0x4C5D30,
    "NextObject": 0x4C5F87,
    "FinishNewObject": 0x7AA007,
    "CompleteOriginalJob": 0x7AC13F,
    "LeaveOriginalJob": 0x7AC1CF,
    "RemoveWorldObject": 0x7BAC70,
}

STATE_FIELDS = (
    "PendingCell", "PendingType", "PendingId", "PendingOldAnchor", "PendingOldSize", "IgnoreCommand", "IgnoreId",
)

STACK_SIZES = {
    "CommitDoorWithReplacement": 0x48,
    "CaptureDoorInFootprint": 0x68,
    "CaptureExactDoor": 0x78,
    "ValidateScoped": 0x78,
    "RecoverDoorJob": 0x38,
}


def apply(image) -> int:
    image_path = Path(__file__).with_name("thunks.json")
    payload = json.loads(image_path.read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]
    recovery = add_recovery(image)
    state = image.add_zeroed_state(len(STATE_FIELDS) * 8)
    symbols = SYMBOLS | {"RecoverOldDoor": recovery}
    symbols.update({name: state + index * 8 for index, name in enumerate(STATE_FIELDS)})

    def link(base: int) -> bytes:
        linked = bytearray(code)
        for offset, after_displacement, name in payload["relocations"]:
            displacement_end = base + offset + 4 + after_displacement
            struct.pack_into("<i", linked, offset, symbols[name] - displacement_end)
        return bytes(linked)

    base = image.add_code(link)
    ordered = sorted(procedures.items(), key=lambda pair: pair[1])
    limits = {
        name: ordered[index + 1][1] if index + 1 < len(ordered) else len(code)
        for index, (name, _) in enumerate(ordered)
    }
    for rva, signature, name, is_call in HOOKS:
        expected = bytes.fromhex(signature)
        destination = base + procedures[name]
        opcode = b"\xe8" if is_call else b"\xe9"
        instruction = opcode + struct.pack("<i", destination - rva - 5)
        image.patch(rva, expected, instruction.ljust(len(expected), b"\x90"))
        if not is_call:
            image.add_runtime_function(destination, base + limits[name], unwind_from=rva)

    for name, stack_size in STACK_SIZES.items():
        allocation = ((stack_size - 8) // 8 << 4) | 2
        unwind = bytes((1, 4, 1, 0, 4, allocation, 0, 0))
        image.add_runtime_function(base + procedures[name], base + limits[name], unwind=unwind)
    return recovery
