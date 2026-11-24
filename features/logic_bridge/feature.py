"""Replace the logic bridge's repeated visited-list search with a bitmap."""

import json
from pathlib import Path
import struct

from patch_image import near_jump


BROADCAST_CALL = 0x78FAFF
BROADCAST_CALL_SIGNATURE = bytes.fromhex("E8 0C 00 00 00")
VISITED_CHECK = 0x78FD89
VISITED_CHECK_SIGNATURE = bytes.fromhex("33 C9 85 F6 7E 21")
SYMBOLS = {
    "Game": 0xD57900,
    "BroadcastOutput": 0x78FB10,
    "NativeVisitedScan": 0x78FD8F,
    "NativeNotVisited": 0x78FDB0,
    "NativeAlreadyVisited": 0x78FEF4,
    "GetProcessHeapImport": 0xA45550,
    "HeapAllocImport": 0xA455F0,
    "HeapFreeImport": 0xA455E8,
}


def apply(image):
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]

    def link(origin):
        linked = bytearray(code)
        for offset, adjustment, symbol in payload["relocations"]:
            struct.pack_into("<i", linked, offset, SYMBOLS[symbol] - origin - offset - 4 - adjustment)
        return linked

    base = image.add_code(link)
    ordered_entries = sorted(procedures.values()) + [len(code)]
    ends = dict(zip(ordered_entries, ordered_entries[1:]))
    release = base + procedures["FreeVisitedBitmapOnUnwind"]

    # The wrapper uses a fixed 0x48-byte frame, with a termination handler.
    wrapper = procedures["BroadcastWithVisitedBitmap"]
    wrapper_unwind = bytes.fromhex("11 04 01 00 04 82 00 00") + struct.pack("<I", release)
    image.add_runtime_function(base + wrapper, base + ends[wrapper], unwind=wrapper_unwind)

    # The handler and the initializer both reserve 0x28 bytes of stack.
    helper_unwind = bytes.fromhex("01 04 01 00 04 42 00 00")
    for helper in ("FreeVisitedBitmapOnUnwind", "InitializeVisitedBitmap"):
        entry = procedures[helper]
        image.add_runtime_function(base + entry, base + ends[entry], unwind=helper_unwind)

    # The inline check runs on the stock BroadcastOutput frame.
    check = procedures["CheckVisited"]
    image.add_runtime_function(base + check, base + ends[check], unwind_from=VISITED_CHECK)
    image.patch(
        BROADCAST_CALL, BROADCAST_CALL_SIGNATURE,
        b"\xe8" + struct.pack("<i", base + wrapper - BROADCAST_CALL - 5),
    )
    image.patch(
        VISITED_CHECK, VISITED_CHECK_SIGNATURE,
        near_jump(VISITED_CHECK, base + check).ljust(len(VISITED_CHECK_SIGNATURE), b"\x90"),
    )
