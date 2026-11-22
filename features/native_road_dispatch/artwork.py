"""Derive a distinct dispatch console sprite from the local stock bitmap."""

import json
import struct
from pathlib import Path

BITMAP_READ_SITE = 0x40AC93
STOCK_BITMAP_READER = 0x144580
SPRITE_ORIGIN = (58, 14)


def apply(image) -> int:
    artwork_ready = image.add_zeroed_state(1, 1)
    symbols = {"ReadStockBitmap": STOCK_BITMAP_READER, "DispatchArtworkReady": artwork_ready}
    payload = json.loads(Path(__file__).with_name("artwork_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])

    def link(origin):
        linked = bytearray(code)
        for offset, adjustment, symbol in payload["relocations"]:
            struct.pack_into("<i", linked, offset, symbols[symbol] - origin - offset - 4 - adjustment)
        return linked

    origin = image.add_code(link)
    entry = origin + payload["procedures"]["DeriveDispatchArtwork"]
    image.add_runtime_function(entry, origin + len(code), unwind=bytes.fromhex("01 07 04 00 07 52 03 70 02 60 01 30"))
    image.patch(BITMAP_READ_SITE, bytes.fromhex("E8 E8 98 D3 FF"), b"\xe8" + struct.pack("<i", entry - BITMAP_READ_SITE - 5))
    return artwork_ready
