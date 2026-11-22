"""Offer mutually exclusive road supply truck capacity patches."""

from struct import pack

from patch_image import PatchImage, near_jump


DEFINITION_COMMIT_CALL = 0x601624
DEFINITION_ASSIGN = 0x6031C0
SUPPLY_TRUCK_KIND = 0x8B
NUM_SLOTS_OFFSET = 0x7C
PICKUP_STOP_LIMITS = (0x74E83A, 0x74E8E1)


def relative_call(origin: int, destination: int) -> bytes:
    return b"\xe8" + pack("<i", destination - origin - 5)


def definition_thunk(origin: int, slots: int) -> bytes:
    # EDI is the resolved object kind; RDX points to its parsed definition.
    compare_kind = b"\x81\xff" + pack("<I", SUPPLY_TRUCK_KIND)  # cmp edi, kind
    set_slots = bytes((0xC7, 0x42, NUM_SLOTS_OFFSET)) + pack("<I", slots)  # mov [rdx+7Ch], slots
    code = compare_kind + bytes((0x75, len(set_slots))) + set_slots  # jne original assignment
    return code + near_jump(origin + len(code), DEFINITION_ASSIGN)


def definition_edit(image: PatchImage, slots: int) -> tuple[int, bytes, bytes]:
    thunk = image.add_code(lambda origin: definition_thunk(origin, slots))
    return (
        DEFINITION_COMMIT_CALL,
        relative_call(DEFINITION_COMMIT_CALL, DEFINITION_ASSIGN),
        relative_call(DEFINITION_COMMIT_CALL, thunk),
    )


def prepare(image: PatchImage) -> dict[str, list[tuple[int, bytes, bytes]]]:
    """Pin the chosen slot count when the game's resolved definition is committed."""
    alternatives = {}
    for slots in (8, 12, 16):
        edits = [definition_edit(image, slots)]
        # Garbage and Exports stop checks are inside separate SupplyTruck-only branches.
        if slots != 8:
            stop_limit = bytes((0x83, 0xF8, slots))
            edits.extend((site, b"\x83\xf8\x08", stop_limit) for site in PICKUP_STOP_LIMITS)
        alternatives[f"truckCapacity{slots}"] = edits
    return alternatives
