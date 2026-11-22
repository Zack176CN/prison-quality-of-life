"""Staged stock-atlas, per-truck bed geometry using the native quad builder."""

import json
import struct
from pathlib import Path

from patch_image import align


SITE = 0x431EC8
EXPECT = bytes.fromhex("E8 23 09 D1 FF")
ANCHOR_SITE = 0x7E04C1
ANCHOR_EXPECT = bytes.fromhex("E8 CA D4 C1 FF")
CULL_SITE = 0x433ECA
CULL_EXPECT = bytes.fromhex("81 7B 40 4D 02 00 00 0F 85 49 01 00 00 48 89 5D 40")
NATIVE = {"NativeDrawQuad": 0x1427F0, "NativeSpriteMarker": 0x3FD990, "GamePointer": 0xD57900}
BED_START = 1 / 6
BED_END = 5 / 8


def prepare(image, bindings: dict[str, int]) -> list[tuple[int, bytes, bytes]]:
    plan = json.loads(Path(__file__).with_name("graphics-thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(plan["code"])
    symbols = NATIVE | bindings | {"TruckBedSnapshots": image.add_zeroed_state(16 * 64, 8)}
    segments = b"".join(struct.pack("<6f", left, right - left, (left + right) / 2 - 0.5,
                                    extra_center, right - left, extra_length)
                        for left, right, extra_center, extra_length in (
                            (0, BED_START, -0.5, 0),
                            (BED_START, BED_END, 0, 1),
                            (BED_END, 1, 0.5, 0),
                        ))

    def link(base: int) -> bytes:
        payload = bytearray(code)
        payload.extend(b"\0" * (align(len(payload), 8) - len(payload)))
        symbols["TruckBodySegments"] = base + len(payload)
        payload.extend(segments)
        symbols["GroundAxisLimit"] = base + len(payload)
        payload.extend(struct.pack("<f", 0.01))
        symbols["BedMarkerConstants"] = base + len(payload)
        payload.extend(struct.pack("<13f", 6, 64, 1, 15, BED_START, BED_END, 1e-5,
                                   0.25, 0.75, 0.86, 0.94, 0.5, 0.3))
        for offset, adjustment, name in plan["relocations"]:
            struct.pack_into("<i", payload, offset, symbols[name] - base - offset - 4 - adjustment)
        return payload

    start = image.add_code(link)
    entries = {name: start + offset for name, offset in plan["procedures"].items()}
    draw = entries["DrawTruckBody"]
    anchor = entries["LocateTruckCargo"]
    cull = entries["ClassifyTruckCargoRender"]
    image.add_runtime_function(draw, anchor, unwind=bytes.fromhex("01 07 02 00 07 01 1F 00"))
    image.add_runtime_function(anchor, cull, unwind=bytes.fromhex("01 04 01 00 04 C2 00 00"))
    image.add_runtime_function(cull, start + len(code), unwind=bytes.fromhex("01 09 03 0C 09 03 06 92 02 C0 00 00"))
    edits = [(site, expected, b"\xe8" + struct.pack("<i", entry - site - 5))
             for site, expected, entry in ((SITE, EXPECT, draw), (ANCHOR_SITE, ANCHOR_EXPECT, anchor))]
    classify = b"\xe8" + struct.pack("<i", cull - CULL_SITE - 5)
    classify += b"\x0f\x84" + struct.pack("<i", 0x434142 - CULL_SITE - 11)
    classify += b"\x0f\x89" + struct.pack("<i", 0x434020 - CULL_SITE - 17)
    return edits + [(CULL_SITE, CULL_EXPECT, classify)]
