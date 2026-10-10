program test_ui;

uses TestKit, MilesLogic, MilesLayout, MilesCtrl;

const
  DblDelay = 40;       { hundredths of a second, like the Lisa's clickDelay }

var
  g: Game;
  u: UIState;
  clk: longint;     { a fake clock: every ordinary click is 10 seconds after the last, so none is a double }

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

procedure ClickBoxAt(var b: Box; t: longint; var ev: UIEvent);
var x, y: integer;
begin
  BoxCenter(b, x, y);
  UIClick(u, g, x, y, t, DblDelay, ev)
end;

procedure ClickBox(var b: Box; var ev: UIEvent);
begin
  clk := clk + 1000;
  ClickBoxAt(b, clk, ev)
end;

procedure ClickHandAt(i: integer; t: longint; var ev: UIEvent);
var b: Box;
begin
  HandBox(i, i = u.sel, b);
  ClickBoxAt(b, t, ev)
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
  Check(ok, 'layout: hit areas (hand, piles, both sides) never overlap');

  ok := true;
  NextBox(c);
  if not Inside(c) then ok := false;
  DrawPileBox(b); if Overlap(b, c) then ok := false;
  DiscardBox(b); if Overlap(b, c) then ok := false;
  for s := 0 to 1 do begin RegionBox(s, b); if Overlap(b, c) then ok := false end;
  for i := 1 to 7 do begin
    HandBox(i, false, b); if Overlap(b, c) then ok := false;
    HandBox(i, true, b); if Overlap(b, c) then ok := false
  end;
  Check(ok, 'layout: the Next Match button lies inside the window and overlaps nothing else')
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

  NextBox(b); BoxCenter(b, x, y); HitTest(x, y, 6, 0, h);
  Check(h.kind = hkNext, 'hit: the Next Match button');

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
  CheckEq(u.msg, MsgCpuCoup, 'coup: and the status says so');
  CheckEq(g.turn, 1, 'coup: the computer takes the next turn')
end;

procedure TestHandOverScoresOnce;
var ev: UIEvent;
begin
  UIInit(u);
  UINewHand(u, g, 3);
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975; g.pl[0].extended := true;
  g.turn := 0; g.ph := phPlay;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueHandOver, 'over: reaching 1000 ends the hand');
  CheckEq(u.match[0], 1000 + 400 + 200 + 300 + 500, 'over: the win is scored into the match');
  UIAdvance(u, g, ev);
  UIAdvance(u, g, ev);
  CheckEq(u.match[0], 1000 + 400 + 200 + 300 + 500, 'over: it is never scored twice');
  CheckEq(StatusMsg(u, g), MsgHandOver, 'over: status says the hand is over');
  UINewHand(u, g, 4);
  CheckEq(u.match[0], 1000 + 400 + 200 + 300 + 500, 'over: the match total survives a new hand');
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
    if g.ph = phExtend then begin
      if g.extSeat = 0 then begin
        answer := answer + 1;
        UIExtendAnswer(u, g, odd(answer div 2), ev)
      end
      else UIAdvance(u, g, ev)
    end
    else if g.ph = phCoup then begin
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
      if (mv.tgt <> tgDiscard) and odd(steps) then begin
        { play it the quick way: double-click the card }
        clk := clk + 1000;
        ClickHandAt(mv.hand, clk, ev);
        if ev <> ueSelect then bad := 4;
        if bad = 0 then begin
          ClickHandAt(mv.hand, clk + 10, ev);
          if (ev <> ueMoved) and (ev <> ueHandOver) and (ev <> ueExtendPrompt) then bad := 5
        end
      end
      else begin
        HandBox(mv.hand, false, b);
        ClickBox(b, ev);
        if ev <> ueSelect then bad := 2;
        if bad = 0 then begin
          if mv.tgt = tgDiscard then DiscardBox(b)
          else if mv.tgt = tgSelf then SlotBox(0, NaturalSlot(k), b)
          else SlotBox(1, NaturalSlot(k), b);
          ClickBox(b, ev);
          if (ev <> ueMoved) and (ev <> ueHandOver) and (ev <> ueExtendPrompt) then bad := 3
        end
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

