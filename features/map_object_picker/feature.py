"""Pick a built object or tile material through the stock construction tools."""

import json
import struct
from pathlib import Path

from patch_image import near_jump


MAP_INPUT = 0x1CE15C
ORIGINAL = bytes.fromhex("8B 57 74 83 FA FF")
STOCK_HOVER_CANDIDATE = 0x1CB953
HOVER_ORIGINAL = bytes.fromhex("80 7F 6D 00 0F 85 1C 01 00 00")
STOCK_HOVER_RESULT = 0x1CBBC1
HOVER_RESULT_ORIGINAL = bytes.fromhex("4D 85 ED 74 38")
ICON_BOX_LAYOUT = 0xF85BF
ICON_BOX_LAYOUT_ORIGINAL = bytes.fromhex("E8 6C 64 04 00")
MIDDLE_BUTTON_HOOKS = (
    (0x11AAFB, "C6 81 4B 01 00 00 01", "CaptureMapPickerMiddleButton", "ContinueMiddleButtonDown"),
    (0x11A282, "88 8E 4E 01 00 00", "PublishMapPickerMiddleButton", "ContinueFrameMiddleEdge"),
    (0x11A7EC, "40 88 AF 48 01 00 00", "ClearMapPickerMiddleButton", "ContinueFocusLost"),
)
SYMBOLS = {
    "Game": 0xD57900,
    "InputManager": 0xD57648,
    "KeysHeld": 0xD57650,
    "KeysPressed": 0xD57750,
    "WindowManager": 0xD57638,
    "ObjectDefinitions": 0xDECCA0,
    "ObjectDefinitionCount": 0xE085CC,
    "MaterialDefinitions": 0xDECC90,
    "MaterialDefinitionCount": 0xDECCEC,
    "GameEntitlements": 0xDA5C10,
    "GetFocusedWindowId": 0x109BB0,
    "GetWindowIdByName": 0x1095E0,
    "GetWindowById": 0x1096D0,
    "GetControlById": 0x10C990,
    "GetControlByName": 0x10CA30,
    "ResolveWorldObject": 0x7BADC0,
    "IsObjectMenuItem": 0x22E530,
    "IsDoorMenuItem": 0x22E4A0,
    "IsWallMenuItem": 0x22E410,
    "IsFloorMenuItem": 0x22E810,
    "IsRoadTabMaterial": 0x60A890,
    "IsSharedFloorMaterial": 0x60A960,
    "HasContentEntitlement": 0x1C6B50,
    "RequiresExtendedContent": 0x7DE690,
    "IsUtilityBuildItem": 0x1F4E70,
    "CanUseToolbarItem": 0x6EDF70,
    "ClickToolbarCategory": 0x21AAF0,
    "RebuildToolbar": 0x20E3F0,
    "AssignToolbarSearch": 0xF5140,
    "RefreshToolbarSearchControl": 0xFA300,
    "IsObjectPackMatch": 0x210FA0,
    "SetToolbarDropdownValue": 0xF4260,
    "ScrollToolbarIconIntoView": 0xF85F0,
    "FinishIconBoxDraw": 0x13EA30,
    "ContinueIconBoxDraw": ICON_BOX_LAYOUT + len(ICON_BOX_LAYOUT_ORIGINAL),
    "SetMapTool": 0x1F3430,
    "SetBuildItem": 0x1F38C0,
    "ReadStockHover": 0x1CB500,
    "ContinueStockHoverCandidate": STOCK_HOVER_CANDIDATE + len(HOVER_ORIGINAL),
    "RejectStockHoverCandidate": 0x1CBA79,
    "ContinueStockHoverResult": STOCK_HOVER_RESULT + len(HOVER_RESULT_ORIGINAL),
    "TryStockActorHover": 0x1CBBFE,
    "FinishStockHover": 0x1CBEC0,
    "ContinueMapInput": MAP_INPUT + len(ORIGINAL),
    "FinishMapInput": 0x1CE2B0,
}


