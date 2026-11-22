"""Serve road dispatch requests from the normal native logistics tick."""

from __future__ import annotations

import json
import struct
from pathlib import Path

from patch_image import PatchImage, near_jump
from features.long_truck_fleet.capacity import MODE_HOOK


UPDATE_CALL = 0x733FF3
BACKLOG_CAPTURE = 0x7347EB
WORLD_CONSTRUCTOR = 0x7B3650
STATE_SIZE = 0x60
SYMBOLS = {
    "Game": 0xD57900,
    "RunNativeUpdate": 0x7352E0,
    "CheckRoadEntrance": 0x731590,
    "CheckNativeBacklog": 0x734500,
    "SpawnRoadTruck": 0x7316E0,
    "ContinueNativeBacklog": 0x7347F3,
    "NativeWastePermission": 0x739900,
    "NativeExportsPermission": 0x739970,
    "ContinueWorldConstruction": WORLD_CONSTRUCTOR + 5,
    "MaterialDefCount": 0xDECCEC,
    "MaterialDefTable": 0xDECC90,
    "LongTruckMode": MODE_HOOK,
}


def apply(image: PatchImage, console_kind_rva: int | None = None) -> dict[str, int]:
    """Install scheduler hooks and return native entry RVAs for a UI feature."""
    state = image.add_zeroed_state(STATE_SIZE)
    if console_kind_rva is None:
        console_kind_rva = state + 0x3C
    symbols = {
        **SYMBOLS,
        "DispatchState": state,
        "DispatchObjectKind": console_kind_rva,
        "PreferredTruckCapacity": state + 0x40,
        "FleetWorldEpoch": state + 0x44,
    }
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])

    def link(origin: int) -> bytes:
        linked = bytearray(code)
        for offset, adjustment, symbol in payload["relocations"]:
            next_instruction = origin + offset + 4 + adjustment
            struct.pack_into("<i", linked, offset, symbols[symbol] - next_instruction)
        return bytes(linked)

    origin = image.add_code(link)
    entries = {procedure: origin + offset for procedure, offset in payload["procedures"].items()}
    visit = entries["DispatchNativeUpdate"]
    collect = entries["CollectDispatchBacklog"]
    update_call = b"\xe8" + struct.pack("<i", visit - UPDATE_CALL - 5)
    image.patch(UPDATE_CALL, bytes.fromhex("E8 E8 12 00 00"), update_call)
    expected_capture = bytes.fromhex("48 FF C3 48 89 5C 24 20")
    image.patch(BACKLOG_CAPTURE, expected_capture, near_jump(BACKLOG_CAPTURE, collect).ljust(8, b"\x90"))
    reset = entries["ResetDispatchForWorldConstruction"]
    image.patch(WORLD_CONSTRUCTOR, bytes.fromhex("48 89 4C 24 08"), near_jump(WORLD_CONSTRUCTOR, reset))
    refresh = entries["RefreshDispatchBacklog"]
    image.add_runtime_function(visit, refresh, unwind=bytes.fromhex("01 04 01 00 04 A2 00 00"))
    image.add_runtime_function(refresh, collect, unwind=bytes.fromhex("01 04 01 00 04 42 00 00"))
    image.add_runtime_function(collect, entries["HasNativeRoad"], unwind_from=BACKLOG_CAPTURE)
    return {
        **entries,
        "DispatchState": state,
        "DispatchObjectKind": console_kind_rva,
        "LongTruckMode": MODE_HOOK,
        "PreferredTruckCapacity": state + 0x40,
        "FleetWorldEpoch": state + 0x44,
    }
