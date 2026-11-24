"""Generate the native search table from the Unicode 17.0.0 Unihan archive.

Source: https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
Unihan data copyright © 2025 Unicode, Inc. See LICENSE-UNICODE.txt.

Each U+3400–U+9FFF entry is a little-endian uint32 file offset. An offset
of zero means unmapped. Every nonzero offset addresses a list of lowercase
ASCII syllables, each terminated by NUL, with a final empty syllable.
"""

import argparse
import hashlib
import struct
import unicodedata
import zipfile
from pathlib import Path


FIRST_CODEPOINT = 0x3400
LAST_CODEPOINT = 0x9FFF
ARCHIVE_SHA256 = "f7a48b2b545acfaa77b2d607ae28747404ce02baefee16396c5d2d7a8ef34b5e"
READING_PROPERTIES = ("kMandarin", "kTGHZ2013", "kHanyuPinyin")


def plain_pinyin(reading: str) -> bytes:
    decomposed = unicodedata.normalize("NFD", reading).replace("u\u0308", "v")
    return "".join(char for char in decomposed if not unicodedata.combining(char)).encode("ascii")


def read_pronunciations(source: Path) -> dict[str, dict[int, list[bytes]]]:
    if hashlib.sha256(source.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("Expected the official Unicode 17.0.0 Unihan.zip archive")

    by_property = {field: {} for field in READING_PROPERTIES}
    with zipfile.ZipFile(source) as archive, archive.open("Unihan_Readings.txt") as records:
        for record in records:
            if not record.startswith(b"U+"):
                continue
            code, field, value = record.decode("utf-8").rstrip("\n").split("\t")
            if field not in by_property:
                continue
            point = int(code[2:], 16)
            if not FIRST_CODEPOINT <= point <= LAST_CODEPOINT:
                continue
            if field == "kMandarin":
                words = value.split()
            else:
                # Each group begins with dictionary locations followed by a colon.
                words = [
                    word
                    for group in value.split()
                    for word in group.split(":", 1)[1].split(",")
                ]
            by_property[field][point] = [plain_pinyin(word) for word in words]
    return by_property


def generate(source: Path, destination: Path) -> None:
    by_property = read_pronunciations(source)
    points = sorted({point for entries in by_property.values() for point in entries})
    point_count = LAST_CODEPOINT - FIRST_CODEPOINT + 1
    offset_table = bytearray(point_count * 4)
    syllable_lists = bytearray()
    offset_by_readings = {}
    reading_count = 0
    polyphonic_count = 0

    for point in points:
        readings = tuple(dict.fromkeys(
            reading for field in READING_PROPERTIES for reading in by_property[field].get(point, ())
        ))
        if readings not in offset_by_readings:
            offset_by_readings[readings] = len(offset_table) + len(syllable_lists)
            syllable_lists.extend(b"\0".join(readings) + b"\0\0")
        struct.pack_into("<I", offset_table, (point - FIRST_CODEPOINT) * 4, offset_by_readings[readings])
        reading_count += len(readings)
        polyphonic_count += len(readings) > 1

    destination.write_bytes(offset_table + syllable_lists)
    print(f"{len(points):,} code points, {reading_count:,} readings, "
          f"{polyphonic_count:,} characters with alternatives, {len(offset_by_readings):,} unique lists, "
          f"{len(offset_table) + len(syllable_lists):,} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unihan", type=Path, help="The official Unicode 17.0.0 Unihan.zip")
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("pronunciations.bin"))
    args = parser.parse_args()
    generate(args.unihan, args.output)
