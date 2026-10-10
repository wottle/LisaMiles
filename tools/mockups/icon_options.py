#!/usr/bin/env python3
"""Draw candidate 48x32 one-bit tool icons for 1000 Miles and save a contact sheet.

  python3 tools/mockups/icon_options.py            -> docs/mockups/icon_options.png

Each icon is a 48x32 image (1 = black).  The mask is derived the usual way: everything
that is not reachable from the border through white pixels is part of the icon.
The sheet shows each icon with the Lisa's tall pixels (about 2 wide : 3 high) at the
left and the same icon at 1:1 on a light-gray "desktop" on the right.
"""
import os
import sys
from collections import deque
from PIL import Image, ImageDraw, ImageFont

W, H = 48, 32

# 3x5 digit and letter glyphs, enough for the numerals and a few labels
GLYPHS = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "L": ["100", "100", "100", "100", "111"],
    "E": ["111", "100", "110", "100", "111"],
    "S": ["111", "100", "111", "001", "111"],
}


def blank():
    return Image.new("1", (W, H), 1)          # 1 = white in PIL mode "1"


def put_text(img, x, y, text, ink=0, gap=1):
    px = img.load()
    for ch in text:
        g = GLYPHS[ch]
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit == "1":
                    px[x + gx, y + gy] = ink
        x += 3 + gap
    return x


def text_width(text, gap=1):
    return len(text) * 3 + (len(text) - 1) * gap


def option_a():
    """Three cards fanned, the front one reading 1000."""
    img = blank()
    d = ImageDraw.Draw(img)
    for i, x in enumerate((3, 9, 15)):
        top = 2 + (2 - i) * 1
        d.rectangle([x, top, x + 20, top + 25], outline=0, fill=1)
    put_text(img, 15 + 3, 7, "1000")
    # a tiny road line under the number on the front card
    d.line([18, 20, 32, 20], fill=0)
    d.line([19, 22, 31, 22], fill=0)
    d.point([24, 21], fill=0)
    return img


def option_b():
    """An odometer reading 1000 above a road."""
    img = blank()
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, 45, 17], outline=0, fill=1)
    d.rectangle([3, 3, 44, 16], outline=0, fill=1)
    for i, ch in enumerate("01000"):
        x = 5 + i * 8
        d.rectangle([x, 5, x + 6, 14], outline=0, fill=1)
        put_text(img, x + 2, 7, ch if ch != "0" or i else "0")
    # the road, in perspective, under it
    d.polygon([(10, 31), (38, 31), (28, 21), (20, 21)], outline=0, fill=1)
    d.line([24, 30, 24, 28], fill=0)
    d.line([24, 26, 24, 25], fill=0)
    return img


def option_c():
    """A milestone marker: the original 'thousand milestones'."""
    img = blank()
    d = ImageDraw.Draw(img)
    d.pieslice([13, 1, 35, 23], 180, 360, outline=0, fill=1)
    d.rectangle([13, 12, 34, 29], outline=0, fill=1)
    d.line([13, 12, 34, 12], fill=1)
    d.arc([13, 1, 35, 23], 180, 360, fill=0)
    d.line([13, 12, 13, 29], fill=0)
    d.line([34, 12, 34, 29], fill=0)
    d.line([13, 29, 34, 29], fill=0)
    put_text(img, 16, 9, "1000")
    put_text(img, 20, 18, "MI")
    d.line([4, 30, 43, 30], fill=0)
    d.line([4, 31, 43, 31], fill=0)
    return img


def option_d():
    """A car in side view with speed lines."""
    img = blank()
    d = ImageDraw.Draw(img)
    d.polygon([(10, 20), (13, 12), (28, 12), (33, 20)], outline=0, fill=1)   # cabin
    d.rectangle([7, 19, 40, 25], outline=0, fill=1)                         # body
    d.rectangle([15, 14, 19, 18], outline=0, fill=0)                        # windows
    d.rectangle([22, 14, 27, 18], outline=0, fill=0)
    for cx in (14, 33):
        d.ellipse([cx - 4, 22, cx + 4, 30], outline=0, fill=0)
        d.ellipse([cx - 1, 25, cx + 1, 27], outline=0, fill=1)
    for y, x1 in ((16, 5), (20, 3), (24, 5)):
        d.line([0, y, x1, y], fill=0)
    put_text(img, 33, 3, "1000")
    return img


