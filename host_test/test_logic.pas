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

procedure SetHand(var d: Game; s: integer; a, b, c, e, f, h: CardKind);
begin
  d.pl[s].handN := 6;
  d.pl[s].hand[1] := a; d.pl[s].hand[2] := b; d.pl[s].hand[3] := c;
  d.pl[s].hand[4] := e; d.pl[s].hand[5] := f; d.pl[s].hand[6] := h
end;

procedure FreshPlay(var d: Game);
begin
  NewGame(d, 12345);
  d.turn := 0;
  d.ph := phPlay
end;

procedure TestMovement;
begin
  FreshPlay(g);
  SetHand(g, 0, ck25, ck50, ck100, ck200, ck75, ck25);
  CheckEq(CheckPlay(g, 1, tgSelf), ErrNeedGo, 'no Go: 25 refused');
  g.pl[0].battle := rmGo;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrOK, 'Go: 25 ok');
  g.pl[0].limited := true;
  CheckEq(CheckPlay(g, 2, tgSelf), ErrOK, 'limit: 50 ok');
  CheckEq(CheckPlay(g, 3, tgSelf), ErrLimit, 'limit: 100 refused');
  CheckEq(CheckPlay(g, 5, tgSelf), ErrLimit, 'limit: 75 refused');
  g.pl[0].safe[3] := true;
  CheckEq(CheckPlay(g, 3, tgSelf), ErrOK, 'Right of Way ignores limit');
  g.pl[0].safe[3] := false;
  g.pl[0].limited := false;
  g.pl[0].n200 := 2;
  CheckEq(CheckPlay(g, 4, tgSelf), Err200, 'third 200 refused');
  g.pl[0].n200 := 1;
  CheckEq(CheckPlay(g, 4, tgSelf), ErrOK, 'second 200 ok');
  g.pl[0].n200 := 0;
  g.pl[0].miles := 800;
  CheckEq(CheckPlay(g, 4, tgSelf), ErrOK, '800+200 = exactly 1000 ok');
  g.pl[0].miles := 825;
  CheckEq(CheckPlay(g, 4, tgSelf), ErrOver, '825+200 overshoots');
  g.pl[0].miles := 975;
  CheckEq(CheckPlay(g, 2, tgSelf), ErrOver, '975+50 overshoots');
  CheckEq(CheckPlay(g, 1, tgSelf), ErrOK, '975+25 = exactly 1000 ok');
  g.pl[0].miles := 0;
  g.pl[0].battle := hzAccident;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrBlocked, 'accident blocks moving');
  g.pl[0].battle := rmRepairs;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrNeedGo, 'after repairs still need Go')
end;

procedure TestRemedies;
begin
  FreshPlay(g);
  SetHand(g, 0, rmRepairs, rmGas, rmSpare, rmEndLimit, rmGo, sfAce);
  g.pl[0].battle := hzAccident;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrOK, 'repairs cure accident');
  CheckEq(CheckPlay(g, 2, tgSelf), ErrWrongRemedy, 'gas does not cure accident');
  CheckEq(CheckPlay(g, 3, tgSelf), ErrWrongRemedy, 'spare does not cure accident');
  CheckEq(CheckPlay(g, 5, tgSelf), ErrWrongRemedy, 'Go cannot cure accident');
  g.pl[0].battle := hzOutOfGas;
  CheckEq(CheckPlay(g, 2, tgSelf), ErrOK, 'gas cures out of gas');
  g.pl[0].battle := hzFlat;
  CheckEq(CheckPlay(g, 3, tgSelf), ErrOK, 'spare cures flat');
  g.pl[0].battle := hzStop;
  CheckEq(CheckPlay(g, 5, tgSelf), ErrOK, 'Go cures stop');
  g.pl[0].battle := rmGo;
  CheckEq(CheckPlay(g, 5, tgSelf), ErrNoNeed, 'Go when already going');
  CheckEq(CheckPlay(g, 4, tgSelf), ErrNoNeed, 'end limit when not limited');
  g.pl[0].limited := true;
  CheckEq(CheckPlay(g, 4, tgSelf), ErrOK, 'end limit when limited');
  CheckEq(CheckPlay(g, 6, tgSelf), ErrOK, 'safety playable on self');
  CheckEq(CheckPlay(g, 6, tgOpponent), ErrBadTarget, 'safety never playable on opponent');
  SetHand(g, 0, hzStop, ck25, ck25, ck25, ck25, ck25);
  CheckEq(CheckPlay(g, 1, tgSelf), ErrBadTarget, 'hazard cannot target self');
  CheckEq(CheckPlay(g, 2, tgOpponent), ErrBadTarget, 'distance cannot target opponent')
