program test_ui;

uses TestKit, MilesLayout;

{ ---------------- layout ---------------- }

function Inside(var b: Box): boolean;
begin
  Inside := (b.left >= 0) and (b.top >= 0) and (b.right <= ContentW) and (b.bottom <= ContentH)
end;

function Overlap(var a, b: Box): boolean;
begin
  Overlap := (a.left < b.right) and (b.left < a.right) and (a.top < b.bottom) and (b.top < a.bottom)
end;

procedure TestLayoutGeometry;
var b, c: Box; i, j, s, t: integer; ok: boolean;
begin
  ok := true;
  for i := 1 to 7 do begin
    HandBox(i, false, b); if not Inside(b) then ok := false;
    HandBox(i, true, b); if not Inside(b) then ok := false
  end;
  for s := 0 to 1 do
    for t := 0 to NumSlots - 1 do begin
      SlotBox(s, t, b); if not Inside(b) then ok := false
    end;
  for i := 1 to 7 do begin OppHandBox(i, b); if not Inside(b) then ok := false end;
  DrawPileBox(b); if not Inside(b) then ok := false;
  DiscardBox(b); if not Inside(b) then ok := false;
  Check(ok, 'layout: every box lies inside the window content');

  ok := true;
  for i := 1 to 7 do
    for j := i + 1 to 7 do begin
      HandBox(i, false, b); HandBox(j, false, c);
      if Overlap(b, c) then ok := false
    end;
  Check(ok, 'layout: hand cards do not overlap each other');

  ok := true;
  for s := 0 to 1 do
    for i := 0 to NumSlots - 1 do
      for j := i + 1 to NumSlots - 1 do begin
        SlotBox(s, i, b); SlotBox(s, j, c);
        if Overlap(b, c) then ok := false
      end;
  Check(ok, 'layout: the seven piles of a player do not overlap');

  { the hit-test areas must be mutually exclusive }
  ok := true;
  DrawPileBox(b); DiscardBox(c);
  if Overlap(b, c) then ok := false;
  for s := 0 to 1 do begin
    RegionBox(s, c);
    DrawPileBox(b); if Overlap(b, c) then ok := false;
    DiscardBox(b); if Overlap(b, c) then ok := false;
    for i := 1 to 7 do begin
      HandBox(i, false, b); if Overlap(b, c) then ok := false;
      HandBox(i, true, b); if Overlap(b, c) then ok := false
    end
  end;
  RegionBox(0, b); RegionBox(1, c);
  if Overlap(b, c) then ok := false;
  Check(ok, 'layout: hit areas (hand, piles, both sides) never overlap')
end;

procedure TestHitTest;
var b: Box; h: HitInfo; i, t, x, y: integer; ok: boolean;
begin
  ok := true;
  for i := 1 to 7 do begin
    HandBox(i, false, b); BoxCenter(b, x, y);
    HitTest(x, y, 7, 0, h);
    if (h.kind <> hkHand) or (h.index <> i) then ok := false
  end;
  Check(ok, 'hit: the centre of each hand card hits that card');

  HandBox(5, false, b); BoxCenter(b, x, y);
  HitTest(x, y, 4, 0, h);
  Check(h.kind = hkNone, 'hit: a hand slot beyond the hand size hits nothing');

  HandBox(3, true, b); BoxCenter(b, x, y);
  HitTest(x, y, 6, 3, h);
  Check((h.kind = hkHand) and (h.index = 3), 'hit: the lifted (selected) card is hit where it is drawn');
  HitTest(x, b.top, 6, 0, h);
  Check(h.kind <> hkHand, 'hit: the same spot is not the card when it is not lifted');

  DrawPileBox(b); BoxCenter(b, x, y); HitTest(x, y, 6, 0, h);
  Check(h.kind = hkDraw, 'hit: draw pile');
  DiscardBox(b); BoxCenter(b, x, y); HitTest(x, y, 6, 0, h);
  Check(h.kind = hkDiscard, 'hit: discard pile');

  ok := true;
  for t := 0 to NumSlots - 1 do begin
    SlotBox(0, t, b); BoxCenter(b, x, y); HitTest(x, y, 6, 0, h);
    if h.kind <> hkOwn then ok := false;
    SlotBox(1, t, b); BoxCenter(b, x, y); HitTest(x, y, 6, 0, h);
    if h.kind <> hkOpp then ok := false
  end;
  Check(ok, 'hit: your piles are hkOwn, the computer''s piles are hkOpp');

  HitTest(2, 305, 6, 0, h);
  Check(h.kind = hkNone, 'hit: empty space hits nothing');
  HitTest(-5, -5, 6, 0, h);
  Check(h.kind = hkNone, 'hit: outside the window hits nothing')
end;

begin
  TestLayoutGeometry;
  TestHitTest;
  Summary
end.
