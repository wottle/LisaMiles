program test_ui;

uses TestKit, MilesLogic, MilesLayout, MilesCtrl;

var
  g: Game;
  u: UIState;

procedure SetHand(var d: Game; s: integer; a, b, c, e, f, h: CardKind);
begin
  d.pl[s].handN := 6;
  d.pl[s].hand[1] := a; d.pl[s].hand[2] := b; d.pl[s].hand[3] := c;
  d.pl[s].hand[4] := e; d.pl[s].hand[5] := f; d.pl[s].hand[6] := h
end;

procedure FreshPlay;      { human to play, nothing selected }
begin
  UIInit(u);
  UINewHand(u, g, 4242);
  g.turn := 0;
  g.ph := phPlay
end;

procedure ClickBox(var b: Box; var ev: UIEvent);
var x, y: integer;
begin
  BoxCenter(b, x, y);
  UIClick(u, g, x, y, ev)
end;

procedure ClickHand(i: integer; var ev: UIEvent);
var b: Box;
begin
  HandBox(i, i = u.sel, b);
  ClickBox(b, ev)
end;

procedure ClickSlot(seat, slot: integer; var ev: UIEvent);
var b: Box;
begin
  SlotBox(seat, slot, b);
  ClickBox(b, ev)
end;

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

{ ---------------- controller ---------------- }

procedure TestSelection;
var ev: UIEvent;
begin
  FreshPlay;
  ClickHand(2, ev);
  Check(ev = ueSelect, 'ctrl: clicking a hand card selects it');
  CheckEq(u.sel, 2, 'ctrl: selection is card 2');
  ClickHand(4, ev);
  CheckEq(u.sel, 4, 'ctrl: clicking another card moves the selection');
  ClickHand(4, ev);
  Check(ev = ueDeselect, 'ctrl: clicking the selected card deselects');
  CheckEq(u.sel, 0, 'ctrl: nothing selected after deselect');
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueRejected, 'ctrl: clicking a pile with nothing selected is rejected');
  CheckEq(u.msg, ErrNoCard, 'ctrl: ...with the "pick a card" message')
end;

procedure TestDrawClick;
var ev: UIEvent; b: Box;
begin
  UIInit(u);
  UINewHand(u, g, 7);
  ClickHand(1, ev);
  Check(ev = ueRejected, 'ctrl: before drawing, a hand click is refused');
  CheckEq(u.msg, ErrPhase, 'ctrl: ...with "draw a card first"');
  DrawPileBox(b);
  ClickBox(b, ev);
  Check(ev = ueDrew, 'ctrl: clicking the draw pile draws');
  CheckEq(g.pl[0].handN, 7, 'ctrl: the human now holds 7 cards');
  Check(g.ph = phPlay, 'ctrl: now in the play phase');
  ClickBox(b, ev);
  Check(ev = ueRejected, 'ctrl: the draw pile is refused after drawing');
  CheckEq(u.msg, MsgAlreadyDrew, 'ctrl: ...with the already-drew message')
end;

procedure TestPlayClicks;
var ev: UIEvent; b: Box;
begin
  FreshPlay;
  SetHand(g, 0, ck50, rmGo, hzStop, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueMoved, 'ctrl: select 50, click your miles pile: played');
  CheckEq(g.pl[0].miles, 50, 'ctrl: the miles went on');
  CheckEq(u.sel, 0, 'ctrl: selection cleared after a move');
  CheckEq(g.turn, 1, 'ctrl: turn passed to the computer');

  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);        { no Go: illegal }
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueRejected, 'ctrl: an illegal play is rejected');
  CheckEq(u.msg, ErrNeedGo, 'ctrl: ...with the reason');
  CheckEq(u.sel, 1, 'ctrl: ...and the card stays selected');
  CheckEq(g.pl[0].handN, 6, 'ctrl: ...and the hand is untouched');

  FreshPlay;
  SetHand(g, 0, ck75, ck25, ck25, ck25, ck25, ck25);
  ClickHand(1, ev);
  DiscardBox(b);
  ClickBox(b, ev);
  Check(ev = ueMoved, 'ctrl: discarding by clicking the discard pile');
  Check(g.discardTop = ck75, 'ctrl: the discard pile shows the card');
  CheckEq(g.pl[0].handN, 5, 'ctrl: the hand shrank');

  FreshPlay;
  SetHand(g, 0, hzStop, ck25, ck25, ck25, ck25, ck25);
  SetHand(g, 1, ck25, ck25, ck25, ck25, ck25, ck25);        { computer has no safety }
  g.pl[1].battle := rmGo;
  ClickHand(1, ev);
  ClickSlot(1, SlotBattle, ev);
  Check(ev = ueMoved, 'ctrl: attacking by clicking the computer''s side');
  Check(g.pl[1].battle = hzStop, 'ctrl: the hazard landed on the computer')
