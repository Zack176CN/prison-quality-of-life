"""Register the console through the game's native object and sprite tables."""

import json
import struct
from pathlib import Path

from patch_image import align


HOOKS = (
    (0x5FF6E7, "E8 84 14 00 00", "RegisterBaseDispatch", 0x68),
    (0x600BB3, "E8 C8 52 DB FF", "CollectBaseDispatchPaths", 0x28),
    (0x600E10, "E8 0B 41 B1 FF", "OpenBaseDispatchText", 0x38),
)
SYMBOLS = {
    "Game": 0xD57900,
    "ObjectDefCount": 0xE085CC,
    "ObjectDefTable": 0xDECCA0,
    "RoomDefCount": 0xDECCBC,
    "RoomDefTable": 0xDECCB0,
    "SpriteEnumList": 0xDC3850,
    "ReadMaterials": 0x600B70,
    "CollectMaterialPaths": 0x3B5E80,
    "AppendMaterialPath": 0xF74A0,
    "OpenTextFile": 0x114F20,
    "NativeNew": 0x8DF294,
    "TextReaderFromMemory": 0x118090,
    "FindObjectKind": 0x60A3B0,
    "FindRoomKind": 0x60A230,
    "InsertLikelyObject": 0x167EE0,
    "FindSpriteId": 0x3FDD70,
    "FindSpriteDescriptor": 0x3FDDB0,
    "RegisterSpriteDescriptor": 0x3FE400,
    "CompareNativeString": 0xED100,
}

MATERIAL = b"""BEGIN Object
    Name PAOutboundConsole
    Width 1
    Height 1
    ConstructionTime 1.00000
    Price -200
    Toughness 15
    RenderDepth 1
    Group StaticObject
    BlockedBy Wall
    BlockedBy StaticObject
    BlockedBy UtilityStation
    Sprite QOLDSP_Monitor
    ToolbarSprite QOLDSP_Monitor
    MadeOf Composite
    Properties StaticObject
END
"""


def small_string(value: bytes) -> bytes:
    return struct.pack("<16sQQ", value, len(value), 15)


def prepare(image, *, dispatch_kind: int, artwork_ready: int,
            sprite_origin: tuple[int, int], register_translations: int) -> list:
    symbols = SYMBOLS | {
        "DispatchObjectKind": dispatch_kind,
        "LoadingDispatchResource": image.add_zeroed_state(1, 1),
        "OwnedDispatchSprite": image.add_zeroed_state(4, 4),
        "DispatchArtworkReady": artwork_ready,
        "RegisterDispatchTranslations": register_translations,
    }
    payload = json.loads(Path(__file__).with_name("registration_thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    entries = payload["procedures"]
    contents = (
        ("ObjectNameText", b"PAOutboundConsole\0"),
        ("ResourceName", small_string(b"data/paqol.dsp")),
        ("StockSpriteName", small_string(b"PhoneMonitor")),
        ("AliasSpriteName", small_string(b"QOLDSP_Monitor")),
        ("DispatchSpriteOrigin", struct.pack("<ii", *sprite_origin)),
        ("DispatchMaterialSize", struct.pack("<I", len(MATERIAL))),
        ("DispatchMaterialText", MATERIAL),
        ("DeliveriesRoomName", small_string(b"Deliveries")),
        ("GarbageRoomName", small_string(b"Garbage")),
        ("ExportsRoomName", small_string(b"Exports")),
    )

    def link(base: int) -> bytes:
        result = bytearray(code)
        for label, value in contents:
            result.extend(b"\0" * (align(len(result), 8) - len(result)))
            symbols[label] = base + len(result)
            result.extend(value)
        symbols["AliasSpriteNameHeader"] = symbols["AliasSpriteName"] + 16
        for offset, adjustment, name in payload["relocations"]:
            struct.pack_into("<i", result, offset, symbols[name] - base - offset - 4 - adjustment)
        return result

    base = image.add_code(link)
    edits = []
    procedures = HOOKS + (
        (0, "", "RegisterDispatchSprite", 0x78),
        (0, "", "EnsureDispatchSpriteEnum", 0x38),
        (0, "", "RegisterDispatchRoomHint", 0x28),
    )
    for index, (site, signature, procedure, stack) in enumerate(procedures):
        start = base + entries[procedure]
        end = base + entries[(procedures[index + 1][2] if index + 1 < len(procedures) else "IsNativeDispatchResource")]
        allocation = (((stack - 8) // 8) << 4) | 2
        image.add_runtime_function(start, end, unwind=bytes((1, 4, 1, 0, 4, allocation, 0, 0)))
        if site:
            edits.append((site, bytes.fromhex(signature), b"\xe8" + struct.pack("<i", start - site - 5)))
    return edits
