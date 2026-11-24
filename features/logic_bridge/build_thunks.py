"""Assemble the native logic bridge thunks using the Visual C++ x64 tools."""

import argparse
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from features.door_replacement.export_thunks import export


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ml64", default="ml64.exe", help="Path to the MSVC x64 MASM assembler")
    arguments = parser.parse_args()
    source = Path(__file__).with_name("logic_bridge.asm")
    with TemporaryDirectory() as scratch:
        obj = Path(scratch) / "logic_bridge.obj"
        subprocess.run(
            [arguments.ml64, "/nologo", "/c", f"/Fo{obj}", str(source)],
            check=True,
        )
        thunks = export(obj.read_bytes())
    source.with_name("thunks.json").write_text(
        json.dumps(thunks, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