end;

procedure TestNaturalSlot;
begin
  CheckEq(NaturalSlot(ck100), SlotMiles, 'slot: distance goes on the miles pile');
  CheckEq(NaturalSlot(rmGo), SlotBattle, 'slot: Go goes on the battle pile');
  CheckEq(NaturalSlot(rmRepairs), SlotBattle, 'slot: Repairs goes on the battle pile');
  CheckEq(NaturalSlot(rmEndLimit), SlotSpeed, 'slot: End of Limit goes on the speed pile');
  CheckEq(NaturalSlot(hzLimit), SlotSpeed, 'slot: Speed Limit goes on the speed pile');
  CheckEq(NaturalSlot(hzStop), SlotBattle, 'slot: Stop goes on the battle pile');
  CheckEq(NaturalSlot(sfAce), SlotSafety0, 'slot: Ace is the first safety slot');
  CheckEq(NaturalSlot(sfRoW), SlotSafety0 + 3, 'slot: Right of Way is the last safety slot')
end;

procedure TestComputerAdvance;
var ev: UIEvent;
begin
  UIInit(u);
  UINewHand(u, g, 99);
  UIAdvance(u, g, ev);
  Check(ev = ueNone, 'adv: nothing happens on the human''s turn');
  g.turn := 1;
  UIAdvance(u, g, ev);
  Check(ev = ueDrew, 'adv: the computer draws first');
  CheckEq(g.pl[1].handN, 7, 'adv: it now holds 7');
  UIAdvance(u, g, ev);
  Check((ev = ueMoved) or (ev = ueCoupPrompt) or (ev = ueHandOver), 'adv: then it makes a move');
  CheckEq(g.pl[1].handN, 6, 'adv: back to 6 cards')
end;

procedure TestCoupFlows;
var ev: UIEvent;
begin
  { computer attacks the human who holds the matching safety: the human is asked }
  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, hzAccident, ck25, ck25, ck25, ck25, ck25);
  SetHand(g, 0, sfAce, ck50, ck50, ck50, ck50, ck50);
  g.pl[0].battle := rmGo;
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  Check(ev = ueCoupPrompt, 'coup: the human is prompted');
  CheckEq(u.msg, MsgCoupAsk, 'coup: with the ask message');
  Check(g.ph = phCoup, 'coup: the game waits');
  UIAdvance(u, g, ev);
  Check(ev = ueCoupPrompt, 'coup: it keeps waiting until answered');
  UICoupAnswer(u, g, true, ev);
  Check(g.pl[0].safe[0], 'coup: answering yes puts the ace in play');
  CheckEq(g.turn, 0, 'coup: the human moves next');

  { declined }
  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, hzAccident, ck25, ck25, ck25, ck25, ck25);
  SetHand(g, 0, sfAce, ck50, ck50, ck50, ck50, ck50);
  g.pl[0].battle := rmGo;
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  UICoupAnswer(u, g, false, ev);
  Check(g.pl[0].battle = hzAccident, 'coup: declining leaves the accident');
  Check(not g.pl[0].safe[0], 'coup: ...and the ace stays in hand');

  { human attacks the computer holding the matching safety: the computer answers itself }
  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 0, hzAccident, ck25, ck25, ck25, ck25, ck25);
  SetHand(g, 1, sfAce, ck50, ck50, ck50, ck50, ck50);
  g.pl[1].battle := rmGo;
  g.turn := 0; g.ph := phPlay;
  ClickHand(1, ev);
  ClickSlot(1, SlotBattle, ev);
  Check(g.pl[1].safe[0], 'coup: the computer plays its ace at once');
  CheckEq(u.msg, MsgComputerCoup, 'coup: and the status says so');
  CheckEq(g.turn, 1, 'coup: the computer takes the next turn')
end;

