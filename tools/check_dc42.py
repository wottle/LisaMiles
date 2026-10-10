#!/usr/bin/env python3
"""Check a Lisa floppy image in DiskCopy 4.2 (.dc42) format before it is released.

  python3 tools/check_dc42.py dist/1000-miles.dc42

Verifies the header, the data and tag sizes (400K or 800K Sony), the two DiskCopy checksums and the file
length.  Prints a short summary and exits 0 when everything is consistent, 1 otherwise.
"""
import struct
import sys

SIZES = {800: "400K", 1600: "800K"}          # sectors -> kind; each sector is 512 data + 12 tag bytes


def checksum(buf):
    """DiskCopy 4.2 checksum: sum of big-endian 16-bit words, rotating right one bit after each word."""
    total = 0
    for i in range(0, len(buf) - 1, 2):
        total = (total + ((buf[i] << 8) | buf[i + 1])) & 0xFFFFFFFF
        total = ((total >> 1) | ((total & 1) << 31)) & 0xFFFFFFFF
    return total


def check_file(path):
    """Return (ok, problems, info)."""
    with open(path, "rb") as handle:
        blob = handle.read()
    problems = []
    info = {}
    if len(blob) < 84:
        return False, ["file is shorter than a DiskCopy header"], info
    name_len = blob[0]
    if name_len > 63:
        problems.append("disk name length %d is not valid" % name_len)
    data_size, tag_size, data_sum, tag_sum = struct.unpack(">IIII", blob[64:80])
    magic = struct.unpack(">H", blob[82:84])[0]
    info.update(name=blob[1:1 + min(name_len, 63)].decode("mac-roman", "replace"), data_size=data_size,
                tag_size=tag_size)
    if magic != 0x0100:
        problems.append("magic number is 0x%04x, expected 0x0100" % magic)
    sectors = data_size // 512
    kind = SIZES.get(sectors)
    info["kind"] = kind
    if kind is None or data_size % 512:
        problems.append("data size %d is not a 400K or 800K Sony image" % data_size)
    elif tag_size != sectors * 12:
        problems.append("tag size %d does not match %d sectors" % (tag_size, sectors))
    expected_len = 84 + data_size + tag_size
    if len(blob) != expected_len:
        problems.append("length is %d bytes, header says %d" % (len(blob), expected_len))
    else:
        data = blob[84:84 + data_size]
        tags = blob[84 + data_size:84 + data_size + tag_size]
        if checksum(data) != data_sum:
            problems.append("data checksum is %08x, header says %08x" % (checksum(data), data_sum))
        if checksum(tags[12:]) != tag_sum:
            problems.append("tag checksum is %08x, header says %08x" % (checksum(tags[12:]), tag_sum))
    return not problems, problems, info


def main(argv):
    if len(argv) != 1:
        print(__doc__)
        return 2
    ok, problems, info = check_file(argv[0])
    print("%s: %s, name %r, %s data bytes, %s tag bytes" % (
        argv[0], info.get("kind") or "unknown size", info.get("name"), info.get("data_size"), info.get("tag_size")))
    for p in problems:
        print("  PROBLEM:", p)
    print("OK" if ok else "NOT OK")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
