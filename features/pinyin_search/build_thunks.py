"""Compile the freestanding search matcher and its native input wrapper."""

import argparse
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from features.door_replacement.export_thunks import export as export_asm
from features.multicore_circuits.build_thunks import export as export_c


HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", required=True, type=Path)
    parser.add_argument("--ml64", required=True, type=Path)
    parser.add_argument("--work-dir", required=True, type=Path)
    args = parser.parse_args()
    with TemporaryDirectory(dir=args.work_dir) as scratch:
        matcher = Path(scratch) / "matcher.obj"
        wrapper = Path(scratch) / "search_edit.obj"
        subprocess.run([
            str(args.zig.resolve()), "cc", "-target", "x86_64-windows-msvc", "-O2", "-ffreestanding",
            "-fno-builtin", "-fno-stack-protector", "-fno-function-sections", "-fno-data-sections",
            "-funwind-tables", "-g0", "-Wall", "-Wextra", "-Werror",
            "-c", str(HERE / "matcher.c"), "-o", str(matcher),
        ], check=True)
        subprocess.run([
            str(args.ml64.resolve()), "/nologo", "/c", f"/Fo{wrapper}", str(HERE / "search_edit.asm"),
        ], check=True)
        payload = {
            "matcher": export_c(matcher.read_bytes(), ("PinyinToolbarMatch",)),
            "edit": export_asm(wrapper.read_bytes()),
        }
    (HERE / "thunks.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
