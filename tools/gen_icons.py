#!/usr/bin/env python3
"""Generate src/MILES-ICONS.TEXT from the approved card artwork (tools/mockups/render_mockups.py).

Each icon becomes rows of three 16-bit words (a QuickDraw bitmap with a 6-byte row, 1 = black, leftmost
pixel in the top bit), written as hex text so the Pascal unit needs no array constants.

  python3 tools/gen_icons.py            write the unit
  python3 tools/gen_icons.py --check    fail if the committed unit is out of date or does not decode
                                        back to exactly the pixels of the artwork
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "mockups"))
from render_mockups import icon_bitmap          # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "src", "MILES-ICONS.TEXT"))
W = 36
CHUNK = 72                                       # hex characters per Pascal string constant (18 words)
# (index, artwork name, rows).  The order is part of the Pascal interface (IconOf in the unit).
ICONS = [(1, "accident", 24), (2, "nogas", 24), (3, "flat", 24), (4, "limit", 24), (5, "stop", 24),
         (6, "repairs", 24), (7, "fuel", 24), (8, "spare", 24), (9, "endlimit", 24), (10, "go", 24),
         (11, "ace", 24), (12, "tank", 24), (13, "tough", 24), (14, "row", 24), (15, "road", 12)]


def black(img, x, y):
    return img.getpixel((x, y)) == 0


def words_of(img, rows):
    out = []
    for y in range(rows):
        row = [0, 0, 0]
        for x in range(W):
            if black(img, x, y):
                row[x // 16] |= 1 << (15 - x % 16)
        out.extend(row)
    return out


def hex_of(words):
    return "".join("%04X" % w for w in words)


def chunks(text):
    return [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)]


def build():
    consts, loads, bits = [], [], []
    for index, name, rows in ICONS:
        img = icon_bitmap(name, W, rows)
        words = words_of(img, rows)
        n_black = sum(1 for y in range(rows) for x in range(W) if black(img, x, y))
        bits.append((index, n_black))
        pieces = chunks(hex_of(words))
        branch = []
        for k, piece in enumerate(pieces):
            cname = "hx%02d%s" % (index, "abcd"[k])
            consts.append("  %s = '%s';" % (cname, piece))
            branch.append("DecodeChunk(%s, %d, w)" % (cname, k * 18))
        loads.append((index, branch))
    text = HEADER
    text += "const\n  NumIcons    = 15;\n  IconW       = 36;\n  IconH       = 24;       { rows of a card icon }\n"
    text += "  RoadH       = 12;       { rows of the road icon used on distance cards }\n"
    text += "  IconRowBytes = 6;       { 3 words per row }\n  IconWords   = 72;       { words in the largest icon }\n\n"
    text += "type\n  IconBuf = array[0..71] of integer;\n  HexChunk = string[72];\n\n"
    text += MIDDLE
    text += "const\n" + "\n".join(consts) + "\n\n"
    text += "function IconRows(icon: integer): integer;\nbegin\n  if icon = NumIcons then IconRows := RoadH\n  else IconRows := IconH\nend;\n\n"
    text += """function HexVal(c: char): integer;
begin
  HexVal := 0;
  if (c >= '0') and (c <= '9') then HexVal := ord(c) - ord('0');
  if (c >= 'A') and (c <= 'F') then HexVal := ord(c) - ord('A') + 10
end;

{ Decode up to 18 words of hex text into w, starting at word index at. }
procedure DecodeChunk(s: HexChunk; at: integer; var w: IconBuf);
var i, j: integer; v: longint;
begin
  for i := 0 to (length(s) div 4) - 1 do begin
    v := 0;
    for j := 1 to 4 do
      v := v * 16 + HexVal(s[i * 4 + j]);
    if v >= 32768 then v := v - 65536;
    w[at + i] := v
  end
end;

