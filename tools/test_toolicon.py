#!/usr/bin/env python3
"""Checks for tools/gen_toolicon.py: the {T202}icon file layout and the Pascal program that writes it."""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "mockups"))
import gen_toolicon as g  # noqa: E402

HEADER = bytes.fromhex("0003000000020030" "0000ffe000300020" "018a000000200000" "000c")
TRAILER = bytes.fromhex("0000003000600090" "00c0003000300030" "0030ffff")


def plane(data, off):
    rows = []
    for r in range(32):
        start = 26 + 24 * r + off
        rows.append(data[start:start + 6])
    return rows


class ToolIcon(unittest.TestCase):
    def setUp(self):
        self.data = g.build_icon()

    def test_size_and_frame(self):
        self.assertEqual(len(self.data), 814)
        self.assertEqual(self.data[:26], HEADER)
        self.assertEqual(self.data[26 + 768:], TRAILER)

    def test_checkerboard_plane_alternates(self):
        for r, row in enumerate(plane(self.data, 18)):
            self.assertEqual(row, bytes([0xAA if r % 2 == 0 else 0x55]) * 6, "row %d" % r)

    def test_layers_are_the_gauge_design(self):
        picture, overlay, area = g.gauge_planes()
        self.assertEqual(plane(self.data, 6), picture)     # layer B: the picture, drawn black
        self.assertEqual(plane(self.data, 12), overlay)    # layer C: white overlay when selected
        if g.SOLID_AREA:
            area = [b'\xff' * 6] * g.H                  # layer A is the whole box
        self.assertEqual(plane(self.data, 0), area)        # layer A: the click area

    def test_gauge_is_a_dark_face_with_light_markings_and_black_digits(self):
        picture, overlay, area = g.gauge_planes()

        def bit(rows, x, y):
            return bool(rows[y][x // 8] & (0x80 >> (x % 8)))

        dark = sum(bit(picture, x, y) for y in range(21) for x in range(48))
        self.assertGreater(dark, 250, "the gauge face is mostly dark")
        self.assertTrue(any(bit(picture, x, y) for y in range(25, 32) for x in range(16, 34)),
                        "the 1000 below the gauge is black")
        light = sum(not bit(picture, x, y) and bit(area, x, y) for y in range(21) for x in range(48))
        self.assertGreater(light, 40, "tick marks and arcs are left light inside the face")

    def test_overlay_is_the_whole_silhouette(self):
        picture, overlay, area = g.gauge_planes()
        self.assertEqual(overlay, area, "the placeholder left while dragging is the full silhouette")
        for rp, ro in zip(picture, overlay):
            for p_, o_ in zip(rp, ro):
                self.assertEqual(p_ & ~o_ & 0xFF, 0, "every black pixel is inside the placeholder (else it is left behind)")

    def test_pascal_program_embeds_exactly_these_bytes(self):
        text = g.pascal_program(self.data)
        hexes = re.findall(r"Put\((\d+), '([0-9A-F]+)'\)", text)
        rebuilt = b"".join(bytes.fromhex(h) for _, h in hexes)
        self.assertEqual(rebuilt, self.data)
        self.assertIn("'{T202}icon'", text)
        for line in text.split("\n"):
            self.assertLessEqual(len(line), 105, line)
        self.assertNotRegex(text.split("BEGIN")[0].replace("'{T202}icon'", ""), r"\{[^}]*\{")


if __name__ == "__main__":
    unittest.main()
