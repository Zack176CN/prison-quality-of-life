"""Apply native per-vehicle bounds to supply-truck loading and stopping."""

import json
import struct
from pathlib import Path

from patch_image import near_jump

MODE_HOOK = 0x738171
HOOKS = (
    (MODE_HOOK, "8B 71 7C 49 8D 85 D8 00 00 00", "LoadCapacity", "AfterLoadCapacity"),
    (0x74E83A, "83 F8 08 7D 6D", "CheckGarbageCapacity", "AfterCheckGarbageCapacity"),
    (0x74E8E1, "83 F8 08 0F 8D 16 01 00 00", "CheckExportsCapacity", "AfterCheckExportsCapacity"),
    (0x7DF9CA, "8B 8C 24 88 00 00 00 85 C9 78 0A 41 8B 42 7C FF C8 3B C8 7E 06 41 8B 4A 7C FF C9",
     "SlotSearchLimit", "AfterSlotSearchLimit"),
    (0x7DF686, "39 5F 7C 0F 8E B0 02 00 00", "InitialInsertCheck", "AfterInitialInsertCheck"),
    (0x7DF6AC, "3B 5F 7C 7C DF", "InsertLoopCheck", "AfterInsertLoop"),
    (0x7DF6C9, "44 8B 47 7C 45 85 C0", "GetInsertCapacity", "AfterGetInsertCapacity"),
    (0x7DF704, "44 3B 7F 7C 0F 8D 31 02 00 00", "CheckInsertSlot", "AfterCheckInsertSlot"),
)
NATIVE_BRANCHES = {
    "SkipGarbageStop": 0x74E8AC,
    "SkipExportsStop": 0x74EA00,
    "TryNextInsertSlot": 0x7DF690,
    "RejectInsertSlot": 0x7DF93F,
    "CreateNativeObject": 0x7DAC00,
}
FACTORY_CALL = 0x731703


def prepare(image, dispatch_bindings):
    """Link the shared getter and each exact-size native detour."""
    payload = json.loads(Path(__file__).with_name("capacity_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]
    hooks = [(site, bytes.fromhex(signature), name, resume) for site, signature, name, resume in HOOKS]
    native = {
        **NATIVE_BRANCHES,
        **{resume: site + len(signature) for site, signature, _, resume in hooks},
        "DispatchSpawnReturn": dispatch_bindings["DispatchSpawnReturn"],
        "PreferredTruckCapacity": dispatch_bindings["PreferredTruckCapacity"],
    }

    def link(origin):
        result = bytearray(code)
        for offset, adjustment, symbol in payload["relocations"]:
            displacement = native[symbol] - origin - offset - 4 - adjustment
            struct.pack_into("<i", result, offset, displacement)
        return result

    base = image.add_code(link)
    sorted_entries = sorted(procedures.values()) + [len(code)]
    ends = dict(zip(sorted_entries, sorted_entries[1:]))
    changes = []
    for site, signature, name, _ in hooks:
        start = procedures[name]
        image.add_runtime_function(base + start, base + ends[start], unwind_from=site)
        changes.append((site, signature, near_jump(site, base + start).ljust(len(signature), b"\x90")))
    factory = base + procedures["ConstructSupplyTruck"]
    image.add_runtime_function(factory, base + len(code), unwind=bytes.fromhex("01 04 01 00 04 62 00 00"))
    changes.append((FACTORY_CALL, bytes.fromhex("E8 F8 94 0A 00"), b"\xe8" + struct.pack("<i", factory - FACTORY_CALL - 5)))
    return {"GetTruckCapacity": base + procedures["GetTruckCapacity"]}, changes
