"""Register native console controls through the stock object context menu."""

from __future__ import annotations

import json
import struct
from pathlib import Path

from patch_image import near_jump


BUILDER = 0x297868
CLICK_SITES = (0x209C52, 0x298A38)
WIDGET_RENDER = 0x1024A0
NATIVE = {
    "AppendContextItem": 0x2978D0,
    "ContinueContextMenu": BUILDER + 6,
    "StockClick": 0x7D7480,
    "CopyNativeCaption": 0xF5140,
    "GameLanguage": 0xDBF968,
    "NativeWastePermission": 0x739900,
    "NativeExportsPermission": 0x739970,
    "LongTruckMode": 0x738171,
    "NativeWidgetRenderer": 0xD57638,
    "ContinueWidgetRender": WIDGET_RENDER + 7,
}

CAPTIONS = (
    ("Request 1 truck", "召唤一辆货车"),
    ("Request 2 trucks", "召唤两辆货车"),
    ("Unable to queue", "无法新增派车请求"),
    ("Unavailable", "当前无法设置"),
    ("Auto: Off", "自动调度：关闭"),
    ("Auto: 15 min", "自动调度：15 分钟"),
    ("Auto: 30 min", "自动调度：30 分钟"),
    ("Auto: 60 min", "自动调度：60 分钟"),
    ("Limit: 1 truck", "货车上限：1 辆"),
    ("Limit: 2 trucks", "货车上限：2 辆"),
    ("Limit: 3 trucks", "货车上限：3 辆"),
    ("Limit: 4 trucks", "货车上限：4 辆"),
    ("Limit: 5 trucks", "货车上限：5 辆"),
    ("Balanced pickup: Off", "均衡取货：关闭"),
    ("Balanced pickup: On", "均衡取货：开启"),
    ("Backlog: 4 stacks", "积压门槛：4 堆"),
    ("Backlog: 8 stacks", "积压门槛：8 堆"),
    ("Backlog: 16 stacks", "积压门槛：16 堆"),
    ("Backlog: Custom", "积压门槛：自定义"),
    ("Last: no attempts", "最近调度：暂无记录"),
    ("Last: truck sent", "最近调度：已发车"),
    ("Last: cooldown", "最近调度：等待发车间隔"),
    ("Last: limit reached", "最近调度：货车已达上限"),
    ("Last: entrance blocked", "最近调度：入口被占用"),
    ("Last: below threshold", "最近调度：积压未达门槛"),
    ("Last: unavailable", "最近调度：当前无法派车"),
    ("Truck length: 8 slots", "车长：标准（8 格）"),
    ("Truck length: 12 slots", "车长：中型（12 格）"),
    ("Truck length: 16 slots", "车长：加长（16 格）"),
    ("Last: request queued", "最近调度：请求已排队"),
    ("Waste: counting", "垃圾积压：待统计"),
    ("Exports: counting", "出货积压：待统计"),
    ("Waste: ", "垃圾积压："),
    ("Exports: ", "出货积压："),
)

STACK_SIZES = {
    "AppendDispatchButtons": 0x78,
    "ReadDispatchConfig": 0x28,
    "ReadAndLocalizeDispatchOutcome": 0x28,
    "RefreshDispatchLabel": 0x78,
    "FormatDispatchCount": 0x48,
    "DispatchClickEnqueue": 0x38,
    "DispatchClickLength": 0x38,
    "DispatchClickSettings": 0x38,
    "AssignButtonCaption": 0x48,
}


def prepare(image, symbols) -> None:
    """Install menu hooks bound to the registered kind and scheduler exports."""
    path = Path(__file__).with_name("ui_thunks.json")
    payload = json.loads(path.read_text(encoding="utf-8"))
    _link(image, symbols, payload)


def _link(image, symbols, payload) -> None:
    bindings = {**NATIVE, **symbols, "DispatchKind": symbols["DispatchObjectKind"]}
    bindings["DispatchLabelCache"] = image.add_zeroed_state(3 * 0x10)
    records = []
    for languages in CAPTIONS:
        for caption in languages:
            text = (caption + "\0").encode("utf-32-le")
            if len(text) > 92 or len(caption) < 4:
                raise ValueError(f"Caption does not fit the native text record: {caption}")
            records.append(struct.pack("<I", len(text) // 4 - 1) + text.ljust(92, b"\0"))
    table = b"".join(records)
    bindings["DispatchCaptionTable"] = image.add_code(lambda _: table)

    raw = bytes.fromhex(payload["code"])
    procedures = payload["procedures"]

    def link(base):
        data = bytearray(raw)
        for offset, adjustment, symbol in payload["relocations"]:
            destination = bindings[symbol]
            struct.pack_into("<i", data, offset, destination - base - offset - 4 - adjustment)
        return bytes(data)

    base = image.add_code(link)
    starts = sorted(procedures.values())
    ends = dict(zip(starts, starts[1:] + [len(raw)]))
    build = procedures["BuildDispatchMenu"]
    click = procedures["DispatchClick"]
    image.patch(BUILDER, bytes.fromhex("39 9E D4 01 00 00"), near_jump(BUILDER, base + build) + b"\x90")
    image.add_runtime_function(base + build, base + ends[build], unwind_from=BUILDER)
    renderer = base + procedures["RenderDispatchLabels"]
    image.patch(WIDGET_RENDER, bytes.fromhex("48 8B 05 91 51 C5 00"), near_jump(WIDGET_RENDER, renderer) + b"\x90\x90")

    for site, signature in zip(CLICK_SITES, ("E8 29 D8 5C 00", "E8 43 EA 53 00")):
        replacement = b"\xe8" + struct.pack("<i", base + click - site - 5)
        image.patch(site, bytes.fromhex(signature), replacement)

    for procedure, stack_size in STACK_SIZES.items():
        if procedure not in procedures:
            continue
        start = procedures[procedure]
        allocation = ((stack_size - 8) // 8 << 4) | 2
        unwind = bytes((1, 4, 1, 0, 4, allocation, 0, 0))
        image.add_runtime_function(base + start, base + ends[start], unwind=unwind)
