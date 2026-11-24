"""Cancel a construction selection after the stock map has handled a right click."""

import json
from pathlib import Path
import struct

from patch_image import near_jump


MESSAGE_DISPATCH = 0x11A78A
FRAME_PUBLICATION = 0x11A2DC
MAP_CONTROL_CHECK = 0x1CE146
MAP_EPILOGUE = 0x1CED1D

HOOKS = (
    (MESSAGE_DISPATCH, "83 FA 07 77 16", "ObserveRightClick"),
    (FRAME_PUBLICATION, "88 86 52 01 00 00", "PublishRightClick"),
    (MAP_CONTROL_CHECK, "80 3D 14 95 B8 00 00", "StageRightClickDeselect"),
    (MAP_EPILOGUE, "4C 8D 9C 24 58 01 00 00", "FinishRightClickDeselect"),
)

SYMBOLS = {
    "Game": 0xD57900,
    "InputManager": 0xD57648,
    "WindowManager": 0xD57638,
    "ShiftAndControlKeys": 0xD57660,
    "ControlKey": 0xD57661,
    "AltKey": 0xD57662,
    "BuildToolbarVtable": 0xAC4810,
    "ContinueLowMessage": 0x11A78F,
    "ContinueHighMessage": 0x11A7A5,
    "ContinueInputFrame": 0x11A2E2,
    "ContinueControlCheck": 0x1CE14D,
    "ContinueMapInput": 0x1CE15C,
    "ContinueMapEpilogue": 0x1CED25,
    "StopPreviewSound": 0x14E000,
    "GetWindowIdByName": 0x1095E0,
    "GetWindowById": 0x1096D0,
    "SetBuildItem": 0x1F38C0,
}


def apply(image):
    payload = json.loads(Path(__file__).with_name("thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]
    toolbar_name = image.add_code(lambda _: struct.pack("<16sQQ", b"SubToolbar", 10, 15))
    state = image.add_zeroed_state(28)
    bindings = {
        **SYMBOLS, "SubToolbarName": toolbar_name,
        "TapArmed": state, "PendingTap": state + 1, "FrameTap": state + 2,
        "DeselectAfterStock": state + 3,
        "TapOrigin": state + 4, "TapWorld": state + 8, "TapSelection": state + 16,
        "TapMode": state + 24,
    }

    def link(origin):
        linked = bytearray(code)
        for offset, adjustment, name in payload["relocations"]:
            struct.pack_into("<i", linked, offset, bindings[name] - origin - offset - adjustment - 4)
        return linked

    origin = image.add_code(link)
    starts = sorted(procedures.values())
    ends = dict(zip(starts, starts[1:] + [len(code)]))
    for site, signature, name in HOOKS:
        before = bytes.fromhex(signature)
        start = procedures[name]
        target = origin + start
        image.patch(site, before, near_jump(site, target).ljust(len(before), b"\x90"))
        image.add_runtime_function(target, origin + ends[start], unwind_from=site)

    for name, unwind in (
        ("CanDeselectBuildItem", "01 04 01 00 04 62 00 00"),
        ("DeselectBuildItem", "01 04 01 00 04 42 00 00"),
    ):
        start = procedures[name]
        image.add_runtime_function(origin + start, origin + ends[start], unwind=bytes.fromhex(unwind))
