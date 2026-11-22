"""Register native dispatch console text in the game's live translation map."""

import json
import struct
from pathlib import Path

from patch_image import align


SCOPE = 0x18C938
EXPECTED = bytes.fromhex("E8 53 00 00 00")
SYMBOLS = {
    "LanguagePreference": 0xDBF968,
    "LanguageMap": 0xD57880,
    "HasTranslation": 0x11DB20,
    "GetOrInsertTranslation": 0x11DDD0,
    "CopyTranslationValue": 0xF5140,
    "LoadLanguageFile": 0x18C990,
}


def messages(name: str, tooltip: str) -> bytes:
    return struct.pack("<II", len(name), len(tooltip)) + f"{name}\0{tooltip}\0".encode("utf-32-le")


DATA = {
    "DispatchNameKey": b"object_paoutboundconsole\0",
    "DispatchTooltipKey": b"buildtoolbar_popup_obj_paoutboundconsole\0",
    "ChineseLocale": b"simplifiedchinese\0",
    "EnglishStrings": messages("Outbound Dispatch Console", "Select the built console to queue supply trucks for garbage and exports. Dispatch depends on road access, vehicle limits, and the selected interval."),
    "ChineseStrings": messages("出货调度台", "建成后点击调度台，按需为垃圾区和出货区安排货车。发车受道路通行、车辆上限和所选间隔约束。"),
}


def prepare(image, dispatch_kind: int):
    payload = json.loads(Path(__file__).with_name("language-thunks.json").read_text(encoding="utf-8"))
    code = bytes.fromhex(payload["code"])
    entries = payload["procedures"]
    symbols = SYMBOLS | {"DispatchObjectKind": dispatch_kind}

    def link(base: int):
        result = bytearray(code)
        for name, raw in DATA.items():
            result.extend(b"\0" * (align(len(result), 8) - len(result)))
            symbols[name] = base + len(result)
            result.extend(raw)
        for offset, adjustment, name in payload["relocations"]:
            struct.pack_into("<i", result, offset, symbols[name] - base - offset - 4 - adjustment)
        return result

    base = image.add_code(link)
    for index, (procedure, stack) in enumerate((
        ("ReloadDispatchLanguage", 0x28), ("RegisterDispatchTranslations", 0x38), ("AddDispatchTranslation", 0x68),
    )):
        bounds = sorted(entries.values()) + [len(code)]
        allocation = (((stack - 8) // 8) << 4) | 2
        image.add_runtime_function(base + entries[procedure], base + bounds[index + 1],
                                   unwind=bytes((1, 4, 1, 0, 4, allocation, 0, 0)))
    symbols["RegisterDispatchTranslations"] = base + entries["RegisterDispatchTranslations"]
    hook = base + entries["ReloadDispatchLanguage"]
    edits = [(SCOPE, EXPECTED, b"\xe8" + struct.pack("<i", hook - SCOPE - 5))]
    return symbols, edits
