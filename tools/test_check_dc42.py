#!/usr/bin/env python3
"""Tests for tools/check_dc42.py using small synthetic DiskCopy 4.2 images."""
import os
import struct
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_dc42 as c  # noqa: E402


def make_image(sectors=800, name=b"", corrupt_data=False, wrong_len=False):
    data = bytes((i * 7) & 0xFF for i in range(sectors * 512))
    tags = bytes((i * 3) & 0xFF for i in range(sectors * 12))
    header = bytearray(84)
    header[0] = len(name)
    header[1:1 + len(name)] = name
    header[64:80] = struct.pack(">IIII", len(data), len(tags), c.checksum(data), c.checksum(tags[12:]))
    header[80] = 0 if sectors == 800 else 1
    header[81] = 0x02 if sectors == 800 else 0x22
    header[82:84] = struct.pack(">H", 0x0100)
    body = bytearray(data)
    if corrupt_data:
        body[100] ^= 0xFF
    out = bytes(header) + bytes(body) + tags
    return out[:-5] if wrong_len else out


class CheckDc42(unittest.TestCase):
    def check(self, blob):
        with tempfile.NamedTemporaryFile(suffix=".dc42", delete=False) as f:
            f.write(blob)
        try:
            return c.check_file(f.name)
        finally:
            os.unlink(f.name)

    def test_good_400k_image(self):
        ok, problems, info = self.check(make_image())
        self.assertTrue(ok, problems)
        self.assertEqual(info["kind"], "400K")

    def test_good_800k_image(self):
        ok, problems, info = self.check(make_image(sectors=1600))
        self.assertTrue(ok, problems)
        self.assertEqual(info["kind"], "800K")

    def test_corrupt_data_is_caught(self):
        ok, problems, _ = self.check(make_image(corrupt_data=True))
        self.assertFalse(ok)
        self.assertTrue(any("data checksum" in p for p in problems), problems)

    def test_truncated_file_is_caught(self):
        ok, problems, _ = self.check(make_image(wrong_len=True))
        self.assertFalse(ok)
        self.assertTrue(any("length" in p for p in problems), problems)

    def test_not_a_diskcopy_file(self):
        ok, problems, _ = self.check(b"hello" * 100)
        self.assertFalse(ok)

    def test_checksum_matches_a_known_value(self):
        # one word 0x0001: sum = 1, rotate right -> 0x80000000
        self.assertEqual(c.checksum(b"\x00\x01"), 0x80000000)


if __name__ == "__main__":
    unittest.main()
