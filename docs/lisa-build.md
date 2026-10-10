# Building 1000 Miles from source

The game is written in Lisa Pascal and built **on a Lisa** (real, LisaFPGA, or LisaEm) in the Workshop 3.0. The Mac
runs the portable rules and UI-logic tests, and sends source text to the Lisa. Everything here was learned on real
hardware; `docs/spikes/phase1-pipeline.md` has the original evidence.

## 1. On the Mac: test first
```
make all        # rules tests, UI tests, icon tests, a 6000-game simulation, and the Lisa-Pascal lint rules
```
Needs Free Pascal (`brew install fpc`) and Python 3 (Pillow only for regenerating icons). The portable units
(`MILES-LOGIC`, `MILES-LAYOUT`, `MILES-CTRL`, `MILES-ICONS`) compile unchanged under Free Pascal; the Lisa-only units
(`MILES-GLOBALS`, `MILES-DRAW`, `MILES-MAIN`) are checked by `tools/lint_lisa_subset.py`.

## 2. Get the source onto the Lisa
You need a Workshop 3.0 disk (the stock "Lisa Office System 3.0 and Workshop 3.0" image is fine) and Alex
Anderson-McLeod's transfer tools (`ALEX/TRANSFER`, `ALEX/RECEIVE`, from his LisaSourceCompilation repository,
and his `lisa_serial_transfer.py`). A Lisa file name is the Mac name with `-` turned into `/` and no `.TEXT`:
`src/MILES-GLOBALS.TEXT` becomes `MILES/GLOBALS`. Send all the `src/MILES-*.TEXT` files the first time; later
only the ones that changed. Link order, and so build order, is in `MILES/COMP` and `MILES/LINK`.

### Option A: LisaEm (fastest, recommended for development)
1. In LisaEm: File > Preferences > Ports: Serial B = **PseudoTTY**, xon/xoff off, path `/tmp/b`; I/O ROM **88**; put
   your Workshop image in the parallel-port ProFile slot. Apply and restart. Throttle > 512MHz makes builds quick.
2. On the Lisa (Workshop): `R` then `<ALEX/TRANSFER_NO_HANDSHAKE` (a copy of `ALEX/TRANSFER` with both handshake
   values set to 0). The screen goes blank: the console is now on Serial B.
3. On the Mac, from a scratch directory:
   `echo | python3 lisa_serial_transfer.py /tmp/b path/to/src --no_handshake --throttle_tx_millis 1`
4. The Lisa often stays blank afterwards. Run `python3 tools/lisa_console_main.py` (needs `picocom`) to hand the
   console back, then go to section 3.

### Option B: a real Lisa or LisaFPGA over serial
Same as above, but with the Lisa's serial port. A LisaFPGA only answers while the host holds RTS high and DTR low, which
Alex's script does not do, so run it through the wrapper (about 3 to 4 milliseconds per byte; all of `src/` takes about
nine minutes; if the receiver ever stalls ("never acknowledged our EOF command") the Lisa must be reset and that file
re-sent):
```
echo | python3 tools/lisa_send_alex.py path/to/lisa_serial_transfer.py /dev/cu.usbserial-140 src \
    --no_handshake --baud_rate 28800 --throttle_tx_millis 4
```
The script's own "return to known state" warning is harmless. The LisaFPGA's SERIAL B SOURCE switch must be on USB.

### Option C: the Workshop Transfer program (works anywhere, one file at a time)
On the Lisa: `T` (TransferProgram), Control > Receive From Remote > Receive All Text, then type the Lisa name. On the Mac:
`python3 tools/lisa_send_text.py PORT src/MILES-GLOBALS.TEXT --line-delay-ms 150`. The Lisa transmits only with
RTS=1/DTR=0 here too. Delete an existing file first (`F`, `D`) if it is being replaced.

## 3. Build and install
1. First time only, create placeholders so the build script's deletes succeed: `F`, `C`, source `MILES/MAKE.TEXT`,
   destination `{T202}Obj`; again with destination `{T202}PHRASE`.
2. Optional: write the tool icon. Compile, link and run `MILES/MKICON` (`P`, `L` with `IOSPASLIB`, `R`); it prints
   "Wrote 814 bytes" and creates `{T202}icon`. Do this **before** step 3 so the installer picks the icon up.
3. `R` then `<MILES/MAKE` (the `<` is essential; without it you get error 130). It compiles and links everything, builds
   the phrase file, and installs tool 202. The tool number lives only in `MAKE`.
4. Leave Workshop: `Q`, confirm, then `A` (Environments) and choose the Office System. The tool appears as
   **1000 Miles**. The first build on a real Lisa is slow.

To compile by hand and see errors, the order is `LOGIC`, `ICONS`, `LAYOUT`, `CTRL`, `GLOBALS`, `DRAW`, `MAIN`:
`P`, input `MILES/LAYOUT`, Return for the listing, accept `MILES/LAYOUT.OBJ`. Link inputs one per line: `MILES/MAIN`,
`MILES/GLOBALS`, `MILES/DRAW`, `MILES/CTRL`, `MILES/LAYOUT`, `MILES/ICONS`, `MILES/LOGIC`, `IOSPASLIB`, `SYS1LIB`,
`SYS2LIB`, an empty line, then output `MILES/MILES`. Success is `Output is executable`.

## 4. The tool icon
`tools/gen_toolicon.py` regenerates `src/MILES-MKICON.TEXT` (the icon, as hex, inside a small program that writes
`{T202}icon`) and `docs/mockups/tool_icon_preview.png`. How the Office System uses the four 48x32 layers was found with
a probe icon: layer B is drawn black, layer C is drawn white on top while the icon is selected, nothing is painted
behind the icon on the desktop, and only B's shape is clickable. `tools/mockups/icon_options.py` has the other
candidate designs.

## 5. Making the release floppy
1. In LisaEm, boot the Office System with 1000 Miles installed. File > **Insert blank diskette**, save it as
   `dist/1000-miles.dc42` (a 400 KB Sony image). Initialize the disk when the Office System asks.
2. Drag the **1000 Miles** icon onto the floppy; eject; `python3 tools/check_dc42.py dist/1000-miles.dc42`.
3. Test on a clean Office System (no 1000 Miles installed): insert the floppy, drag the tool onto the hard disk,
   open it and play. Attach the `.dc42` to a release; it is not committed.

## Lisa Pascal rules learned along the way (each is a lint rule or a review item)
- A function result must be scalar, subrange or pointer (error 118): never a string or record.
- A `{ }` comment ends at the first `}`: never put a brace inside a comment, including `{T202}` names.
- Identifiers are significant only in their first 8 characters, case-insensitive, and also collide with the
  Toolbox's own names (a variable called `iconData` did). `tools/lint_lisa_subset.py --collisions` checks ours.
- A unit that uses another unit must list, before it, every unit named in that unit's interface; every non-intrinsic
  unit is preceded by `(*$U MILES/X.OBJ *)`.
- There is no boolean short-circuit; `integer` is 16-bit; keep lines to 105 columns.
- Phrase-file alert and phrase numbers must ascend; comments sit on their own line; blank lines are structural.
- The Window Manager clock runs at the CPU clock, so it speeds up when the Lisa is overclocked: the game calibrates it
  against the one-second battery clock (see `InitClockCal` in `MILES-GLOBALS`).
- Never show an alert from inside the click that caused it: its mouse-up dismisses it. Defer it to the idle loop.