end;

procedure TestAttacks;
begin
  FreshPlay(g);
  SetHand(g, 0, hzStop, hzAccident, hzOutOfGas, hzFlat, hzLimit, ck25);
  CheckEq(CheckPlay(g, 1, tgOpponent), ErrNoEffect, 'stop on non-moving opponent');
  g.pl[1].battle := rmGo;
  CheckEq(CheckPlay(g, 1, tgOpponent), ErrOK, 'stop on moving opponent');
  CheckEq(CheckPlay(g, 2, tgOpponent), ErrOK, 'accident on moving opponent');
  g.pl[1].safe[0] := true;
  CheckEq(CheckPlay(g, 2, tgOpponent), ErrImmune, 'ace blocks accident');
  CheckEq(CheckPlay(g, 3, tgOpponent), ErrOK, 'ace does not block out of gas');
  g.pl[1].safe[0] := false;
  g.pl[1].safe[3] := true;
  CheckEq(CheckPlay(g, 1, tgOpponent), ErrImmune, 'Right of Way blocks stop');
  CheckEq(CheckPlay(g, 5, tgOpponent), ErrImmune, 'Right of Way blocks limit');
  g.pl[1].battle := ckNone;
  CheckEq(CheckPlay(g, 2, tgOpponent), ErrOK, 'RoW holder with empty pile can be hit by accident');
  g.pl[1].safe[3] := false;
  g.pl[1].battle := rmGo;
  g.pl[1].limited := true;
  CheckEq(CheckPlay(g, 5, tgOpponent), ErrNoEffect, 'limit on already-limited opponent')
end;

procedure TestRoW;
begin
  FreshPlay(g);
  SetHand(g, 0, ck100, rmGo, ck25, ck25, ck25, ck25);
  g.pl[0].safe[3] := true;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrOK, 'RoW: moves with empty battle pile');
  CheckEq(CheckPlay(g, 2, tgSelf), ErrNoNeed, 'RoW: Go is pointless');
  g.pl[0].battle := hzAccident;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrBlocked, 'RoW: accident still blocks');
  g.pl[0].battle := rmRepairs;
  CheckEq(CheckPlay(g, 1, tgSelf), ErrOK, 'RoW: repairs alone is enough to move')
end;

procedure TestPhase;
var msg: ErrStr;
begin
  FreshPlay(g);
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.ph := phDraw;
  CheckEq(CheckPlay(g, 1, tgDiscard), ErrPhase, 'cannot play before drawing');
  g.ph := phPlay;
  CheckEq(CheckPlay(g, 0, tgDiscard), ErrNoCard, 'index 0 invalid');
  CheckEq(CheckPlay(g, 7, tgDiscard), ErrNoCard, 'index past hand invalid');
  CheckEq(CheckPlay(g, 3, tgDiscard), ErrOK, 'discard always legal');
  ErrText(ErrNeedGo, msg);
  Check(length(msg) > 0, 'ErrText fills in text for a real error');
  ErrText(ErrOK, msg);
  CheckEq(length(msg), 0, 'ErrText is empty for ErrOK')
end;

