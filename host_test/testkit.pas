unit TestKit;

interface

procedure Check(ok: boolean; name: string);
procedure CheckEq(got, want: longint; name: string);
procedure Summary;

implementation

var
  nRun, nFail: integer;

procedure Check(ok: boolean; name: string);
begin
  nRun := nRun + 1;
  if not ok then begin
    nFail := nFail + 1;
    writeln('FAIL: ', name)
  end
end;

procedure CheckEq(got, want: longint; name: string);
begin
  nRun := nRun + 1;
  if got <> want then begin
    nFail := nFail + 1;
    writeln('FAIL: ', name, ' (got ', got, ', want ', want, ')')
  end
end;

procedure Summary;
begin
  writeln(nRun, ' checks, ', nFail, ' failed');
  if nFail > 0 then halt(1)
end;

begin
  nRun := 0;
  nFail := 0
end.
