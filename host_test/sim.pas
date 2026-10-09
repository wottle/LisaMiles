program sim;

uses MilesLogic;

const
  MaxSteps = 3000;

var
  g: Game;
  n, seed: longint;
  code: integer;
  steps, bad, failures, trips, coups, i, totalSteps: longint;
  pts0, pts1: longint;
  sigA, sigB: longint;

function ParseCount: longint;
var v: longint; c: integer;
begin
  v := 1000;
  if ParamCount >= 1 then begin
    val(ParamStr(1), v, c);
    if c <> 0 then v := 1000
  end;
  ParseCount := v
end;

procedure RunGame(sd: longint; smart0, smart1: boolean);
var mv: PlayMove; err: integer;
begin
  NewGame(g, sd);
  steps := 0;
  bad := 0;
  while (g.ph <> phOver) and (steps < MaxSteps) and (bad = 0) do begin
    steps := steps + 1;
    if g.ph = phDraw then DrawCard(g)
    else if g.ph = phCoup then ResolveCoup(g, true)
    else begin
      if ((g.turn = 0) and smart0) or ((g.turn = 1) and smart1) then AIChoose(g, mv)
      else RandomChoose(g, mv);
      DoPlay(g, mv.hand, mv.tgt, err);
      if err <> ErrOK then bad := 100 + err
    end;
    if bad = 0 then bad := CheckInvariants(g)
  end;
  if g.ph <> phOver then bad := 99
end;

function Signature: longint;
begin
  Signature := steps * 100000 + g.pl[0].miles * 100 + g.pl[1].miles + HandPoints(g, 0)
end;

begin
  n := ParseCount;
  failures := 0; trips := 0; coups := 0; totalSteps := 0; pts0 := 0; pts1 := 0;
  for seed := 1 to n do
    for i := 0 to 2 do begin
      RunGame(seed, i <> 2, i <> 1);          { 0: AI v AI, 1: AI v random, 2: random v AI }
      if bad <> 0 then begin
        failures := failures + 1;
        writeln('FAIL seed ', seed, ' mode ', i, ' code ', bad, ' after ', steps, ' steps')
      end;
      if g.tripBy >= 0 then trips := trips + 1;
      totalSteps := totalSteps + steps;
      if i = 0 then begin
        pts0 := pts0 + HandPoints(g, 0);
        pts1 := pts1 + HandPoints(g, 1)
      end;
      for code := 0 to 3 do begin
        if g.pl[0].viaCoup[code] then coups := coups + 1;
        if g.pl[1].viaCoup[code] then coups := coups + 1
      end
    end;
  RunGame(42, true, true);  sigA := Signature;
  RunGame(42, true, true);  sigB := Signature;
  if sigA <> sigB then begin
    failures := failures + 1;
    writeln('FAIL: same seed produced different games')
  end;
  writeln(n * 3, ' games; ', failures, ' failures; ', trips, ' completed trips; ',
          totalSteps div (n * 3), ' avg steps; ', coups, ' coups fourre');
  writeln('AI v AI average points: seat0 ', pts0 div n, ', seat1 ', pts1 div n);
  if failures > 0 then halt(1)
end.
