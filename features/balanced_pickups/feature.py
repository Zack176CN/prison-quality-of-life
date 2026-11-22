"""Keep pickup categories independent of the vehicle type and body length."""

import json
import struct
from pathlib import Path

from patch_image import near_jump

EXPECTED = bytes.fromhex("8B 51 40 81 FA 9E 00 00 00")
CHECKS = (
    (0x739900, "CheckWastePickup", "ContinueWastePickup"),
    (0x739970, "CheckExportsPickup", "ContinueExportsPickup"),
)


def apply(image) -> None:
    payload = json.loads(Path(__file__).with_name("pickup_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    continuations = {resume: site + len(EXPECTED) for site, _, resume in CHECKS}

    def link(origin):
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            struct.pack_into("<i", linked, offset, continuations[name] - origin - offset - 4 - adjustment)
        return linked

    origin = image.add_code(link)
    for site, name, _ in CHECKS:
        entry = origin + payload["procedures"][name]
        image.patch(site, EXPECTED, near_jump(site, entry).ljust(len(EXPECTED), b"\x90"))
