"""Add Pinyin after stock search across the build toolbar's localized lists."""

import json
from pathlib import Path
import struct

from patch_image import near_jump


HERE = Path(__file__).resolve().parent
MATCH_CALLS = (
    (0x20F16A, "E8 41 DB FF FF"),  # Walls
    (0x20F20F, "E8 9C DA FF FF"),  # Doors
    (0x20F7F7, "E8 B4 D4 FF FF"),  # Flooring
    (0x20FDC7, "E8 E4 CE FF FF"),  # Rooms
    (0x2112F0, "E8 BB B9 FF FF"),  # Objects
    (0x211423, "E8 88 B8 FF FF"),  # Alternate objects list
    (0x214207, "E8 A4 8A FF FF"),  # Sandbox object palette
    (0x2154CC, "E8 DF 77 FF FF"),  # Quick builds
)
EDIT_CALLS = (
    (0xF9F14, "E8 27 B2 FF FF"),
    (0xFA0AE, "E8 8D B0 FF FF"),
    (0xFA25C, "E8 DF AE FF FF"),
)
SYMBOLS = {
    "StockToolbarMatch": 0x20CCB0,
    "AssignWideString": 0xF5140,
    "WindowManager": 0xD57638,
    "GetWindowById": 0x1096D0,
    "BuildToolbarVtable": 0xAC4810,
}


def redirect_calls(image, calls, target):
    for site, signature in calls:
        call = b"\xe8" + near_jump(site, target)[1:]
        image.patch(site, bytes.fromhex(signature), call)


def apply(image):
    payload = json.loads((HERE / "thunks.json").read_text(encoding="utf-8"))
    dictionary = (HERE / "pronunciations.bin").read_bytes()
    pronunciation_rva = image.add_code(lambda _: dictionary)
    bindings = {**SYMBOLS, "PinyinDictionary": pronunciation_rva}
    matcher = payload["matcher"]
    edit = payload["edit"]

    def link_matcher(origin):
        linked = bytearray.fromhex(matcher["code"])
        for offset, adjustment, symbol, addend in matcher["relocations"]:
            destination = origin + symbol if isinstance(symbol, int) else bindings[symbol] + addend
            struct.pack_into("<i", linked, offset, destination - origin - offset - adjustment - 4)
        return linked

    def link_edit(origin):
        linked = bytearray.fromhex(edit["code"])
        for offset, adjustment, symbol in edit["relocations"]:
            struct.pack_into("<i", linked, offset, bindings[symbol] - origin - offset - adjustment - 4)
        return linked

    origin = image.add_code(link_matcher)
    for begin, end, unwind in matcher["runtime"]:
        image.add_runtime_function(origin + begin, origin + end, unwind=bytes.fromhex(unwind))
    edit_origin = image.add_code(link_edit)
    edit_entry = edit_origin + edit["procedures"]["AssignAndRefreshToolbarSearch"]
    image.add_runtime_function(edit_entry, edit_origin + len(bytes.fromhex(edit["code"])),
                               unwind=bytes.fromhex("01 04 01 00 04 62 00 00"))
    redirect_calls(image, MATCH_CALLS, origin + matcher["procedures"]["PinyinToolbarMatch"])
    redirect_calls(image, EDIT_CALLS, edit_entry)
