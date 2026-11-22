"""Compose per-vehicle native movement geometry and spawn headroom."""

import json
import struct
from pathlib import Path


HOOKS = (
    (0x74DEA5, "66440F6E4F44", "VehicleFootprintY"),
    (0x74DF09, "66440F6E5744", "VehicleFootprintRotatedX"),
    (0x74E2FF, "660F6E7344", "VehicleFrontExtent"),
    (0x74F0B5, "660F6E7344", "RoadMotionSelfY"),
    (0x74F1ED, "660F6E7744", "RoadMotionNeighborY"),
    (0x74F6AE, "660F6E7744", "RoadQueueNeighborY"),
    (0x7C2856, "660F6E7B44", "SpatialIndexInsertY"),
    (0x7C2BBA, "660F6E7B44", "SpatialIndexRemoveY"),
    (0x1F150F, "660F6E7B44", "CursorOriginY"),
    (0x1FC95D, "660F6E7B44", "CursorHitTestY"),
    (0x607A9A, "F30F10424C", "SpawnNeighborBack"),
    (0x73170E, "E84D63EDFF", "SpawnNewTruckCenter"),
)

SMALL_ALLOCATION_UNWIND = bytes.fromhex("0104010004620000")
# These horizontal-facing paths normally reload the integer height and convert
# it again. Reuse the effective float height already in XMM7 instead.
ROTATED_SWAPS = (0x7C28B7, 0x7C2C1B, 0x1F1569, 0x1FC9AC)
ORIGINAL_SWAP = bytes.fromhex("660F6E7344 660F6E7B40 0F5BF6 0F5BFF")
EFFECTIVE_SWAP = bytes.fromhex("0F28F7 660F6E7B40 0F5BFF")


def apply(image, get_truck_capacity: int) -> dict[str, int]:
    data = json.loads(Path(__file__).with_name("geometry_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(data["code"])
    procedures = data["procedures"]

    def link(origin: int) -> bytes:
        symbols = {
            "GetTruckCapacity": get_truck_capacity,
            "OriginalSpawnSpacing": 0x607A60,
            "OneCell": origin + len(code),
            "TwoCells": origin + len(code) + 4,
        }
        linked = bytearray(code)
        for offset, adjustment, symbol in data["relocations"]:
            struct.pack_into("<i", linked, offset, symbols[symbol] - origin - offset - 4 - adjustment)
        return linked + struct.pack("<ff", 1.0, 2.0)

    origin = image.add_code(link)
    starts = sorted(procedures.values())
    ends = dict(zip(starts, starts[1:] + [len(code)]))
    entries = {name: origin + offset for name, offset in procedures.items()}
    for site, encoded, procedure in HOOKS:
        before = bytes.fromhex(encoded)
        entry = entries[procedure]
        replacement = b"\xE8" + struct.pack("<i", entry - site - 5)
        image.patch(site, before, replacement.ljust(len(before), b"\x90"))
        image.add_runtime_function(entry, origin + ends[procedures[procedure]], unwind=SMALL_ALLOCATION_UNWIND)
    for site in ROTATED_SWAPS:
        image.patch(site, ORIGINAL_SWAP, EFFECTIVE_SWAP.ljust(len(ORIGINAL_SWAP), b"\x90"))
    return entries