def apply(image) -> int:
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    entries = payload["procedures"]
    key = image.add_code(lambda _: struct.pack("<I", 4))
    sub_toolbar_name = image.add_code(lambda _: struct.pack("<16sQQ", b"SubToolbar", 10, 15))
    icon_box_name = image.add_code(lambda _: struct.pack("<16sQQ", b"IconBox", 7, 15))
    search_control_name = image.add_code(lambda _: struct.pack("<16sQQ", b"Search", 6, 15))
    empty_search = image.add_code(lambda _: struct.pack("<16sQQ", b"", 0, 3))
    object_type_name = image.add_code(lambda _: struct.pack("<16sQQ", b"ObjectType", 10, 15))
    object_pack_name = image.add_code(lambda _: struct.pack("<16sQQ", b"ObjectPack", 10, 15))
    pending = image.add_zeroed_state(40)
    bindings = {
        **SYMBOLS, "MapObjectPickerKey": key, "SubToolbarName": sub_toolbar_name,
        "IconBoxName": icon_box_name, "SearchControlName": search_control_name,
        "EmptyToolbarSearch": empty_search,
        "ObjectTypeControlName": object_type_name, "ObjectPackControlName": object_pack_name,
        "PendingPickerMiddleButton": pending, "FramePickerMiddleButton": pending + 1,
        "PickerHoverTool": pending + 8,
        "PickerScrollIconBox": pending + 16, "PickerScrollOwner": pending + 24,
        "PickerScrollKind": pending + 28, "PickerScrollSubtype": pending + 32,
    }
    for site, signature, _, continuation in MIDDLE_BUTTON_HOOKS:
        bindings[continuation] = site + len(bytes.fromhex(signature))

    def link(origin):
        linked = bytearray(code)
        for offset, adjustment, symbol in payload["relocations"]:
            struct.pack_into("<i", linked, offset, bindings[symbol] - origin - offset - 4 - adjustment)
        return linked

    origin = image.add_code(link)
    starts = sorted(entries.values())
    ends = dict(zip(starts, starts[1:] + [len(code)]))
    hooks = (
        (MAP_INPUT, ORIGINAL, "PickMapObjectFrame"),
        (STOCK_HOVER_CANDIDATE, HOVER_ORIGINAL, "CheckPickerHoverCandidate"),
        (STOCK_HOVER_RESULT, HOVER_RESULT_ORIGINAL, "KeepPickerHoverResult"),
        (ICON_BOX_LAYOUT, ICON_BOX_LAYOUT_ORIGINAL, "ScrollPickedItemAfterLayout"),
        *((site, bytes.fromhex(signature), name) for site, signature, name, _ in MIDDLE_BUTTON_HOOKS),
    )
    for site, before, name in hooks:
        start = entries[name]
        destination = origin + start
        image.patch(site, before, near_jump(site, destination).ljust(len(before), b"\x90"))
        image.add_runtime_function(destination, origin + ends[start], unwind_from=site)
    for name, unwind in (
        ("TryPickMapObject", "01 04 01 00 04 A2 00 00"),    # sub rsp, 58h
        ("ClassifyPickerObject", "01 04 01 00 04 62 00 00"), # sub rsp, 38h
        ("FindPickerObject", "01 07 02 00 07 01 1D 00"),    # sub rsp, 0E8h
        ("FindPickerSubToolbar", "01 04 01 00 04 42 00 00"), # sub rsp, 28h
        ("FocusPickerToolbarItem", "01 04 01 00 04 62 00 00"), # sub rsp, 38h
        ("RevealPickerObjectFilters", "01 04 01 00 04 62 00 00"), # sub rsp, 38h
        ("UpdatePickerDropdown", "01 04 01 00 04 62 00 00"), # sub rsp, 38h
    ):
        start = entries[name]
        image.add_runtime_function(origin + start, origin + ends[start], unwind=bytes.fromhex(unwind))
    return key