procedure TestDrawPlay;
var err: integer;
begin
  NewGame(g, 7);
  DrawCard(g);
  CheckEq(g.pl[0].handN, 7, 'draw: 7 cards');
  CheckEq(RemainingDeck(g), 93, 'draw: 93 left');
  Check(g.ph = phPlay, 'draw: play phase');
  g.pl[0].battle := rmGo;
  g.pl[0].hand[1] := ck50;
  DoPlay(g, 1, tgSelf, err);
  CheckEq(err, ErrOK, 'play 50 ok');
  CheckEq(g.pl[0].miles, 50, 'miles are 50');
  CheckEq(g.pl[0].handN, 6, 'hand back to 6');
  CheckEq(g.turn, 1, 'turn passes');
  Check(g.ph = phDraw, 'next player draws');
  CheckEq(g.gone, 1, 'one card gone')
end;

procedure TestIllegalNoChange;
var err: integer;
begin
  FreshPlay(g);
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  DoPlay(g, 1, tgSelf, err);
  CheckEq(err, ErrNeedGo, 'illegal play reports why');
  CheckEq(g.pl[0].handN, 6, 'illegal play keeps hand');
  CheckEq(g.turn, 0, 'illegal play keeps turn');
  Check(g.ph = phPlay, 'illegal play keeps phase');
  CheckEq(g.gone, 0, 'illegal play removes nothing')
end;

procedure TestDiscard;
var err: integer;
begin
  FreshPlay(g);
  SetHand(g, 0, ck25, hzStop, ck25, ck25, ck25, ck25);
  DoPlay(g, 2, tgDiscard, err);
  CheckEq(err, ErrOK, 'discard ok');
  Check(g.discardTop = hzStop, 'discard pile shows top');
  CheckEq(g.turn, 1, 'discard ends turn');
  CheckEq(g.pl[0].handN, 5, 'discard shrinks hand')
end;

procedure TestSafeties;
var err: integer;
begin
  FreshPlay(g);
  SetHand(g, 0, sfAce, sfTank, sfPunct, sfRoW, ck25, ck25);
  g.pl[0].battle := hzAccident;
  DoPlay(g, 1, tgSelf, err);
  CheckEq(err, ErrOK, 'play ace');
  Check(g.pl[0].safe[0], 'ace now in play');
  Check(g.pl[0].battle = rmRepairs, 'ace cures accident');
  CheckEq(g.turn, 0, 'safety gives extra turn (R1)');
  Check(g.ph = phDraw, 'extra turn starts with a draw');
  g.ph := phPlay;
  g.pl[0].battle := hzOutOfGas;
  DoPlay(g, 1, tgSelf, err);
  Check(g.pl[0].battle = rmGas, 'tank cures out of gas');
  g.ph := phPlay;
  g.pl[0].battle := hzFlat;
  DoPlay(g, 1, tgSelf, err);
  Check(g.pl[0].battle = rmSpare, 'puncture-proof cures flat');
  g.ph := phPlay;
  g.pl[0].battle := hzStop;
  g.pl[0].limited := true;
  DoPlay(g, 1, tgSelf, err);
  Check(g.pl[0].battle = rmGo, 'RoW clears stop');
  Check(not g.pl[0].limited, 'RoW clears limit');
  Check(g.pl[0].safe[3], 'RoW now in play')
end;

procedure SetupCoup(var d: Game; haz, sf: CardKind);
begin
  FreshPlay(d);
  SetHand(d, 0, haz, ck25, ck25, ck25, ck25, ck25);
  SetHand(d, 1, sf, ck50, ck50, ck50, ck50, ck50);
  d.pl[1].battle := rmGo
end;

