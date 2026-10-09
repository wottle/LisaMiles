# Phase 1 spike: does the Minesweeper pipeline work on our hardware?

Questions: (A) serial transfer -> `MAKE` -> run, on the real Lisa/LisaFPGA. (B) Does the same
build complete inside LisaEm? Fill in each result; "PASS/FAIL + notes".

## Setup (Mac)
```bash
cd ~/Documents/Development
git clone https://github.com/alexthecat123/los_minesweeper.git
cd los_minesweeper && ls            # check for a LICENSE file; note it here: ______
python3 -m venv .venv && .venv/bin/pip install pyserial
ls /dev/cu.*                        # find the serial adapter, e.g. /dev/cu.usbserial-XXXX
```

## A. Real Lisa / LisaFPGA
1. Cable: Lisa Serial B <-> Mac USB-serial adapter. Result: ______
2. On the Lisa, in Workshop, run `<ALEX/TRANSFER` (requires the transfer receiver from the
   Minesweeper README; if missing, install from its prebuilt `.dc42` image). Result: ______
3. On the Mac: `.venv/bin/python tools/lisa_serial_transfer.py <port> src/` (expect 5-10 min).
   Result (all files received? errors?): ______
4. On the Lisa: `<MINESWEEPER/MAKE`. Result (compile/link/install messages): ______
5. Launch "Minesweeper" from the Office System; play one game. Result: ______
6. Note baud/handshake gotchas, DSR behaviour, anything surprising: ______

## B. LisaEm (Mac)
1. Version/build used and how Workshop 3.0 is installed in it: ______
2. Run the same `<MINESWEEPER/MAKE` (sources via disk image or paste). Result: ______
3. If it fails: exact error text, and whether it is the reported linker/NMI/address-error issue: ______

## Decision
- Which target is the primary test loop? ______
- Is `LisaEm` usable for UI smoke tests (yes/no/partial)? ______

## C. MILES-LOGIC first compile (do after A works)
Files to send with the transfer script (it turns `-` into `/`): `src/MILES-LOGIC.TEXT` arrives as
`MILES/LOGIC.TEXT`, `src/MILES-LCOMP.TEXT` as `MILES/LCOMP.TEXT`.
1. Transfer both files to the Lisa. Result: ______
2. In Workshop run `<MILES/LCOMP`. Expected: compiles with no errors and `MILES/LOGIC.OBJ` exists.
3. Paste the full compiler output here: ______
4. If anything is rejected, send the exact error text back: the fix is made in `MILES-LOGIC.TEXT`,
   re-verified on the Mac (`make all`), and a rule is added to `tools/lint_lisa_subset.py`.

## Findings from the first hardware session (2026-10-09)
- `LOS Compilation Base.image` (author's 50 MB image) fails to boot on this LisaFPGA at both 15 MHz and
  5 MHz: Level 7 interrupt + system error 10738. Copy on the SD card is byte-identical (SHA-256 0997069...aea00).
  Stock images, including `Lisa Office System 3.0 and Workshop 3.0.image`, boot fine.
- Workaround that works: boot the stock Workshop 3.0 image, set Preferences > Connect Device Software >
  Serial B = "Serial cable", then use the Workshop `T` (TransferProgram) to receive text files over Serial B
  (9600 baud, parity none, full duplex, Receive All Text). Mac side: `tools/lisa_send_text.py`.
  Used this to get `ALEX/TRANSFER.TEXT` and `ALEX/RECEIVE.TEXT` onto the Lisa; `RECEIVE` compiled
  (`P`, third prompt is the OBJECT file) and linked (`L`: `ALEX/RECV`, `IOSPASLIB`, output `ALEX/RECEIVE`).
- LisaFPGA Serial B over USB (`LisaFPGA Serial B`, /dev/cu.usbserial-140) after `<ALEX/TRANSFER` (console moved to
  Serial B, 28800 baud, DTR handshakes): the Lisa transmits ONLY when the Mac drives RTS=1 and DTR=0
  (pyserial's default DTR=1 mutes it). CTS/DSR/CD/RI always read 0. The Minesweeper script waits on DSR, so it
  stalls; a patched copy (RTS=1, DTR=0, selectable flow control) got the Lisa to print its
  `SYSTEM-MGR:` prompt, but the Lisa redraws that prompt for ANY received byte (q, Q, ?, CR) and never acts on
  commands, and keys pressed on the Lisa keyboard produced nothing on the serial line. Mac -> Lisa command input
  over the exec-configured console is therefore NOT working; cause unknown (ask the LisaFPGA/Minesweeper author).
- Do NOT run a transfer script that sends file contents when the Lisa has not acknowledged: it types the
  file into whatever prompt is showing. (The script continues after its own warnings.)
- Error 130 "Could not open program file" came from running `ALEX/TRANSFER` without the `<` prefix.

## C. MILES-LOGIC first compile: RESULT (2026-10-09)
- Sent `src/MILES-LOGIC.TEXT` (628 lines, 18,829 bytes) with `tools/lisa_send_text.py --line-delay-ms 150`
  into the Workshop Transfer program (Serial B, 9600 baud, no handshake, Receive All Text), then `P`
  (Pascal) with object file `MILES/LOGIC.OBJ`.
- First compile: one error class, **Error 118, "Function result type must be scalar, subrange, or pointer"**
  (`function ErrText(...): ErrStr`). Fixed by making `ErrText` a procedure with a `var` parameter
  (commit 4766971) and adding a lint rule for string-returning functions.
- Second compile: **no errors.** The engine, AI, and scoring compile unchanged on Lisa Pascal.
- Constructs the code review had flagged as portability risks that Lisa Pascal ACCEPTED: long integer
  literals (2147483647, 127773), implicit longint -> integer assignment in `RandBelow`, `with` statements,
  enumeration `for` loops, `string[63]` sized strings, a boolean constant, 16-bit integers with longint
  arithmetic, `exit`-free control flow.
- Not yet verified on the Lisa: running the code (no UI yet), so behaviour is covered only by the Mac tests.

## Phase 3: portable UI units on the Lisa (Checkpoint 0, 2026-10-09)
- `MILES/LAYOUT` compiled with no errors on the first try.
- `MILES/CTRL` first failed with "identifier declared twice" on `MsgComputerCoup`: **Lisa Pascal treats
  identifiers that agree in their first 8 characters as the same name** (`MsgComputerTurn`/`MsgComputerCoup`).
  Renamed to `MsgCpuCoup`; `tools/lint_lisa_subset.py --collisions` now checks every unit together
  (it also caught `DrawCard` vs `DrawCardFace`/`DrawCardBack` in the not-yet-written drawing unit).
- After the rename `MILES/CTRL` compiled with no errors.
