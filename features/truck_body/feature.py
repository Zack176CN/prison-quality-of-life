"""Hide cargo meshes for slots outside the stock supply truck's eight anchors."""

from __future__ import annotations

import json
import struct
from pathlib import Path

from patch_image import near_jump


SITE = 0x433ECA
EXPECTED = bytes.fromhex("81 7B 40 4D 02 00 00")
SYMBOLS = {
    "Game": 0xD57900,
    "DrawObject": SITE + len(EXPECTED),
    "NextObject": 0x434142,
}


def prepare(image) -> list[tuple[int, bytes, bytes]]:
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])

    def link(base: int) -> bytes:
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            displacement_end = base + offset + 4 + adjustment
            struct.pack_into("<i", linked, offset, SYMBOLS[name] - displacement_end)
        return bytes(linked)

    destination = image.add_code(link, unwind_from=SITE)
    replacement = near_jump(SITE, destination).ljust(len(EXPECTED), b"\x90")
    return [(SITE, EXPECTED, replacement)]
