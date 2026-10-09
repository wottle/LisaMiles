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
