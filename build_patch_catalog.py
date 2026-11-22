"""Build the patch catalog from supported, separately supplied game files."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path

from patch_image import PatchImage


HERE = Path(__file__).resolve().parent
STAFF_MORALE = "staffDeathMoraleDecay"
TRUCK_CAPACITIES = ("truckCapacity8", "truckCapacity12", "truckCapacity16")
LONG_TRUCK_FLEET = "longTruckFleet"
BUILDS = {
    "steam": (
        "cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9",
        "Windows Steam 10630057",
    ),
    "tyr": (
        "0558faef8a6fee27c0116ab11466e6c0733eeb6dad9fb10f96c7389c38e61c94",
        "Windows Steam 10630057 + Tyr 1.5.0 (staff morale enabled)",
    ),
    "tyr_core": (
        "18d53efe09301f0d9f37c2cdb77008d138365f2157a2dd43c0ddc9856510823f",
        "Windows Steam 10630057 + Tyr 1.5.0 Core",
    ),
}


def sha256(source: bytes) -> str:
    return hashlib.sha256(source).hexdigest()


def encode(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def edit(offset: int, before: bytes, after: bytes) -> dict[str, int | str]:
    return {"offset": offset, "before": encode(before), "after": encode(after)}


def header_edits(source: bytes, target: bytes, header_size: int) -> list[dict]:
    edits = []
    offset = 0
    while offset < header_size:
        if source[offset] == target[offset]:
            offset += 1
            continue
        start = offset
        while offset < header_size and source[offset] != target[offset]:
            offset += 1
        edits.append(edit(start, source[start:offset], target[start:offset]))
    return edits


def registered_features():
    from features.trees.feature import apply as remove_stumps
    from features.door_replacement.feature import apply as replace_with_door
    from features.wall_replacement.feature import apply as replace_with_wall
    from features.construction_clearance.feature import apply as clear_construction_sites
    from features.balanced_pickups.feature import apply as balance_pickups
    from features.staff_morale_decay.feature import apply as decay_staff_morale
    from features.native_road_dispatch.console import apply as add_native_dispatch
    from features.reform_program_progress.feature import apply as retain_reform_progress

    def replace_doors(image):
        recover_old_door = replace_with_door(image)
        replace_with_wall(image, recovery=recover_old_door)

    return {
        "removeTreeStumps": (remove_stumps,),
        "doubleClickDoorReplacement": (replace_doors,),
        "clearTreesForConstruction": (clear_construction_sites,),
        "balancedPickups": (balance_pickups,),
        "nativeRoadDispatch": (add_native_dispatch,),
        STAFF_MORALE: (decay_staff_morale,),
        "reformProgramProgress": (retain_reform_progress,),
    }


def tyr_variants(source: bytes, signature: list[dict]) -> dict[str, bytes]:
    digest = sha256(source)
    if digest not in (BUILDS["tyr"][0], BUILDS["tyr_core"][0]):
        raise ValueError("Supply the supported Tyr 1.5.0 default build with or without its staff morale tweak")
    original = digest == BUILDS["tyr_core"][0]
    alternative = bytearray(source)
    for row in signature:
        before = bytes.fromhex(row["expect"] if original else row["replace"])
        after = bytes.fromhex(row["replace"] if original else row["expect"])
        offset = row["offset"]
        if len(before) != len(after) or source[offset:offset + len(before)] != before:
            raise ValueError(f"Tyr staff morale instruction mismatch at 0x{offset:X}")
        alternative[offset:offset + len(after)] = after
    if original:
        return {"tyr_core": source, "tyr": bytes(alternative)}
    return {"tyr_core": bytes(alternative), "tyr": source}


def generate_build(build: str, source: bytes, features: dict) -> dict:
    from features.truck_capacity.feature import prepare as prepare_truck_capacities
    from features.truck_body.feature import prepare as prepare_cargo_rendering
    from features.long_truck_fleet.fleet import apply as add_long_truck_fleet

    digest, name = BUILDS[build]
    if sha256(source) != digest:
        raise ValueError(f"The supplied {build} executable does not match {digest}")

    image = PatchImage(source, build)
    tyr_staff_morale_installed = build == "tyr"
    by_feature = {}
    dispatch = None
    for feature, apply_steps in features.items():
        if tyr_staff_morale_installed and feature == STAFF_MORALE:
            continue
        start = len(image.edits)
        for apply in apply_steps:
            bindings = apply(image)
            if feature == "nativeRoadDispatch":
                dispatch = bindings
        writes = image.edits[start:]
        if not writes:
            raise ValueError(f"No changes were registered for {feature} on {build}")
        by_feature[feature] = [edit(*write) for write in sorted(writes)]

    common_feature_end = len(image.edits)
    add_long_truck_fleet(image, dispatch)
    long_truck_edits = image.edits[common_feature_end:]
    if not long_truck_edits:
        raise ValueError(f"No long truck changes were registered on {build}")
    by_feature[LONG_TRUCK_FLEET] = [edit(*write) for write in sorted(long_truck_edits)]

    capacity_edits = prepare_truck_capacities(image)
    shared_rendering = prepare_cargo_rendering(image)
    for variant in TRUCK_CAPACITIES:
        capacity_edits[variant].extend(shared_rendering)
    standard, extended = (sorted(capacity_edits[variant]) for variant in ("truckCapacity12", "truckCapacity16"))
    if not standard or standard == extended or [row[:2] for row in standard] != [row[:2] for row in extended]:
        raise ValueError(f"Truck capacity alternatives do not share a distinct set of hook sites on {build}")
    fixed_edits = {}
    for variant, writes in capacity_edits.items():
        raw_edits = []
        for rva, before, after in sorted(writes):
            if len(before) != len(after):
                raise ValueError(f"Invalid truck capacity signature length at RVA 0x{rva:X}")
            raw_edits.append((image.raw_offset(rva, len(before)), before, after))
        fixed_edits[variant] = raw_edits
        by_feature[variant] = [edit(*write) for write in raw_edits]

    output = image.finish()
    fixed_base = bytearray(output)
    for offset, before, _ in long_truck_edits:
        fixed_base[offset:offset + len(before)] = before
    fixed_hashes = {}
    for variant, edits in fixed_edits.items():
        fixed_output = bytearray(fixed_base)
        for offset, before, after in edits:
            if fixed_output[offset:offset + len(before)] != before:
                raise ValueError(f"{build}: fixed capacity signature or overlap at offset 0x{offset:X}")
            fixed_output[offset:offset + len(after)] = after
        fixed_hashes[variant] = sha256(fixed_output)

    # The shared section is inert until an enabled feature redirects native code to it.
    # Reserve one layout so the app can compose subsets without relocating thunks.
    common = header_edits(source, output, image.header_size)
    tail = output[len(source):]
    source_span = None
    if image.reused_source_span is not None:
        source_offset, output_offset, length = image.reused_source_span
        tail_offset = output_offset - len(source)
        tail = tail[:tail_offset] + tail[tail_offset + length:]
        source_span = {"sourceOffset": source_offset, "tailOffset": tail_offset, "length": length}
    return {
        "name": name,
        "sourceSha256": digest,
        "sourceLength": len(source),
        "allFeaturesSha256": fixed_hashes["truckCapacity12"],
        "truckCapacity8AllFeaturesSha256": fixed_hashes["truckCapacity8"],
        "truckCapacity16AllFeaturesSha256": fixed_hashes["truckCapacity16"],
        "longTruckFleetAllFeaturesSha256": sha256(output),
        "commonEdits": common,
        "append": encode(tail),
        "appendFromSource": source_span,
        "features": by_feature,
        "tyrStaffMoraleInstalled": tyr_staff_morale_installed,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--steam", type=Path, required=True, help="Windows Steam 10630057 stock executable")
    parser.add_argument("--tyr", type=Path, required=True, help="Observed Tyr 1.5.0 default build, with or without its staff morale tweak")
    parser.add_argument("--output", type=Path, default=HERE / "patches.json")
    args = parser.parse_args()
    features = registered_features()
    legacy_outputs = json.loads((HERE / "legacy_output_hashes.json").read_text(encoding="utf-8"))
    signature_path = HERE / "features/staff_morale_decay/tyr_signatures.json"
    signature = json.loads(signature_path.read_text(encoding="utf-8"))
    sources = {"steam": args.steam.read_bytes(), **tyr_variants(args.tyr.read_bytes(), signature)}
    builds = []
    for build in BUILDS:
        record = generate_build(build, sources[build], features)
        record["legacyOutputs"] = legacy_outputs.get(record["sourceSha256"], {})
        builds.append(record)
    catalog = {
        "schema": 1,
        "featureOrder": [*features, *TRUCK_CAPACITIES, LONG_TRUCK_FLEET],
        "tyrStaffMoraleSignatures": [
            {"offset": row["offset"], "variants": [encode(bytes.fromhex(value)) for value in (row["replace"], *row["superseded"])]}
            for row in signature
        ],
        "builds": builds,
    }
    args.output.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