def option_e():
    """A speedometer-style gauge reading toward 1000."""
    img = blank()
    d = ImageDraw.Draw(img)
    d.pieslice([6, 4, 41, 39], 180, 360, outline=0, fill=1)
    d.pieslice([9, 7, 38, 36], 180, 360, outline=0, fill=1)
    d.rectangle([6, 21, 41, 22], outline=1, fill=1)
    d.arc([6, 4, 41, 39], 180, 360, fill=0)
    d.line([6, 21, 41, 21], fill=0)
    # ticks
    ticks = [(8, 20, 11, 19), (11, 13, 14, 15), (17, 8, 18, 11), (24, 6, 24, 9),
             (30, 8, 29, 11), (36, 13, 33, 15), (40, 20, 37, 19)]
    for x0, y0, x1, y1 in ticks:
        d.line([x0, y0, x1, y1], fill=0)
    d.line([24, 20, 33, 12], fill=0)          # needle
    d.ellipse([22, 18, 26, 22], fill=0)
    put_text(img, 16, 25, "1000")
    return img


OPTIONS = [
    ("A  card fan", option_a),
    ("B  odometer + road", option_b),
    ("C  milestone", option_c),
    ("D  car + speed lines", option_d),
    ("E  gauge", option_e),
]


def silhouette(img):
    """Mask: everything not reachable from the border through white pixels."""
    px = img.load()
    seen = [[False] * W for _ in range(H)]
    q = deque()
    for x in range(W):
        for y in (0, H - 1):
            if px[x, y] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if px[x, y] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < W and 0 <= ny < H and px[nx, ny] and not seen[ny][nx]:
                seen[ny][nx] = True
                q.append((nx, ny))
    mask = Image.new("1", (W, H), 0)
    mp = mask.load()
    for y in range(H):
        for x in range(W):
            mp[x, y] = 0 if seen[y][x] else 1   # 1 = opaque (part of the icon)
    return mask


def lisa_scale(img, sx=6, sy=9):
    """Show the pixels as the Lisa does: taller than wide."""
    return img.convert("L").resize((W * sx, H * sy), Image.NEAREST)


def sheet(path):
    sx, sy = 6, 9
    cell_w, cell_h = W * sx + 30, H * sy + 60
    out = Image.new("L", (cell_w * len(OPTIONS), cell_h + 130), 255)
    d = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
    except OSError:
        font = ImageFont.load_default()
    for i, (name, fn) in enumerate(OPTIONS):
        img = fn()
        x0 = i * cell_w + 15
        d.text((x0, 8), name, fill=0, font=font)
        out.paste(lisa_scale(img, sx, sy), (x0, 34))
        # 1:1 preview on a light desktop with the mask applied
        mask = silhouette(img)
        desk = Image.new("L", (64, 48), 210)
        tile = Image.new("L", (W, H), 255)
        ip, tp = img.load(), tile.load()
        for y in range(H):
            for x in range(W):
                tp[x, y] = 0 if not ip[x, y] else 255
        desk.paste(tile, (8, 8), mask.convert("L").point(lambda v: 255 if v else 0))
        desk = desk.resize((64 * 2, 48 * 3), Image.NEAREST)
        out.paste(desk, (x0, 34 + H * sy + 12))
    out.save(path)
    for name, fn in OPTIONS:
        fn().save(os.path.join(os.path.dirname(path), "icon_" + name[0].lower() + ".png"))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, "..", "..", "docs", "mockups", "icon_options.png")
    sheet(os.path.abspath(target))
    print("wrote", os.path.abspath(target))
