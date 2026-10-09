program test_logic;

uses TestKit, MilesLogic;

var
  g: Game;

function DeckSig(var d: Game): longint;
var i: integer; s: longint;
begin
  s := 0;
  for i := 1 to NumCards do s := (s * 31 + ord(d.deck[i]) + 1) mod 1000003;
  DeckSig := s
end;

{ Number of positions where the card kind drops: ~0 for a sorted deck, ~50 for a random one. }
function Descents(var d: Game): integer;
var i, n: integer;
begin
  n := 0;
  for i := 2 to NumCards do
    if ord(d.deck[i]) < ord(d.deck[i - 1]) then n := n + 1;
  Descents := n
end;

function DeckIsValid(var d: Game): boolean;
var cnt: array[CardKind] of integer; i: integer; k: CardKind; ok: boolean;
begin
  for k := ckNone to sfRoW do cnt[k] := 0;
  for i := 1 to NumCards do cnt[d.deck[i]] := cnt[d.deck[i]] + 1;
  ok := cnt[ckNone] = 0;
  for k := ck25 to sfRoW do
    if cnt[k] <> KindCount(k) then ok := false;
  DeckIsValid := ok
end;

procedure TestDeck;
var cnt: array[CardKind] of integer; i: integer; k: CardKind; total: integer;
begin
  NewGame(g, 1);
  for k := ckNone to sfRoW do cnt[k] := 0;
  for i := 1 to NumCards do cnt[g.deck[i]] := cnt[g.deck[i]] + 1;
  CheckEq(cnt[ck25], 10, 'deck: 25 x10');
  CheckEq(cnt[ck50], 10, 'deck: 50 x10');
  CheckEq(cnt[ck75], 10, 'deck: 75 x10');
  CheckEq(cnt[ck100], 12, 'deck: 100 x12');
  CheckEq(cnt[ck200], 4, 'deck: 200 x4');
  CheckEq(cnt[hzAccident], 3, 'deck: accident x3');
  CheckEq(cnt[hzOutOfGas], 3, 'deck: out of gas x3');
  CheckEq(cnt[hzFlat], 3, 'deck: flat x3');
  CheckEq(cnt[hzLimit], 4, 'deck: limit x4');
  CheckEq(cnt[hzStop], 5, 'deck: stop x5');
  CheckEq(cnt[rmRepairs], 6, 'deck: repairs x6');
  CheckEq(cnt[rmGas], 6, 'deck: gas x6');
  CheckEq(cnt[rmSpare], 6, 'deck: spare x6');
  CheckEq(cnt[rmEndLimit], 6, 'deck: end limit x6');
  CheckEq(cnt[rmGo], 14, 'deck: go x14');
  for k := sfAce to sfRoW do CheckEq(cnt[k], 1, 'deck: each safety x1');
  total := 0;
  for k := ck25 to sfRoW do total := total + cnt[k];
  CheckEq(total, 106, 'deck: 106 cards');
  CheckEq(g.pl[0].handN, 6, 'deal: p0 has 6');
  CheckEq(g.pl[1].handN, 6, 'deal: p1 has 6');
  CheckEq(RemainingDeck(g), 94, 'deal: 94 left');
  CheckEq(g.turn, 0, 'deal: player 0 first');
  Check(g.ph = phDraw, 'deal: starts in draw phase')
end;

procedure TestSeeds;
var sig1: longint; g2: Game;
begin
  NewGame(g, 1);  sig1 := DeckSig(g);
  NewGame(g2, 1); CheckEq(DeckSig(g2), sig1, 'seed: same seed same deck');
  NewGame(g2, 2); Check(DeckSig(g2) <> sig1, 'seed: different seed different deck');
  NewGame(g2, 0);
  Check(DeckIsValid(g2), 'seed 0: valid deck');
  Check(Descents(g2) >= 20, 'seed 0: really shuffled, not stuck on a degenerate shuffle');
  NewGame(g2, -1);
  Check(DeckIsValid(g2), 'seed -1: valid deck');
  NewGame(g2, -2147483647 - 1);
  Check(DeckIsValid(g2), 'seed min longint: valid deck');
  NewGame(g2, 2147483647);
  Check(DeckIsValid(g2), 'seed max longint: valid deck');
  Check(NormSeed(0) > 0, 'NormSeed(0) > 0');
  Check(NormSeed(-2147483647 - 1) > 0, 'NormSeed(min) > 0')
end;

{@TESTS}

begin
  TestDeck;
  TestSeeds;
  {@CALLS}
  Summary
end.
