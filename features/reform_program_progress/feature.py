"""Keep eligible students enrolled in two courses with no required equipment."""

from __future__ import annotations

import struct

from patch_image import near_jump


PRUNE_ROSTER = 0x6DF22F
DEFINITION_COUNT = 0xDF850C
DEFINITION_TABLE = 0xDF80B0


def apply(image) -> None:
    expected = bytes.fromhex("44 8B 75 60 4D 8B C1")
    resume = PRUNE_ROSTER + len(expected)

    def build(base: int) -> bytes:
        # The equipment scan leaves MaxPlaces at zero for these two classes.
        # Enrollment already uses the definition's Places when there is no
        # equipment. Apply the same limit before removing existing students.
        code = bytearray(bytes.fromhex(
            "44 8B 75 60 "              # mov r14d, [rbp+60h]   (stock MaxPlaces)
            "4D 8B C1 "                 # mov r8, r9            (stock student argument)
            "45 85 F6 75 3C "           # test r14d, r14d; jne resume
            "8B 45 34 "                 # mov eax, [rbp+34h]    (program type)
            "83 F8 15 74 05 "           # cmp eax, FlowerTherapy; je definition
            "83 F8 18 75 2F "           # cmp eax, JuvenileCorrection; jne resume
            "3B 05 00 00 00 00 7D 27 " # cmp eax, [rip+definition_count]; jge resume
            "4C 8B 1D 00 00 00 00 "    # mov r11, [rip+definition_table]
            "4D 85 DB 74 1B "           # test r11, r11; je resume
            "69 C0 B8 00 00 00 "        # imul eax, eax, 0B8h
            "4C 03 D8 "                 # add r11, rax
            "41 83 7B 54 00 75 0B "     # cmp dword ptr [r11+54h], 0; jne resume (Equipment count)
            "41 83 7B 24 00 7E 04 "     # cmp dword ptr [r11+24h], 0; jle resume (configured Places)
            "45 8B 73 24"               # mov r14d, [r11+24h]
        ))
        for offset, target in ((27, DEFINITION_COUNT), (36, DEFINITION_TABLE)):
            struct.pack_into("<i", code, offset, target - (base + offset + 4))
        return bytes(code) + near_jump(base + len(code), resume)

    entry = image.add_code(build, unwind_from=PRUNE_ROSTER)
    image.patch(PRUNE_ROSTER, expected, near_jump(PRUNE_ROSTER, entry).ljust(len(expected), b"\x90"))
