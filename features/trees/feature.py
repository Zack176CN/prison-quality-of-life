"""Skip creating a stump when a tree is felled and keep its timber drop."""

STUMP_FACTORY = 0x746036
CELL_CLEANUP = 0x746078


def apply(image):
    # The stock Tree handler initializes and inserts a TreeStump before clearing
    # a cell field. Resume at the cell write, before the separate log-drop path.
    expected_cleanup = bytes.fromhex("89 77 28 4C 8B 15 7E 18 61 00")
    if image.read(CELL_CLEANUP, len(expected_cleanup)) != expected_cleanup:
        raise ValueError("unexpected tree felling cleanup code")

    expected = bytes.fromhex("B9 2E 01 00 00 E8 C0 4B 09 00")
    displacement = CELL_CLEANUP - (STUMP_FACTORY + 2)
    jump = bytes((0xEB, displacement))
    image.patch(STUMP_FACTORY, expected, jump.ljust(len(expected), b"\x90"))
