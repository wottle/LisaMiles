program test_icons;

uses TestKit, MilesLogic, MilesIcons;

var
  w: IconBuf;

{ How many black pixels (1 bits) does a decoded icon hold? }
function CountBits(var b: IconBuf; words: integer): integer;
var i, j, n: integer; v: longint;
begin
  n := 0;
  for i := 0 to words - 1 do begin
    v := b[i];
    if v < 0 then v := v + 65536;
    for j := 0 to 15 do begin
      if (v mod 2) = 1 then n := n + 1;
      v := v div 2
    end
  end;
  CountBits := n
end;

procedure TestMapping;
begin
  CheckEq(IconOf(hzAccident), 1, 'icons: accident');
  CheckEq(IconOf(hzOutOfGas), 2, 'icons: out of gas');
  CheckEq(IconOf(hzFlat), 3, 'icons: flat tire');
  CheckEq(IconOf(hzLimit), 4, 'icons: speed limit');
  CheckEq(IconOf(hzStop), 5, 'icons: stop');
  CheckEq(IconOf(rmRepairs), 6, 'icons: repairs');
  CheckEq(IconOf(rmGas), 7, 'icons: gasoline');
  CheckEq(IconOf(rmSpare), 8, 'icons: spare tire');
  CheckEq(IconOf(rmEndLimit), 9, 'icons: end of limit');
  CheckEq(IconOf(rmGo), 10, 'icons: go');
  CheckEq(IconOf(sfAce), 11, 'icons: ace');
  CheckEq(IconOf(sfTank), 12, 'icons: tank');
  CheckEq(IconOf(sfPunct), 13, 'icons: tough tires');
  CheckEq(IconOf(sfRoW), 14, 'icons: right of way');
  CheckEq(IconOf(ck25), 15, 'icons: distance cards share the road');
  CheckEq(IconOf(ck200), 15, 'icons: ...all of them');
  CheckEq(IconOf(ckNone), 0, 'icons: no card, no icon')
end;

procedure TestSizes;
var i: integer;
begin
  for i := 1 to NumIcons - 1 do
    CheckEq(IconRows(i), IconH, 'icons: a card icon is 24 rows');
  CheckEq(IconRows(NumIcons), RoadH, 'icons: the road is 12 rows');
  CheckEq(IconRowBytes, 6, 'icons: 3 words (6 bytes) per row')
end;

procedure TestDecoding;
var i, rows, n: integer; allOk: boolean;
begin
  allOk := true;
  for i := 1 to NumIcons do begin
    for n := 0 to IconWords - 1 do w[n] := 0;
    LoadIcon(i, w);
    rows := IconRows(i);
    n := CountBits(w, rows * 3);
    if n <> IconBits(i) then begin
      allOk := false;
      writeln('icon ', i, ': decoded ', n, ' black pixels, expected ', IconBits(i))
    end;
    if (n < 30) or (n > 700) then begin
      allOk := false;
      writeln('icon ', i, ' looks blank or solid: ', n)
    end
  end;
  Check(allOk, 'icons: every icon decodes to exactly the black pixels the generator drew')
end;

procedure TestRowsOutsideAreWhite;
var i, r, c: integer; ok: boolean; v: longint;
begin
  { the 36-pixel-wide icons leave the last 12 bits of each row's third word clear }
  ok := true;
  for i := 1 to NumIcons do begin
    LoadIcon(i, w);
    for r := 0 to IconRows(i) - 1 do begin
      v := w[r * 3 + 2];
      if v < 0 then v := v + 65536;
      c := v mod 4096;
      if c <> 0 then ok := false
    end
  end;
  Check(ok, 'icons: nothing is drawn past the 36th pixel of a row')
end;

begin
  TestMapping;
  TestSizes;
  TestDecoding;
  TestRowsOutsideAreWhite;
  Summary
end.