procedure TestNextMatchButton;
var ev: UIEvent; b: Box; before: longint;
begin
  FreshPlay;
  NextBox(b); ClickBox(b, ev);
  Check(ev = ueNone, 'next: the button does nothing while a match is in progress');

  FreshPlay;
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975; g.pl[0].extended := true;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueHandOver, 'next: the match ends at 1000');
  before := u.match[0];
  CheckEq(before, 1000 + 400 + 200 + 300 + 500, 'next: and is scored');
  ClickHand(1, ev);
  Check(ev = ueNone, 'next: other clicks do nothing once the match is over');
  NextBox(b); ClickBox(b, ev);
  Check(ev = ueNextHand, 'next: clicking Next Match deals a new match');
  Check(g.ph = phDraw, 'next: the new match starts at the draw');
  CheckEq(g.turn, 0, 'next: you move first');
  CheckEq(g.pl[0].miles, 0, 'next: the cars start from zero');
  CheckEq(g.pl[0].handN, 6, 'next: six cards each');
  CheckEq(u.match[0], before, 'next: the running scores are kept');
  Check(not u.handScored, 'next: the new match can be scored');
  CheckEq(u.sel, 0, 'next: nothing is selected');
  g.pl[0].miles := 50;                       { a marker: a re-deal would wipe it }
  NextBox(b); ClickBox(b, ev);
  Check(ev <> ueNextHand, 'next: the button no longer deals once the new match is under way');
  CheckEq(g.pl[0].miles, 50, 'next: ...and the match in progress is untouched')
end;

procedure TestNewGameResetsScores;
begin
  UIInit(u);
  UINewHand(u, g, 3);
  u.match[0] := 500; u.match[1] := 300; u.sel := 2;
  UINewGame(u, g, 9);
  CheckEq(u.match[0], 0, 'newgame: your score is reset');
  CheckEq(u.match[1], 0, 'newgame: the computer''s score is reset');
  CheckEq(u.sel, 0, 'newgame: nothing selected');
  Check(g.ph = phDraw, 'newgame: a fresh deal');
  CheckEq(g.pl[0].handN, 6, 'newgame: six cards each')
end;

procedure TestComputerMoveMessages;
var ev: UIEvent;
begin
  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, hzFlat, ck25, ck25, ck25, ck25, ck25);
  SetHand(g, 0, ck50, ck50, ck50, ck50, ck50, ck50);
  g.pl[0].battle := rmGo;
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  CheckEq(u.msg, MsgCpuAttack, 'cpu: an attack on you is announced');
  Check(u.lastCard = hzFlat, 'cpu: ...with the card it used');

  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, ck75, ck25, ck25, ck25, ck25, ck25);
  g.pl[1].battle := rmGo;
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  CheckEq(u.msg, MsgCpuPlayed, 'cpu: a normal play is announced');
  Check(u.lastCard = ck75, 'cpu: ...with the card it used');

  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, ck25, ck25, ck25, ck25, ck25, ck25);        { no Go: only discards are possible }
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  CheckEq(u.msg, MsgCpuDiscard, 'cpu: a discard is announced');
  Check(u.lastCard = ck25, 'cpu: ...with the card it threw away');

  { the message goes away as soon as you act }
  UINewHand(u, g, 6);
  u.msg := MsgCpuAttack;
  g.turn := 0; g.ph := phDraw;
  ClickHand(1, ev);
  u.msg := MsgCpuAttack;
  g.ph := phPlay;
  ClickHand(1, ev);
  CheckEq(u.msg, MsgNone, 'cpu: selecting a card clears the computer''s message')
end;

