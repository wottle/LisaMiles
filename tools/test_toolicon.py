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

    def test_image_and_mask_are_the_gauge(self):
        image, mask = g.gauge_planes()
        self.assertEqual(plane(self.data, 12), image)
        self.assertEqual(plane(self.data, 6), mask)
        black = sum(bin(b).count("1") for row in image for b in row)
        solid = sum(bin(b).count("1") for row in mask for b in row)
        self.assertTrue(100 < black < solid < 48 * 32 // 2 + 200, (black, solid))

    def test_every_image_pixel_is_inside_the_mask(self):
        image, mask = g.gauge_planes()
        for ri, rm in zip(image, mask):
            for a, b in zip(ri, rm):
                self.assertEqual(a & ~b & 0xFF, 0)

    def test_click_area_is_the_mask(self):
        _, mask = g.gauge_planes()
        self.assertEqual(plane(self.data, 0), mask)

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