procedure TestCoup;
var err, before: integer;
begin
  SetupCoup(g, hzAccident, sfAce);
  DoPlay(g, 1, tgOpponent, err);
  CheckEq(err, ErrOK, 'coup: attack ok');
  Check(g.ph = phCoup, 'coup: waiting for decision');
  CheckEq(g.coupSeat, 1, 'coup: victim is seat 1');
  Check(g.pl[1].battle = hzAccident, 'coup: hazard is applied until resolved');
  before := RemainingDeck(g);
  ResolveCoup(g, true);
  Check(g.pl[1].safe[0], 'coup: ace in play');
  Check(g.pl[1].viaCoup[0], 'coup: flagged as coup');
  Check(g.pl[1].battle = rmGo, 'coup: prior battle state restored');
  CheckEq(g.pl[1].handN, 6, 'coup: replacement drawn');
  CheckEq(RemainingDeck(g), before - 1, 'coup: one card from the pile');
  CheckEq(g.turn, 1, 'coup: victim takes the next turn (R2)');
  Check(g.ph = phDraw, 'coup: turn starts with a draw');
  CheckEq(g.pl[0].handN, 5, 'coup: attacker lost the hazard card');

  SetupCoup(g, hzAccident, sfAce);
  DoPlay(g, 1, tgOpponent, err);
  ResolveCoup(g, false);
  Check(g.pl[1].battle = hzAccident, 'decline: hazard stands');
  Check(not g.pl[1].safe[0], 'decline: safety stays in hand');
  CheckEq(g.turn, 1, 'decline: turn passes');
  Check(g.ph = phDraw, 'decline: victim draws next');

  SetupCoup(g, hzStop, sfRoW);
  DoPlay(g, 1, tgOpponent, err);
  Check(g.ph = phCoup, 'coup: stop answered by RoW');
  ResolveCoup(g, true);
  Check(g.pl[1].battle = rmGo, 'coup: stop undone');
  Check(g.pl[1].safe[3], 'coup: RoW in play');

  SetupCoup(g, hzLimit, sfRoW);
  DoPlay(g, 1, tgOpponent, err);
  Check(g.pl[1].limited, 'coup: limit applied');
  ResolveCoup(g, true);
  Check(not g.pl[1].limited, 'coup: limit undone');

  SetupCoup(g, hzAccident, sfTank);
  DoPlay(g, 1, tgOpponent, err);
  Check(g.ph = phDraw, 'no matching safety: no coup window');
  CheckEq(g.turn, 1, 'no matching safety: turn passes');

  SetupCoup(g, hzAccident, sfAce);
  g.deckNext := NumCards + 1;
  g.pl[1].handN := 1;
  g.pl[1].hand[1] := sfAce;
  DoPlay(g, 1, tgOpponent, err);
  ResolveCoup(g, true);
  CheckEq(g.pl[1].handN, 0, 'coup with empty pile: no replacement');
  CheckEq(g.turn, 0, 'coup with empty pile and empty hand: no stuck turn');
  Check(g.ph = phDraw, 'coup with empty pile: play continues')
end;