procedure TestHandOverScoresOnce;
var ev: UIEvent;
begin
  UIInit(u);
  UINewHand(u, g, 3);
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975;
  g.turn := 0; g.ph := phPlay;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueHandOver, 'over: reaching 1000 ends the hand');
  CheckEq(u.match[0], 1000 + 400 + 300 + 500, 'over: the win is scored into the match');
  UIAdvance(u, g, ev);
  UIAdvance(u, g, ev);
  CheckEq(u.match[0], 1000 + 400 + 300 + 500, 'over: it is never scored twice');
  CheckEq(StatusMsg(u, g), MsgHandOver, 'over: status says the hand is over');
  UINewHand(u, g, 4);
  CheckEq(u.match[0], 1000 + 400 + 300 + 500, 'over: the match total survives a new hand');
  Check(g.ph = phDraw, 'over: a new hand starts at the draw');
  CheckEq(StatusMsg(u, g), MsgYourDraw, 'over: ...and says to draw')
end;

{ A scripted human that plays whole games using ONLY clicks derived from the layout. }
procedure PlayThrough(seed: longint; var steps: integer; var bad: integer);
var ev: UIEvent; mv: PlayMove; b: Box; k: CardKind; answer: integer;
begin
  UIInit(u);
  UINewHand(u, g, seed);
  steps := 0; bad := 0; answer := 0;
  while (g.ph <> phOver) and (steps < 4000) and (bad = 0) do begin
    steps := steps + 1;
    if g.ph = phCoup then begin
      if g.coupSeat = 0 then begin
        answer := answer + 1;
        UICoupAnswer(u, g, odd(answer), ev)
      end
      else UIAdvance(u, g, ev)
    end
    else if g.turn = 1 then
      UIAdvance(u, g, ev)
    else if g.ph = phDraw then begin
      DrawPileBox(b);
      ClickBox(b, ev);
      if ev <> ueDrew then bad := 1
    end
    else begin
      AIChoose(g, mv);
      k := g.pl[0].hand[mv.hand];
      HandBox(mv.hand, false, b);
      ClickBox(b, ev);
      if ev <> ueSelect then bad := 2;
      if bad = 0 then begin
        if mv.tgt = tgDiscard then DiscardBox(b)
        else if mv.tgt = tgSelf then SlotBox(0, NaturalSlot(k), b)
        else SlotBox(1, NaturalSlot(k), b);
        ClickBox(b, ev);
        if (ev <> ueMoved) and (ev <> ueHandOver) then bad := 3
      end
    end;
    if bad = 0 then bad := CheckInvariants(g) * 10
  end;
  if g.ph <> phOver then bad := 99
end;

procedure TestScriptedGames;
var seed: longint; steps, bad, failures, worst: integer; before: longint;
begin
  failures := 0; worst := 0;
  for seed := 1 to 300 do begin
    PlayThrough(seed, steps, bad);
    if bad <> 0 then begin
      failures := failures + 1;
      if failures <= 3 then writeln('scripted game failed: seed ', seed, ' code ', bad, ' steps ', steps)
    end;
    if steps > worst then worst := steps;
    before := u.match[0] + u.match[1];
    if (bad = 0) and (before < 0) then failures := failures + 1
  end;
  CheckEq(failures, 0, 'scripted: 300 whole games played by clicks alone, no refusals, invariants hold')
end;

procedure TestIgnoredClicks;
var ev: UIEvent; b: Box; before: integer;
begin
  { computer's turn: every click is ignored and changes nothing }
  FreshPlay;
  g.turn := 1; g.ph := phDraw;
  before := g.pl[0].handN;
  DrawPileBox(b); ClickBox(b, ev);
  Check(ev = ueNone, 'ignored: draw-pile click on the computer''s turn');
  HandBox(1, false, b); ClickBox(b, ev);
  Check(ev = ueNone, 'ignored: hand click on the computer''s turn');
  CheckEq(g.pl[0].handN, before, 'ignored: the hand is untouched');
  Check((g.ph = phDraw) and (g.turn = 1), 'ignored: the game state is untouched');
  CheckEq(u.sel, 0, 'ignored: nothing got selected');

  { a coup prompt is pending: clicks are ignored }
  FreshPlay;
  g.ph := phCoup; g.coupSeat := 0; g.turn := 1;
  ClickHand(1, ev);
  Check(ev = ueNone, 'ignored: clicks while a coup answer is pending');
  Check(g.ph = phCoup, 'ignored: the coup is still pending');

  { hand over: clicks are ignored }
  FreshPlay;
  g.ph := phOver;
  ClickHand(1, ev);
  Check(ev = ueNone, 'ignored: clicks after the hand is over')
end;

begin
  TestLayoutGeometry;
  TestHitTest;
  TestSelection;
  TestDrawClick;
  TestPlayClicks;
  TestNaturalSlot;
  TestComputerAdvance;
  TestCoupFlows;
  TestHandOverScoresOnce;
  TestIgnoredClicks;
  TestScriptedGames;
  Summary
end.