"""
    text += "procedure LoadIcon(icon: integer; var w: IconBuf);\nvar i: integer;\nbegin\n  for i := 0 to IconWords - 1 do w[i] := 0;\n"
    first = True
    for index, branch in loads:
        text += "  %s icon = %d then begin\n" % ("if" if first else "else if", index)
        text += "".join("    %s%s\n" % (b, ";" if i < len(branch) - 1 else "") for i, b in enumerate(branch))
        text += "  end%s\n" % ("" if index != loads[-1][0] else "")
        first = False
    text += "end;\n\n"
    text += "{ Black pixels the generator drew in each icon: lets the tests prove the decoding is exact. }\n"
    text += "function IconBits(icon: integer): integer;\nbegin\n  IconBits := 0;\n"
    for index, n in bits:
        text += "  if icon = %d then IconBits := %d;\n" % (index, n)
    text = text.rstrip(";\n") + "\nend;\n"
    text = text.replace("IconBits := " + str(bits[-1][1]) + "\nend;", "IconBits := " + str(bits[-1][1]) + "\nend;")
    text += "\n" + TAIL
    return text


HEADER = """{ MILES-ICONS.TEXT -- the card pictures, as 1-bit bitmaps stored in hex text.  GENERATED   }
{ by tools/gen_icons.py from the approved artwork: do not edit by hand; run `make icons`.     }
{ Portable: tested on the Mac, then drawn on the Lisa with CopyBits.  Each icon is rows of    }
{ three 16-bit words, one bit per pixel, 1 = black, leftmost pixel in the top bit (a          }
{ QuickDraw bitmap with a 6-byte row).                                                        }
unit MilesIcons;

interface

uses (*$U MILES/LOGIC.OBJ *) MilesLogic;

"""
MIDDLE = """function  IconOf(k: CardKind): integer;
function  IconRows(icon: integer): integer;
procedure LoadIcon(icon: integer; var w: IconBuf);
function  IconBits(icon: integer): integer;

implementation

{ Which icon a card shows: 1 accident, 2 out of gas, 3 flat, 4 limit, 5 stop, 6 repairs, 7 gas,  }
{ 8 spare, 9 end of limit, 10 go, 11 ace, 12 tank, 13 tough tires, 14 right of way, 15 the road.  }
function IconOf(k: CardKind): integer;
begin
  IconOf := 0;
  if IsDistance(k) then IconOf := 15;
  if k = hzAccident then IconOf := 1;
  if k = hzOutOfGas then IconOf := 2;
  if k = hzFlat then IconOf := 3;
  if k = hzLimit then IconOf := 4;
  if k = hzStop then IconOf := 5;
  if k = rmRepairs then IconOf := 6;
  if k = rmGas then IconOf := 7;
  if k = rmSpare then IconOf := 8;
  if k = rmEndLimit then IconOf := 9;
  if k = rmGo then IconOf := 10;
  if k = sfAce then IconOf := 11;
  if k = sfTank then IconOf := 12;
  if k = sfPunct then IconOf := 13;
  if k = sfRoW then IconOf := 14
end;

"""
TAIL = "end.\n"


def decode_back(text, index, rows):
    """Re-read the hex constants of one icon out of the generated text (independent of the Pascal decoder)."""
    import re
    hexes = "".join(re.findall(r"hx%02d[a-d] = '([0-9A-F]*)';" % index, text))
    words = [int(hexes[i:i + 4], 16) for i in range(0, len(hexes), 4)]
    return words


def check(text):
    ok = True
    for index, name, rows in ICONS:
        img = icon_bitmap(name, W, rows)
        if decode_back(text, index, rows) != words_of(img, rows):
            print("icon %d (%s): the text does not decode to the artwork" % (index, name))
            ok = False
    return ok


def main(argv):
    text = build()
    if "--check" in argv:
        current = open(OUT).read() if os.path.exists(OUT) else ""
        good = check(text)
        if current != text:
            print("src/MILES-ICONS.TEXT is out of date: run `make icons`")
            good = False
        return 0 if good else 1
    with open(OUT, "w") as handle:
        handle.write(text)
    print("wrote", OUT, "(%d lines)" % text.count("\n"))
    return 0 if check(text) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
