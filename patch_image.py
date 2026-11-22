"""Apply exact-build code changes to an in-memory Windows x64 game image."""

from __future__ import annotations

import struct
from collections.abc import Callable


def align(value: int, alignment: int) -> int:
    return (value + alignment - 1) & -alignment


def near_jump(origin: int, destination: int) -> bytes:
    return b"\xe9" + struct.pack("<i", destination - origin - 5)


class PatchImage:
    def __init__(self, source: bytes, build: str):
        self.build = build
        self.source = source
        self.image = bytearray(source)
        self.payload = bytearray()
        self.unwind_entries: list[tuple[int, int, int]] = []
        self.edits: list[tuple[int, bytes, bytes]] = []
        self.reused_source_span: tuple[int, int, int] | None = None
        pe = struct.unpack_from("<I", source, 0x3C)[0]
        if source[pe:pe + 6] != b"PE\0\0\x64\x86":
            raise ValueError("Expected a Windows x64 PE image")
        self.file_header = pe + 4
        self.section_count = struct.unpack_from("<H", source, pe + 6)[0]
        self.optional = pe + 24
        if struct.unpack_from("<H", source, self.optional)[0] != 0x20B:
            raise ValueError("Expected a PE32+ optional header")
        optional_size = struct.unpack_from("<H", source, pe + 20)[0]
        section_table = self.optional + optional_size
        self.section_table = section_table
        self.new_section_header = section_table + self.section_count * 40
        self.section_alignment, self.file_alignment = struct.unpack_from("<II", source, self.optional + 32)
        self.new_section_rva, self.header_size = struct.unpack_from("<II", source, self.optional + 56)
        self.new_section_rva = align(self.new_section_rva, self.section_alignment)
        self.sections = [
            struct.unpack_from("<8sIIII", source, section_table + index * 40)
            for index in range(self.section_count)
        ]
        self.exception_directory = self.optional + 112 + 3 * 8
        self.runtime_functions = self._read_runtime_functions()

    def raw_offset(self, rva: int, size: int) -> int:
        for _, _, start, raw_size, raw_offset in self.sections:
            if start <= rva and rva + size <= start + raw_size:
                return raw_offset + rva - start
        raise ValueError(f"RVA 0x{rva:X} is outside raw section data")

    def read(self, rva: int, size: int) -> bytes:
        offset = self.raw_offset(rva, size)
        return bytes(self.image[offset:offset + size])

    def patch(self, rva: int, expected: bytes, replacement: bytes) -> None:
        if not expected or len(expected) != len(replacement):
            raise ValueError(f"Invalid instruction size at RVA 0x{rva:X}")
        offset = self.raw_offset(rva, len(expected))
        end = offset + len(expected)
        if self.source[offset:end] != expected:
            raise ValueError(f"{self.build}: instruction signature mismatch at RVA 0x{rva:X}")
        if any(offset < previous + len(before) and previous < end for previous, before, _ in self.edits):
            raise ValueError(f"Overlapping patch at RVA 0x{rva:X}")
        self.image[offset:end] = replacement
        self.edits.append((offset, expected, replacement))

    def _read_runtime_functions(self) -> list[tuple[int, int, int]]:
        rva, size = struct.unpack_from("<II", self.source, self.exception_directory)
        if size == 0 or size % 12:
            raise ValueError("Expected a Windows x64 runtime function table")
        return list(struct.iter_unpack("<III", self.read(rva, size)))

    def _reserve(self, alignment: int, padding: int = 0) -> int:
        offset = align(len(self.payload), alignment)
        self.payload.extend(bytes([padding]) * (offset - len(self.payload)))
        return self.new_section_rva + offset

    def add_code(
        self,
        build: Callable[[int], bytes],
        *,
        unwind_from: int | None = None,
        unwind: bytes | None = None,
    ) -> int:
        """Add position-independent code and optional Windows x64 unwind metadata."""
        rva = self._reserve(16, 0xCC)
        code = build(rva)
        if not code:
            raise ValueError("A native helper must emit code")
        self.payload.extend(code)
        if unwind_from is not None or unwind:
            self.add_runtime_function(rva, rva + len(code), unwind_from=unwind_from, unwind=unwind)
        return rva

    def add_runtime_function(
        self,
        begin: int,
        end: int,
        *,
        unwind_from: int | None = None,
        unwind: bytes | None = None,
    ) -> None:
        """Register the unwind record of one procedure within the native code section."""
        if not self.new_section_rva <= begin < end <= self.new_section_rva + len(self.payload):
            raise ValueError("Unwind function range lies outside the native section")
        if unwind_from is not None:
            if unwind is not None:
                raise ValueError("Choose independent or chained unwind information")
            original = next((entry for entry in self.runtime_functions if entry[0] <= unwind_from < entry[1]), None)
            if original is None:
                raise ValueError(f"No unwind information at RVA 0x{unwind_from:X}")
            frame = self.read(original[2] + 3, 1)
            unwind = b"\x21\x00\x00" + frame + struct.pack("<III", *original)
        if not unwind:
            raise ValueError("Expected a Windows x64 unwind record")
        unwind_rva = self._reserve(4)
        self.payload.extend(unwind)
        self.unwind_entries.append((begin, end, unwind_rva))

    def add_zeroed_state(self, size: int, alignment: int = 8) -> int:
        """Reserve process-local writable state in the zero-filled tail of .data."""
        if size < 1 or alignment < 1 or alignment & (alignment - 1):
            raise ValueError("Invalid state size or alignment")
        index = next(index for index, item in enumerate(self.sections) if item[0] == b".data\0\0\0")
        header = self.section_table + index * 40
        _, _, rva, raw_size, _ = self.sections[index]
        current_size = struct.unpack_from("<I", self.image, header + 8)[0]
        state = align(rva + max(current_size, raw_size), alignment)
        following = min(item[2] for item in self.sections if item[2] > rva)
        if state + size > following:
            raise ValueError("No room in the zero-filled writable page")
        struct.pack_into("<I", self.image, header + 8, state + size - rva)
        return state

    def finish(self) -> bytes:
        if not self.payload:
            return bytes(self.image)
        header = self.new_section_header
        if header + 40 > self.header_size or any(self.source[header:header + 40]):
            raise ValueError("The executable has no room for a new PE section header")
        raw_start = align(len(self.image), self.file_alignment)
        if self.unwind_entries:
            table = self._reserve(4)
            rva, size = struct.unpack_from("<II", self.source, self.exception_directory)
            original_offset = self.raw_offset(rva, size)
            added = sorted(self.unwind_entries)
            if self.runtime_functions != sorted(self.runtime_functions) or self.runtime_functions[-1][1] > added[0][0]:
                raise ValueError("The original runtime function table cannot be copied as a prefix")
            self.payload.extend(self.source[original_offset:original_offset + size])
            for entry in added:
                self.payload.extend(struct.pack("<III", *entry))
            struct.pack_into("<II", self.image, self.exception_directory, table, size + len(added) * 12)
            self.reused_source_span = (original_offset, raw_start + table - self.new_section_rva, size)

        raw_length = align(len(self.payload), self.file_alignment)
        struct.pack_into("<H", self.image, self.file_header + 2, self.section_count + 1)
        code_size = struct.unpack_from("<I", self.source, self.optional + 4)[0]
        struct.pack_into("<I", self.image, self.optional + 4, code_size + raw_length)
        struct.pack_into(
            "<I", self.image, self.optional + 56,
            align(self.new_section_rva + len(self.payload), self.section_alignment),
        )
        struct.pack_into(
            "<8sIIIIIIHHI", self.image, header,
            b".paqol", len(self.payload), self.new_section_rva, raw_length, raw_start,
            0, 0, 0, 0, 0x60000020,
        )
        self.image.extend(bytes(raw_start - len(self.image)))
        self.image.extend(self.payload.ljust(raw_length, b"\0"))
        return bytes(self.image)
