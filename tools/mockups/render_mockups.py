#!/usr/bin/env python3
"""Render 1-bit, Lisa-style mockups of the 1000 Miles table, card set and dialogs.

The Lisa screen is 720x364 with pixels about 2/3 as wide as tall, so every picture is
written twice: pixel-exact (*.png) and stretched 2x wide by 3x tall (*_glass.png), which
is how it looks on the real tube.  Window chrome is approximate: the real frame comes
from the Lisa Window Manager.  Run:  python3 tools/mockups/render_mockups.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont, ImageOps

SCREEN_W, SCREEN_H = 720, 364
CARD_W, CARD_H = 54, 48          # 3:4 on glass once pixel aspect (2:3) is applied
BLACK, WHITE = 0, 255
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "mockups"))


def find_font():
    for path in (os.environ.get("FONT", ""),
                 "/System/Library/Fonts/Geneva.ttf",
                 "/System/Library/Fonts/Supplemental/Geneva.ttf",
                 "/Library/Fonts/Geneva.ttf"):
        if path and os.path.exists(path):
            return path
    sys.exit("Geneva.ttf not found; set FONT=/path/to/a.ttf")


FONT = find_font()


def font(size):
    return ImageFont.truetype(FONT, size)


F7, F8, F9, F10, F12, F16, F18 = (font(n) for n in (7, 8, 9, 10, 12, 16, 18))

# ---------------------------------------------------------------- text helpers


def text(d, xy, s, f, fill=BLACK, bold=False):
    d.text(xy, s, font=f, fill=fill)
    if bold:
        d.text((xy[0] + 1, xy[1]), s, font=f, fill=fill)


def text_w(s, f, bold=False):
    return int(f.getlength(s)) + (1 if bold else 0)


def ctext(d, cx, y, s, f, fill=BLACK, bold=False):
    text(d, (cx - text_w(s, f, bold) // 2, y), s, f, fill, bold)


def fit_font(s, max_w, sizes=(9, 8, 7)):
    for n in sizes:
        f = font(n)
        if text_w(s, f) <= max_w:
            return f
    return font(sizes[-1])


def wrap(s, f, max_w):
    lines, cur = [], ""
    for word in s.split():
        trial = (cur + " " + word).strip()
        if text_w(trial, f) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


# ---------------------------------------------------------------- icons
# Icons are drawn in a 100x100 "glass" space (square on the tube), supersampled 4x,
# then box-filtered down to the real pixel size (e.g. 36x24) and thresholded to 1 bit.
S = 4


def s(v):
    return int(round(v * S))


def pts(points):
    return [(s(x), s(y)) for x, y in points]


def star(cx, cy, big, small, n=5):
    out = []
    for i in range(n * 2):
        r = big if i % 2 == 0 else small
        a = -math.pi / 2 + i * math.pi / n
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def circle(d, cx, cy, r, **kw):
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], **kw)


def draw_icon(name):
    im = Image.new("L", (100 * S, 100 * S), WHITE)
    d = ImageDraw.Draw(im)
    if name == "go":                      # traffic light, bottom (green) lamp lit
        d.rounded_rectangle([s(32), s(2), s(68), s(98)], radius=s(9), outline=BLACK, width=s(7))
        circle(d, 50, 22, 9, outline=BLACK, width=s(4))
        circle(d, 50, 50, 9, outline=BLACK, width=s(4))
        circle(d, 50, 78, 10, fill=BLACK)
    elif name == "stop":                  # octagon with a bar
        d.polygon(pts([(50 + 47 * math.cos(math.radians(22.5 + 45 * k)),
                        50 + 47 * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]), fill=BLACK)
        d.rectangle([s(16), s(41), s(84), s(59)], fill=WHITE)
    elif name == "accident":              # car with a crash burst
        d.rounded_rectangle([s(4), s(52), s(76), s(76)], radius=s(6), fill=BLACK)
        d.polygon(pts([(18, 52), (30, 32), (58, 32), (68, 52)]), fill=BLACK)
        circle(d, 24, 78, 11, fill=BLACK, outline=WHITE, width=s(4))
        circle(d, 58, 78, 11, fill=BLACK, outline=WHITE, width=s(4))
        d.polygon(pts(star(80, 22, 20, 9, 8)), fill=BLACK, outline=WHITE)
    elif name == "nogas":                 # fuel pump
        d.rectangle([s(14), s(8), s(56), s(90)], outline=BLACK, width=s(8))
        d.rectangle([s(23), s(18), s(47), s(42)], fill=BLACK)
        d.rectangle([s(6), s(88), s(64), s(97)], fill=BLACK)
        d.line(pts([(56, 30), (76, 30), (76, 66), (68, 76)]), fill=BLACK, width=s(7))
    elif name == "flat":                  # round tire, flattened where it meets the ground
        circle(d, 50, 44, 38, outline=BLACK, width=s(11))
        d.rectangle([0, s(74), 100 * S, 100 * S], fill=WHITE)         # cut the bottom off
        d.rectangle([s(26), s(70), s(74), s(77)], fill=BLACK)         # the flat contact edge
        d.rectangle([s(4), s(77), s(96), s(84)], fill=BLACK)          # the ground
        circle(d, 50, 44, 7, fill=BLACK)
    elif name in ("limit", "endlimit"):
        circle(d, 50, 50, 45, outline=BLACK, width=s(9))
        f = ImageFont.truetype(FONT, s(40))
        w = d.textlength("50", font=f)
        d.text((s(50) - w / 2, s(28)), "50", font=f, fill=BLACK)
        d.text((s(50) - w / 2 + s(2), s(28)), "50", font=f, fill=BLACK)
        if name == "endlimit":
            d.line(pts([(84, 16), (16, 84)]), fill=WHITE, width=s(17))
            d.line(pts([(84, 16), (16, 84)]), fill=BLACK, width=s(8))
    elif name == "repairs":               # open-end wrench: drawn flat, then turned 45 degrees
        w = Image.new("L", im.size, WHITE)
        wd = ImageDraw.Draw(w)
        wd.rounded_rectangle([s(14), s(43), s(68), s(57)], radius=s(5), fill=BLACK)   # handle
        wd.ellipse([s(2), s(36), s(26), s(64)], fill=BLACK)                          # ring end
        wd.ellipse([s(9), s(44), s(19), s(56)], fill=WHITE)
        wd.ellipse([s(52), s(24), s(96), s(76)], fill=BLACK)                         # jaw head
        wd.rectangle([s(72), s(40), s(100), s(60)], fill=WHITE)                      # U-shaped slot
        wd.ellipse([s(66), s(40), s(80), s(60)], fill=WHITE)
        im = w.rotate(45, resample=Image.BICUBIC, fillcolor=WHITE)
    elif name == "fuel":                  # jerry can
        d.rectangle([s(18), s(32), s(74), s(94)], outline=BLACK, width=s(8))
        d.polygon(pts([(58, 32), (58, 10), (84, 10), (84, 18), (70, 18), (70, 32)]), fill=BLACK)
        d.rectangle([s(28), s(18), s(48), s(32)], outline=BLACK, width=s(5))
        d.line(pts([(24, 40), (68, 88)]), fill=BLACK, width=s(5))
        d.line(pts([(68, 40), (24, 88)]), fill=BLACK, width=s(5))
    elif name == "spare":                 # round tire
        circle(d, 50, 50, 44, outline=BLACK, width=s(15))
        circle(d, 50, 50, 11, fill=BLACK)
        for k in range(4):
            a = math.radians(45 + 90 * k)
            circle(d, 50 + 24 * math.cos(a), 50 + 24 * math.sin(a), 4, fill=BLACK)
    elif name == "ace":                   # star
        d.polygon(pts(star(50, 54, 50, 21)), fill=BLACK)
    elif name == "tank":                  # big tank with a plus
        d.rounded_rectangle([s(4), s(26), s(80), s(78)], radius=s(20), outline=BLACK, width=s(8))
        d.rectangle([s(80), s(42), s(96), s(62)], fill=BLACK)
        d.rectangle([s(30), s(48), s(54), s(56)], fill=BLACK)
        d.rectangle([s(38), s(38), s(46), s(66)], fill=BLACK)
    elif name == "tough":                 # shield with a tire in it
        d.polygon(pts([(10, 6), (90, 6), (90, 50), (50, 97), (10, 50)]), outline=BLACK, width=s(8))
        circle(d, 50, 40, 20, outline=BLACK, width=s(8))
    elif name == "row":                   # diamond sign with an arrow
        d.polygon(pts([(50, 2), (98, 50), (50, 98), (2, 50)]), outline=BLACK, width=s(8))
        d.rectangle([s(44), s(44), s(56), s(78)], fill=BLACK)
        d.polygon(pts([(28, 48), (50, 22), (72, 48)]), fill=BLACK)
    elif name == "road":                  # converging road with a dashed centre line
        d.line(pts([(14, 98), (44, 4)]), fill=BLACK, width=s(9))
        d.line(pts([(86, 98), (56, 4)]), fill=BLACK, width=s(9))
        for y0, y1, hw in ((6, 22, 3), (34, 52, 4), (64, 90, 5)):
            d.rectangle([s(50 - hw), s(y0), s(50 + hw), s(y1)], fill=BLACK)
    return im


def icon_bitmap(name, w, h, invert=False):
    im = draw_icon(name).resize((w, h), Image.BOX)
    im = im.point(lambda p: WHITE if p > 175 else BLACK)
    if invert:
        im = ImageOps.invert(im)
    return im.convert("1", dither=Image.NONE)


# ---------------------------------------------------------------- the card set
# key -> (group, short caption on the card, full name for the legend, icon)
CARDS = {
    "d25": ("distance", "25", "25 Miles", "road"),
    "d50": ("distance", "50", "50 Miles", "road"),
    "d75": ("distance", "75", "75 Miles", "road"),
    "d100": ("distance", "100", "100 Miles", "road"),
    "d200": ("distance", "200", "200 Miles", "road"),
    "accident": ("hazard", "ACCIDENT", "Accident", "accident"),
    "nogas": ("hazard", "NO GAS", "Out of Gas", "nogas"),
    "flat": ("hazard", "FLAT TIRE", "Flat Tire", "flat"),
    "limit": ("hazard", "LIMIT 50", "Speed Limit", "limit"),
    "stop": ("hazard", "STOP", "Stop", "stop"),
    "repairs": ("remedy", "REPAIRS", "Repairs", "repairs"),
    "fuel": ("remedy", "GASOLINE", "Gasoline", "fuel"),
    "spare": ("remedy", "SPARE", "Spare Tire", "spare"),
    "endlimit": ("remedy", "END LIMIT", "End of Limit", "endlimit"),
    "go": ("remedy", "GO", "Go", "go"),
    "ace": ("safety", "ACE", "Ace Driver", "ace"),
    "tank": ("safety", "BIG TANK", "Big Tank", "tank"),
    "tough": ("safety", "TOUGH TIRE", "Tough Tires", "tough"),
    "row": ("safety", "RT OF WAY", "Right of Way", "row"),
}
GROUP_ORDER = [("Distance", ["d25", "d50", "d75", "d100", "d200"]),
               ("Hazards", ["accident", "nogas", "flat", "limit", "stop"]),
               ("Remedies", ["repairs", "fuel", "spare", "endlimit", "go"]),
               ("Safeties", ["ace", "tank", "tough", "row"])]


def card_back(label=True):
    im = Image.new("1", (CARD_W, CARD_H), WHITE)
    px = im.load()
    for y in range(CARD_H):
        for x in range(CARD_W):
            if (x + y) % 2 == 0:
                px[x, y] = BLACK
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, CARD_W - 1, CARD_H - 1], radius=3, outline=BLACK)
    d.rounded_rectangle([2, 2, CARD_W - 3, CARD_H - 3], radius=2, outline=WHITE)
    if label:
        d.rounded_rectangle([9, 16, CARD_W - 10, CARD_H - 17], radius=3, fill=WHITE, outline=BLACK)
        ctext(d, CARD_W // 2, 18, "1000", F8, bold=True)
    return im


def make_card(key):
    group, cap, _, icon = CARDS[key]
    im = Image.new("1", (CARD_W, CARD_H), WHITE)
    d = ImageDraw.Draw(im)
    cx = CARD_W // 2
    if group == "distance":
        d.rounded_rectangle([0, 0, CARD_W - 1, CARD_H - 1], radius=3, outline=BLACK)
        ctext(d, cx, 0, cap, F16, bold=True)
        im.paste(icon_bitmap("road", 38, 12), (8, 21))
        ctext(d, cx, 35, "MILES", F9)
    elif group == "hazard":
        d.rounded_rectangle([0, 0, CARD_W - 1, CARD_H - 1], radius=3, fill=BLACK)
        d.rounded_rectangle([2, 2, CARD_W - 3, CARD_H - 3], radius=2, outline=WHITE)
        im.paste(icon_bitmap(icon, 36, 24, invert=True), (9, 5))
        ctext(d, cx, 33, cap, fit_font(cap, CARD_W - 6), fill=WHITE)
    elif group == "remedy":
        d.rounded_rectangle([0, 0, CARD_W - 1, CARD_H - 1], radius=3, outline=BLACK)
        d.rounded_rectangle([3, 3, CARD_W - 4, CARD_H - 4], radius=2, outline=BLACK)
        im.paste(icon_bitmap(icon, 36, 24), (9, 6))
        ctext(d, cx, 33, cap, fit_font(cap, CARD_W - 10))
    else:                                 # safety: heavy frame and a black banner
        d.rounded_rectangle([0, 0, CARD_W - 1, CARD_H - 1], radius=3, outline=BLACK, width=2)
        im.paste(icon_bitmap(icon, 36, 24), (9, 4))
        d.rectangle([2, CARD_H - 15, CARD_W - 3, CARD_H - 3], fill=BLACK)
        ctext(d, cx, CARD_H - 14, cap, fit_font(cap, CARD_W - 8), fill=WHITE)
    return im


# ---------------------------------------------------------------- table drawing


def dashed_rect(d, x0, y0, x1, y1, dash=3):
    for x in range(x0, x1 + 1, dash * 2):
        for y in (y0, y1):
            d.line([x, y, min(x + dash - 1, x1), y], fill=BLACK)
    for y in range(y0, y1 + 1, dash * 2):
        for x in (x0, x1):
            d.line([x, y, x, min(y + dash - 1, y1)], fill=BLACK)


def empty_slot(im, d, x, y, label):
    dashed_rect(d, x, y, x + CARD_W - 1, y + CARD_H - 1)
    ctext(d, x + CARD_W // 2, y + CARD_H // 2 - 4, label, F8)


def highlight(d, x, y, w=CARD_W, h=CARD_H):
    for i in (3, 4, 5):
        d.rounded_rectangle([x - i, y - i, x + w - 1 + i, y + h - 1 + i], radius=4, outline=BLACK)


def new_screen():
    im = Image.new("1", (SCREEN_W, SCREEN_H), WHITE)
    px = im.load()
    for y in range(0, SCREEN_H, 2):          # light stipple desktop
        for x in range(0, SCREEN_W, 2):
            px[x, y] = BLACK
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SCREEN_W - 1, 15], fill=WHITE)
    d.line([0, 15, SCREEN_W, 15], fill=BLACK)
    for label, x in (("File", 14), ("Edit", 60), ("Game", 106)):
        text(d, (x, 2), label, F10, bold=(label == "Game"))
    text(d, (SCREEN_W - 66, 2), "10:42 AM", F10)
    return im, d


def draw_window(im, d, title="1000 Miles"):
    x0, y0, x1, y1 = 40, 24, 679, 350
    d.rectangle([x0 + 4, y0 + 4, x1 + 4, y1 + 4], fill=BLACK)      # drop shadow
    d.rectangle([x0, y0, x1, y1], fill=WHITE, outline=BLACK)
    d.line([x0, y0 + 16, x1, y0 + 16], fill=BLACK)
    for y in range(y0 + 3, y0 + 14, 2):                            # title-bar stripes
        d.line([x0 + 4, y, x1 - 4, y], fill=BLACK)
    tw = text_w(title, F10, True)
    d.rectangle([360 - tw // 2 - 8, y0 + 2, 360 + tw // 2 + 8, y0 + 14], fill=WHITE)
    ctext(d, 360, y0 + 3, title, F10, bold=True)
    return 41, 41                                                  # content origin


def mile_bar(d, x, y, miles, w=300):
    d.rectangle([x, y, x + w, y + 9], outline=BLACK)
    fill = int((w - 2) * miles / 1000)
    d.rectangle([x + 1, y + 1, x + 1 + fill, y + 8], fill=BLACK)
    for k in range(1, 10):
        tx = x + int(w * k / 10)
        d.line([tx, y + 10, tx, y + 12], fill=BLACK)


def draw_side(im, d, ox, oy, y, name, miles, battle, speed, safeties, last_miles,
              backs=0, hl=()):
    text(d, (ox + 8, oy + y), name, F10, bold=True)
    mile_bar(d, ox + 130, oy + y + 1, miles)
    text(d, (ox + 442, oy + y), "%d / 1000 mi" % miles, F10)
    cy = oy + y + 17

    def put(slot, x, key, empty):
        px = ox + x
        if key:
            im.paste(make_card(key), (px, cy))
        else:
            empty_slot(im, d, px, cy, empty)
        if slot in hl:
            highlight(d, px, cy)

    put("battle", 8, battle, "BATTLE")
    put("speed", 68, speed, "SPEED")
    for i, (slot_key, empty) in enumerate((("ace", "ACE"), ("tank", "TANK"),
                                           ("tough", "TIRES"), ("row", "RT WAY"))):
        put("s_" + slot_key, 136 + 58 * i, slot_key if slot_key in safeties else None, empty)
    put("miles", 380, last_miles, "MILES")
    for i in range(backs):
        im.paste(card_back(label=(i == backs - 1)), (ox + 450 + 22 * i, cy))


def draw_pile(im, d, ox, oy, x, y, count):
    for k in (2, 1):
        im.paste(card_back(label=False), (ox + x + k * 2, oy + y - k * 2))
    im.paste(card_back(label=False), (ox + x, oy + y))
    d.rounded_rectangle([ox + x + 9, oy + y + 15, ox + x + CARD_W - 10, oy + y + CARD_H - 16],
                        radius=3, fill=WHITE, outline=BLACK)
    ctext(d, ox + x + CARD_W // 2, oy + y + 17, str(count), F12, bold=True)


def build_table(coup=False):
    im, d = new_screen()
    ox, oy = draw_window(im, d)
    draw_side(im, d, ox, oy, 3, "COMPUTER", 450, "go", "limit", ("tank",), "d75", backs=6)
    # middle band: draw pile, discard pile, scoreboard
    draw_pile(im, d, ox, oy, 8, 76, 38)
    im.paste(make_card("stop"), (ox + 68, oy + 76))
    text(d, (ox + 136, oy + 74), "Hand 3          Match to 5,000", F10, bold=True)
    text(d, (ox + 136, oy + 90), "You  1,150      Computer  975", F10)
    text(d, (ox + 136, oy + 106), "Draw pile 38 cards.  Top discard: Stop.", F9)
    draw_side(im, d, ox, oy, 128, "YOU", 275, "accident", None, ("row",), "d100",
              hl=() if coup else ("battle",))
    # hand: the last card (Repairs) is selected and lifted
    hand = ["d25", "d100", "d50", "nogas", "go", "ace", "repairs"]
    for i, key in enumerate(hand):
        lift = 8 if (key == "repairs" and not coup) else 0
        im.paste(make_card(key), (ox + 8 + 62 * i, oy + 214 - lift))
    d.line([ox, oy + 274, ox + 637, oy + 274], fill=BLACK)
    if coup:
        text(d, (ox + 8, oy + 279), "The computer played Accident on you.", F10)
        text(d, (ox + 8, oy + 293), "Waiting for your decision...", F10)
        text(d, (ox + 520, oy + 279), "Computer's move", F10, bold=True)
    else:
        text(d, (ox + 8, oy + 279), "Repairs selected: click the highlighted pile to fix your accident,", F10)
        text(d, (ox + 8, oy + 293), "or click the discard pile to throw it away.", F10)
        text(d, (ox + 540, oy + 279), "Your turn", F10, bold=True)
    return im


def caution_icon(d, x, y):
    d.polygon([(x + 18, y), (x + 36, y + 30), (x, y + 30)], outline=BLACK)
    d.polygon([(x + 18, y + 2), (x + 34, y + 29), (x + 2, y + 29)], outline=BLACK)
    d.rectangle([x + 17, y + 10, x + 19, y + 20], fill=BLACK)
    d.rectangle([x + 17, y + 23, x + 19, y + 25], fill=BLACK)


def build_coup_dialog():
    im = build_table(coup=True)
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = 130, 96, 590, 264
    d.rectangle([x0 + 5, y0 + 5, x1 + 5, y1 + 5], fill=BLACK)
    d.rectangle([x0, y0, x1, y1], fill=WHITE)
    d.rectangle([x0, y0, x1, y1], outline=BLACK, width=3)
    caution_icon(d, x0 + 14, y0 + 14)
    im.paste(make_card("accident"), (x0 + 62, y0 + 14))
    im.paste(make_card("ace"), (x0 + 124, y0 + 14))
    text(d, (x0 + 96, y0 + 66), "played on you", F8)
    tx = x0 + 196
    text(d, (tx, y0 + 12), "Accident!  You are holding the Ace Driver.", F10, bold=True)
    body = ("Play it now for a Coup Fourré? The accident is cancelled, you keep "
            "moving without needing a Go, you draw a replacement card and take "
            "your turn next.")
    for i, line in enumerate(wrap(body, F10, x1 - tx - 14)):
        text(d, (tx, y0 + 32 + 14 * i), line, F10)
    # buttons: the default button gets a heavy border
    d.rounded_rectangle([x0 + 150, y1 - 38, x0 + 250, y1 - 12], radius=6, outline=BLACK, width=3)
    ctext(d, x0 + 200, y1 - 31, "Play it!", F10, bold=True)
    d.rounded_rectangle([x0 + 280, y1 - 38, x0 + 380, y1 - 12], radius=6, outline=BLACK)
    ctext(d, x0 + 330, y1 - 31, "No thanks", F10)
    return im


def build_gallery():
    im = Image.new("1", (SCREEN_W, SCREEN_H), WHITE)
    d = ImageDraw.Draw(im)
    text(d, (10, 4), "1000 MILES  -  card set (actual size: %d x %d pixels)" % (CARD_W, CARD_H),
         F10, bold=True)
    d.line([0, 20, SCREEN_W, 20], fill=BLACK)
    y = 28
    for group, keys in GROUP_ORDER:
        text(d, (10, y + 18), group, F10, bold=True)
        for i, key in enumerate(keys):
            x = 100 + 112 * i
            im.paste(make_card(key), (x, y))
            ctext(d, x + CARD_W // 2, y + CARD_H + 2, CARDS[key][2], F9)
        if group == "Safeties":
            x = 100 + 112 * 4
            im.paste(card_back(), (x, y))
            ctext(d, x + CARD_W // 2, y + CARD_H + 2, "Card back", F9)
        y += 80
    return im


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".png"))
    glass = im.resize((im.width * 2, im.height * 3), Image.NEAREST)
    glass.save(os.path.join(OUT, name + "_glass.png"))
    print("wrote", name, ".png and _glass.png")


if __name__ == "__main__":
    save(build_table(), "table_mid_game")
    save(build_coup_dialog(), "coup_fourre_dialog")
    save(build_gallery(), "card_set")