procedure TestWin;
var err: integer;
begin
  FreshPlay(g);
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975;
  DoPlay(g, 1, tgSelf, err);
  CheckEq(err, ErrOK, 'win: 975+25 ok');
  Check(g.ph = phOver, 'win: hand over');
  CheckEq(g.tripBy, 0, 'win: seat 0 completed the trip');
  Check(not g.delayedTrip, 'win: not delayed with cards left');
  FreshPlay(g);
  SetHand(g, 0, ck25, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975;
  g.deckNext := NumCards + 1;
  DoPlay(g, 1, tgSelf, err);
  Check(g.delayedTrip, 'win: delayed once the pile is empty')
end;

procedure TestDeckEmpty;
var err: integer;
begin
  FreshPlay(g);
  g.deckNext := NumCards + 1;
  g.pl[0].handN := 1; g.pl[0].hand[1] := ck25;
  g.pl[1].handN := 0;
  DoPlay(g, 1, tgDiscard, err);
  Check(g.ph = phOver, 'both hands empty ends the hand');

  FreshPlay(g);
  g.deckNext := NumCards + 1;
  g.pl[0].handN := 2; g.pl[0].hand[1] := ck25; g.pl[0].hand[2] := ck25;
  g.pl[1].handN := 0;
  DoPlay(g, 1, tgDiscard, err);
  CheckEq(g.turn, 0, 'opponent with no cards is skipped');
  Check(g.ph = phDraw, 'skipped turn continues in draw phase');
  DrawCard(g);
  Check(g.ph = phPlay, 'drawing from an empty pile just moves to play');
  CheckEq(g.pl[0].handN, 1, 'empty pile draws nothing')
end;

procedure TestScoring;
begin
  NewGame(g, 3);
  g.pl[0].miles := 350;
  CheckEq(HandPoints(g, 0), 350, 'score: miles only');

  NewGame(g, 3);
  g.pl[0].safe[0] := true;
  g.pl[0].safe[1] := true;  g.pl[0].viaCoup[1] := true;
  CheckEq(HandPoints(g, 0), 100 + 100 + 300, 'score: two safeties, one coup');

  NewGame(g, 3);
  g.pl[0].safe[0] := true; g.pl[0].safe[1] := true;
  g.pl[0].safe[2] := true; g.pl[0].safe[3] := true;
  CheckEq(HandPoints(g, 0), 400 + 300, 'score: all four safeties bonus');

  NewGame(g, 3);
  g.pl[0].miles := 1000; g.pl[0].n200 := 1; g.pl[1].miles := 300;
  g.tripBy := 0;
  CheckEq(HandPoints(g, 0), 1000 + 400, 'score: plain trip with a 200');
  CheckEq(HandPoints(g, 1), 300, 'score: loser keeps miles only');

  g.pl[0].n200 := 0;
  CheckEq(HandPoints(g, 0), 1000 + 400 + 300, 'score: safe trip bonus');
  g.delayedTrip := true;
  CheckEq(HandPoints(g, 0), 1000 + 400 + 300 + 300, 'score: delayed bonus');
  g.pl[1].miles := 0;
  CheckEq(HandPoints(g, 0), 1000 + 400 + 300 + 300 + 500, 'score: shutout bonus')
end;

procedure TestLegalMoves;
var ml: MoveList; i: integer;
begin
  FreshPlay(g);
  SetHand(g, 0, ck25, rmGo, hzStop, sfAce, ck50, ck25);
  LegalMoves(g, ml);
  Check(ml.n >= 6, 'every card can at least be discarded');
  for i := 1 to ml.n do
    CheckEq(CheckPlay(g, ml.m[i].hand, ml.m[i].tgt), ErrOK, 'listed move is legal');
  g.ph := phDraw;
  LegalMoves(g, ml);
  CheckEq(ml.n, 0, 'no moves outside the play phase');
  CheckEq(CheckInvariants(g), 0, 'fresh game satisfies invariants')
end;

procedure TestAI;
var mv: PlayMove;
begin
  FreshPlay(g);
  SetHand(g, 0, ck100, rmRepairs, ck25, hzStop, sfTank, ck50);
  g.pl[0].battle := hzAccident;
  AIChoose(g, mv);
  CheckEq(mv.hand, 2, 'AI cures its accident first');
  Check(mv.tgt = tgSelf, 'AI cures on itself');

  FreshPlay(g);
  SetHand(g, 0, ck100, rmRepairs, ck25, hzStop, sfAce, ck50);
  g.pl[0].battle := hzAccident;
  AIChoose(g, mv);
  CheckEq(mv.hand, 5, 'AI uses the matching safety instead of repairs (immunity + extra turn)');

  FreshPlay(g);
  SetHand(g, 0, ck100, ck25, rmGo, hzStop, ck75, ck50);
  g.pl[0].battle := rmGo;
  g.pl[0].miles := 975;
  AIChoose(g, mv);
  CheckEq(mv.hand, 2, 'AI takes the winning 25');

  FreshPlay(g);
  SetHand(g, 0, ck100, ck25, rmGo, hzStop, ck75, ck50);
  g.pl[0].battle := hzStop;
  AIChoose(g, mv);
  CheckEq(mv.hand, 3, 'AI plays Go when stopped');

  FreshPlay(g);
  SetHand(g, 0, hzAccident, ck25, ck25, ck25, ck25, ck25);
  g.pl[0].battle := rmGo;
  g.pl[1].battle := rmGo;
  AIChoose(g, mv);
  CheckEq(mv.hand, 1, 'AI attacks a moving opponent');
  Check(mv.tgt = tgOpponent, 'AI attack targets the opponent');

  FreshPlay(g);
  SetHand(g, 0, sfAce, ck25, hzStop, hzStop, hzStop, hzStop);
  g.pl[0].battle := rmGo;
  AIChoose(g, mv);
  CheckEq(mv.hand, 2, 'AI prefers mileage to spending a safety early')
end;

procedure TestCoupRoWCures;
var err: integer;
begin
  { (a) victim is moving but already limited, hit by Stop, answers with Right of Way }
  SetupCoup(g, hzStop, sfRoW);
  g.pl[1].limited := true;
  DoPlay(g, 1, tgOpponent, err);
  CheckEq(err, ErrOK, 'coup RoW (a): stop played on a limited mover');
  ResolveCoup(g, true);
  Check(g.pl[1].safe[3], 'coup RoW (a): RoW in play');
  Check(not g.pl[1].limited, 'coup RoW (a): RoW clears the old limit');

  { (b) victim is stopped, hit by Limit, answers with Right of Way }
  SetupCoup(g, hzLimit, sfRoW);
  g.pl[1].battle := hzStop;
  DoPlay(g, 1, tgOpponent, err);
  CheckEq(err, ErrOK, 'coup RoW (b): limit played on a stopped car');
  ResolveCoup(g, true);
  Check(g.pl[1].safe[3], 'coup RoW (b): RoW in play');
  Check(g.pl[1].battle = rmGo, 'coup RoW (b): RoW clears the old stop');
  Check(not g.pl[1].limited, 'coup RoW (b): limit undone')
end;

procedure TestInvariantsCatchBadStates;
begin
  FreshPlay(g);
  CheckEq(CheckInvariants(g), 0, 'invariants: clean state passes');
  FreshPlay(g);
  g.pl[0].safe[3] := true; g.pl[0].limited := true;
  Check(CheckInvariants(g) <> 0, 'invariants: RoW while limited is inconsistent');
  FreshPlay(g);
  g.pl[0].safe[3] := true; g.pl[0].battle := hzStop;
  Check(CheckInvariants(g) <> 0, 'invariants: RoW while stopped is inconsistent');
  FreshPlay(g);
  g.pl[1].viaCoup[2] := true;
  Check(CheckInvariants(g) <> 0, 'invariants: coup flag without the safety');
  FreshPlay(g);
  g.tripBy := 0;
  Check(CheckInvariants(g) <> 0, 'invariants: tripBy without 1000 miles');
  FreshPlay(g);
  g.tripBy := 0; g.pl[0].miles := 1000;
  CheckEq(CheckInvariants(g), 0, 'invariants: genuine trip passes');
  FreshPlay(g);
  g.turn := 2;
  Check(CheckInvariants(g) <> 0, 'invariants: turn must be 0 or 1');
  FreshPlay(g);
  g.coupSeat := 1;
  Check(CheckInvariants(g) <> 0, 'invariants: stale coupSeat outside the coup phase')
end;

{@TESTS}

begin
  TestDeck;
  TestSeeds;
  TestMovement;
  TestRemedies;
  TestAttacks;
  TestRoW;
  TestPhase;
  TestDrawPlay;
  TestIllegalNoChange;
  TestDiscard;
  TestSafeties;
  TestCoup;
  TestWin;
  TestDeckEmpty;
  TestScoring;
  TestLegalMoves;
  TestAI;
  TestCoupRoWCures;
  TestInvariantsCatchBadStates;
  {@CALLS}
  Summary
end.