procedure TestDoubleClickPlays;
var ev: UIEvent;
begin
  { a distance card is added to your miles }
  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHandAt(1, 1000, ev);
  Check(ev = ueSelect, 'dbl: the first click selects');
  ClickHandAt(1, 1020, ev);
  Check(ev = ueMoved, 'dbl: a second click within the delay plays the card');
  CheckEq(g.pl[0].miles, 50, 'dbl: a distance card adds to your miles');
  CheckEq(u.sel, 0, 'dbl: nothing is left selected');
  CheckEq(g.turn, 1, 'dbl: the turn passed');

  { Go goes on the battle pile }
  FreshPlay;
  SetHand(g, 0, rmGo, ck25, ck25, ck25, ck25, ck25);
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(g.pl[0].battle = rmGo, 'dbl: Go goes on the battle pile');

  { a remedy cures its hazard }
  FreshPlay;
  SetHand(g, 0, rmRepairs, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := hzAccident;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(g.pl[0].battle = rmRepairs, 'dbl: a remedy cures the hazard');

  { End of Limit goes on the speed pile }
  FreshPlay;
  SetHand(g, 0, rmEndLimit, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].limited := true;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(not g.pl[0].limited, 'dbl: End of Limit lifts the limit');

  { a safety goes into play and gives you another turn }
  FreshPlay;
  SetHand(g, 0, sfTank, ck25, ck25, ck25, ck25, ck25);
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(g.pl[0].safe[1], 'dbl: a safety goes into play');
  CheckEq(g.turn, 0, 'dbl: ...and you move again');

  { a hazard attacks the computer when it can move }
  FreshPlay;
  SetHand(g, 0, hzStop, ck25, ck25, ck25, ck25, ck25);
  SetHand(g, 1, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[1].battle := rmGo;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(g.pl[1].battle = hzStop, 'dbl: a hazard is played on the computer');

  { finishing the trip by double-click ends and scores the match }
  FreshPlay;
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975; g.pl[0].extended := true;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(ev = ueHandOver, 'dbl: the winning card ends the match');
  CheckEq(u.match[0], 1000 + 400 + 200 + 300 + 500, 'dbl: ...and it is scored')
end;

procedure TestDoubleClickRefusals;
var ev: UIEvent;
begin
  { not playable: nothing happens to the hand, the card stays selected, the reason is shown }
  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(ev = ueRejected, 'dbl: an unplayable card is refused');
  CheckEq(u.msg, ErrNeedGo, 'dbl: ...with the reason');
  CheckEq(u.sel, 1, 'dbl: ...and it stays selected');
  CheckEq(g.pl[0].handN, 6, 'dbl: ...and is NOT discarded');
  CheckEq(g.pl[0].miles, 0, 'dbl: ...and nothing was played');

  { a hazard with no legal target gives the attack reason }
  FreshPlay;
  SetHand(g, 0, hzStop, ck25, ck25, ck25, ck25, ck25);
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(ev = ueRejected, 'dbl: a hazard with no target is refused');
  CheckEq(u.msg, ErrNoEffect, 'dbl: ...because it would have no effect');
  CheckEq(g.pl[0].handN, 6, 'dbl: ...and is not thrown away');

  { Go when you are already going }
  FreshPlay;
  SetHand(g, 0, rmGo, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  CheckEq(u.msg, ErrNoNeed, 'dbl: Go is refused when you are already going');
  CheckEq(g.pl[0].handN, 6, 'dbl: ...and kept')
end;

procedure TestDoubleClickTiming;
var ev: UIEvent;
begin
  { exactly the delay apart is too slow: the second click deselects as before }
  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1000 + DblDelay, ev);
  Check(ev = ueDeselect, 'dbl: a slow second click only deselects');
  CheckEq(g.pl[0].miles, 0, 'dbl: ...and plays nothing');

  { two quick clicks on DIFFERENT cards are not a double click }
  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHandAt(1, 2000, ev);
  ClickHandAt(2, 2010, ev);
  Check(ev = ueSelect, 'dbl: quick clicks on two different cards just move the selection');
  CheckEq(u.sel, 2, 'dbl: ...to the second card');
  CheckEq(g.pl[0].miles, 0, 'dbl: ...and play nothing');

  { a clock that goes backwards never counts as a double click }
  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHandAt(1, 5000, ev);
  ClickHandAt(1, 4990, ev);
  Check(ev = ueDeselect, 'dbl: time running backwards is not a double click');

  { an old click does not pair with a click after a pile click in between }
  FreshPlay;
  SetHand(g, 0, ck50, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  ClickHandAt(1, 7000, ev);
  ClickSlot(1, SlotBattle, ev);                         { an illegal click elsewhere }
  ClickHandAt(1, 7005, ev);
  Check(ev = ueDeselect, 'dbl: a click elsewhere in between breaks the pair')
end;

procedure TestTargets;
var ev: UIEvent;
begin
  FreshPlay;
  SetHand(g, 0, rmGo, ck50, hzStop, sfAce, rmEndLimit, hzLimit);
  g.pl[1].battle := rmGo;
  CheckEq(UITarget(u, g, 0), -1, 'target: nothing selected, nothing highlighted (you)');
  CheckEq(UITarget(u, g, 1), -1, 'target: nothing selected, nothing highlighted (computer)');

  ClickHand(1, ev);                                   { Go }
  CheckEq(UITarget(u, g, 0), SlotBattle, 'target: Go highlights your battle pile');
  CheckEq(UITarget(u, g, 1), -1, 'target: ...and nothing on the computer''s side');

  ClickHand(2, ev);                                   { 50 miles: no Go yet, so no legal target }
  CheckEq(UITarget(u, g, 0), -1, 'target: a card you cannot play highlights nothing');

  g.pl[0].battle := rmGo;
  CheckEq(UITarget(u, g, 0), SlotMiles, 'target: distance highlights your miles pile once you have a Go');

  ClickHand(3, ev);                                   { Stop: the computer is moving }
  CheckEq(UITarget(u, g, 0), -1, 'target: a hazard does not highlight your side');
  CheckEq(UITarget(u, g, 1), SlotBattle, 'target: Stop highlights the computer''s battle pile');

  ClickHand(6, ev);                                   { Speed Limit }
  CheckEq(UITarget(u, g, 1), SlotSpeed, 'target: Speed Limit highlights the computer''s speed pile');

  ClickHand(4, ev);                                   { safety }
  CheckEq(UITarget(u, g, 0), SlotSafety0, 'target: the Ace highlights the first safety slot');

  g.turn := 1;
  CheckEq(UITarget(u, g, 0), -1, 'target: nothing is highlighted on the computer''s turn');
  g.turn := 0; g.ph := phOver;
  CheckEq(UITarget(u, g, 0), -1, 'target: nothing is highlighted when the match is over')
end;

procedure TestExtensionFlow;
var ev: UIEvent;
begin
  { you reach 700: the game asks, and nothing else works until you answer }
  FreshPlay;
  SetHand(g, 0, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo; g.pl[0].miles := 600;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueExtendPrompt, 'extflow: reaching 700 asks whether to extend');
  Check(g.ph = phExtend, 'extflow: the game waits');
  ClickHand(1, ev);
  Check(ev = ueNone, 'extflow: clicks are ignored while the question is pending');
  UIAdvance(u, g, ev);
  Check(ev = ueExtendPrompt, 'extflow: the question stays pending until answered');

  UIExtendAnswer(u, g, true, ev);
  Check(ev = ueMoved, 'extflow: extending continues the match');
  Check(g.pl[0].extended, 'extflow: you are marked as extended');
  CheckEq(g.turn, 1, 'extflow: the turn passes to the computer');

  { stopping ends the match at 700 and scores it }
  FreshPlay;
  SetHand(g, 0, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo; g.pl[0].miles := 600;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  UIExtendAnswer(u, g, false, ev);
  Check(ev = ueHandOver, 'extflow: stopping ends the match');
  CheckEq(u.match[0], 700 + 400 + 300 + 500, 'extflow: the 700-mile trip is scored');

  { a double-click that lands on 700 asks too }
  FreshPlay;
  SetHand(g, 0, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo; g.pl[0].miles := 600;
  ClickHandAt(1, 1000, ev);
  ClickHandAt(1, 1010, ev);
  Check(ev = ueExtendPrompt, 'extflow: a double-click to 700 asks as well');

  { the computer reaches 700 well ahead: it extends by itself and says so }
  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[1].battle := rmGo; g.pl[1].miles := 600; g.pl[0].miles := 100;
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  Check(g.pl[1].extended, 'extflow: a computer with a big lead extends');
  CheckEq(u.msg, MsgCpuExtend, 'extflow: ...and the status says so');
  Check(g.ph = phDraw, 'extflow: ...and the match goes on');
  CheckEq(g.turn, 0, 'extflow: ...to your turn');

  { the computer reaches 700 with the opponent close behind: it takes the sure win }
  UIInit(u);
  UINewHand(u, g, 5);
  SetHand(g, 1, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[1].battle := rmGo; g.pl[1].miles := 600; g.pl[0].miles := 650;
  g.turn := 1; g.ph := phPlay;
  UIAdvance(u, g, ev);
  Check(ev = ueHandOver, 'extflow: a computer with a thin lead stops at 700');
  CheckEq(g.tripBy, 1, 'extflow: ...and wins the match');
  CheckEq(u.match[1], 700 + 400 + 300, 'extflow: ...scored at 700')
end;

procedure TestExtendButtons;
var ev: UIEvent; a, b: Box;
begin
  ContinueBox(a); EndBox(b);
  Check((a.right <= b.left) and (a.left >= 0) and (b.right <= ContentW), 'extbtn: two separate buttons inside the window');
  Check((a.bottom <= 204) and (b.bottom <= 204) and (a.top > 68), 'extbtn: ...in the free strip between the rows');

  { Continue extends to 1000 }
  FreshPlay;
  SetHand(g, 0, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo; g.pl[0].miles := 600;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  CheckEq(StatusMsg(u, g), MsgExtendAsk, 'extbtn: the status line asks the question');
  ClickHand(1, ev);
  Check((ev = ueNone) and (g.ph = phExtend), 'extbtn: a click elsewhere leaves the question open');
  ClickBox(a, ev);
  Check(ev = ueMoved, 'extbtn: Continue answers the question');
  Check(g.pl[0].extended and (g.ph <> phExtend), 'extbtn: Continue extends the trip');

  { End Game stops at 700 }
  FreshPlay;
  SetHand(g, 0, ck100, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo; g.pl[0].miles := 600;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  ClickBox(b, ev);
  Check(ev = ueHandOver, 'extbtn: End Game ends the match at 700');
  CheckEq(u.match[0], 700 + 400 + 300 + 500, 'extbtn: ...and scores it');

  { the buttons do nothing at any other time }
  FreshPlay;
  ClickBox(a, ev);
  Check(g.pl[0].extended = false, 'extbtn: Continue is inert outside the question')
end;

procedure TestGameOver;
var ev: UIEvent; b: Box;
begin
  { reaching 5000 ends the whole game; the higher total wins }
  FreshPlay;
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo; g.pl[0].miles := 975; g.pl[0].extended := true;
  u.match[0] := 3000; u.match[1] := 2000;
  ClickHand(1, ev);
  ClickSlot(0, SlotMiles, ev);
  Check(ev = ueHandOver, 'over5000: the winning match ends');
  CheckEq(u.match[0], 3000 + 1000 + 400 + 200 + 300 + 500, 'over5000: and is added to the total');
  Check(u.gameOver, 'over5000: 5000 reached means the game is over');
  CheckEq(u.winner, 0, 'over5000: you have the higher score');
  CheckEq(StatusMsg(u, g), MsgGameOver, 'over5000: the status says the game is over');
  NextBox(b); ClickBox(b, ev);
  Check(ev = ueNone, 'over5000: Next Match no longer works');
  UINewGame(u, g, 4);
  Check(not u.gameOver, 'over5000: New Game starts afresh');
  CheckEq(u.match[0], 0, 'over5000: ...with zero scores');

  { the computer gets to 5000 with the higher score }
  UIInit(u);
  UINewHand(u, g, 5);
  g.pl[1].miles := 1000; g.tripBy := 1; g.ph := phOver;
  u.match[0] := 100; u.match[1] := 3000;
  UIAdvance(u, g, ev);
  Check(u.gameOver, 'over5000: the computer passing 5000 ends the game');
  CheckEq(u.winner, 1, 'over5000: ...and it has the higher score');

  { both past 5000: the higher total still wins }
  UIInit(u);
  UINewHand(u, g, 5);
  g.ph := phOver;
  u.match[0] := 5200; u.match[1] := 5100;
  UIAdvance(u, g, ev);
  Check(u.gameOver, 'over5000: both players past 5000 still ends it');
  CheckEq(u.winner, 0, 'over5000: ...with the higher total winning');

  { an exact tie at or above 5000 keeps the game going }
  UIInit(u);
  UINewHand(u, g, 5);
  g.ph := phOver;
  u.match[0] := 5000; u.match[1] := 5000;
  UIAdvance(u, g, ev);
  Check(not u.gameOver, 'over5000: a tie keeps the game going');
  NextBox(b); ClickBox(b, ev);
  Check(ev = ueNextHand, 'over5000: ...and Next Match still works');

  { below 5000 nothing special happens }
  UIInit(u);
  UINewHand(u, g, 5);
  g.ph := phOver;
  u.match[0] := 4999; u.match[1] := 100;
  UIAdvance(u, g, ev);
  Check(not u.gameOver, 'over5000: 4999 is not enough')
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
  TestExtensionFlow;
  TestExtendButtons;
  TestGameOver;
  TestTargets;
  TestDoubleClickPlays;
  TestDoubleClickRefusals;
  TestDoubleClickTiming;
  TestNextMatchButton;
  TestNewGameResetsScores;
  TestComputerMoveMessages;
  TestScriptedGames;
  Summary
end.
