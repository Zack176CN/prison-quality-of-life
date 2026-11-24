"""Store dispatcher preferences in the stock prison save's root properties."""

import json
import struct
from pathlib import Path


SAVE_CALL = 0x7CA989
LOAD_CALL = 0x7CC381
NATIVE = {
    "WriteWorldProperties": 0x1C3910,
    "ReadWorldProperties": 0x1C3890,
    "InsertSaveProperty": 0x1610E0,
    "FindSaveProperty": 0x161040,
}
SAVE_KEY = b"QoLDispatchV1"
SMALL_ALLOCATION_UNWIND = bytes.fromhex("0104010004420000")


def apply(image, scheduler):
    payload = json.loads(Path(__file__).with_name("persistence_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    entries = payload["procedures"]
    key = struct.pack("<16sQQ", SAVE_KEY, len(SAVE_KEY), 15)

    def link(origin):
        linked = bytearray(code)
        symbols = {**NATIVE, **scheduler, "DispatchSaveKey": origin + len(code)}
        for offset, adjustment, symbol in payload["relocations"]:
            struct.pack_into("<i", linked, offset, symbols[symbol] - origin - offset - 4 - adjustment)
        return linked + key

    origin = image.add_code(link)
    hooks = (
        (SAVE_CALL, "WriteWorldProperties", "SaveDispatchPreferences"),
        (LOAD_CALL, "ReadWorldProperties", "LoadDispatchPreferences"),
    )
    save = origin + entries["SaveDispatchPreferences"]
    load = origin + entries["LoadDispatchPreferences"]
    image.add_runtime_function(save, load, unwind=SMALL_ALLOCATION_UNWIND)
    image.add_runtime_function(load, origin + len(code), unwind=SMALL_ALLOCATION_UNWIND)
    for site, original, replacement in hooks:
        before = b"\xe8" + struct.pack("<i", NATIVE[original] - site - 5)
        after = b"\xe8" + struct.pack("<i", origin + entries[replacement] - site - 5)
        image.patch(site, before, after)
