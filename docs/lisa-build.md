# Building 1000 Miles on the Lisa

Everything here was learned on real hardware; see `docs/spikes/phase1-pipeline.md` for the evidence.

## Getting source files onto the Lisa (the method that works)
The Minesweeper author's serial pipeline does not work on our LisaFPGA yet, so use the Workshop's own
**Transfer program** once per file.

One-time setup, on the Lisa (stock `Lisa Office System 3.0 and Workshop 3.0.image`):
1. `S` (System-Mgr) -> Preferences -> Connect Device Software -> Serial B -> **Serial cable**. Leave.
2. At `WORKSHOP:` press `?`, then `T` (TransferProgram). Menus: Connector **Serial B**, Baud **9600**,
   Parity **None**, Handshake **None**, Duplex **Full**.

For each file (Lisa name = Mac file name with `-` -> `/`, without `.TEXT`: `src/MILES-GLOBALS.TEXT` -> `MILES/GLOBALS`):
1. On the Lisa: Transfer program -> Control -> **Receive From Remote** -> **Receive All Text**; type the
   Lisa name (the `.text` extension is added for you).
2. On the Mac, in a real Terminal window:
   `python3 tools/lisa_send_text.py /dev/cu.usbserial-140 src/MILES-GLOBALS.TEXT --line-delay-ms 150`
   (needs `pyserial`; the Minesweeper `.venv` has it).
3. On the Lisa: toggle Receive From Remote off. After the last file: Control -> Exit.
4. If the file already exists, delete it first: `F` (File-Mgr), `D`, `MILES/GLOBALS.TEXT`.

## Compile and link by hand (the first time, so errors are visible)
Order matters: `LOGIC`, `LAYOUT`, `CTRL`, `GLOBALS`, `DRAW`, `MAIN`.
- Compile: `P`; `Input file`: `MILES/LAYOUT`; `List file`: Return; object file: `MILES/LAYOUT.OBJ`.
- Link: `L`; inputs one per line: `MILES/MAIN`, `MILES/GLOBALS`, `MILES/DRAW`, `MILES/CTRL`, `MILES/LAYOUT`,
  `MILES/LOGIC`, `IOSPASLIB`, `SYS1LIB`, `SYS2LIB`; an empty line; listing: Return; output: `MILES/MILES`.
  Success is the line `Output is executable`.

## Install and run
- First time only, create placeholder files so the build script's deletes succeed:
  `F`, `C`, source `MILES/MAKE.TEXT`, destination `{T202}Obj`; and again with destination `{T202}PHRASE`.
- Run the build script: `R` then `<MILES/MAKE` (the `<` is essential; without it you get error 130).
- Leave Workshop for the Office System: `Q`, confirm, then `A` (Environments window), choose the Office System.
  The tool appears as **1000 Miles**.

## Lisa Pascal rules learned so far (each is a lint rule or a review item)
- A function result must be scalar, subrange or pointer (error 118): never a string or record.
- A `{ }` comment ends at the first `}`: never put a brace inside a comment.
- A unit that uses another unit must list, before it, every unit named in that unit's interface.
- Identifiers must differ within their FIRST 8 CHARACTERS (case-insensitive): Lisa Pascal reports "identifier declared twice" for `MsgComputerTurn` / `MsgComputerCoup` and would for `DrawCard` / `DrawCardFace`. `make lint` checks this across every unit together.
- Booleans are not short-circuited: guard array indexes with nested `if`, never with `and`.
- Alert/phrase numbers must ascend; comments occupy their own line; blank lines are structural.


## Fast rebuild after changing ONE source file (about 3 minutes instead of 10)
1. Send the changed file, then `P` it (see above); if it is a unit other units use, recompile those too.
2. Link: `L`, the same nine inputs, empty line, Return, output `MILES/MILES`.
3. Install the new executable over the old one: `F`, `D`, `{T202}Obj`, `Y`; then `C`, source `MILES/MILES.OBJ`,
   destination `{T202}Obj`; `Q`. (Only changes to the phrase file need the full `<MILES/MAKE`.)
4. Relaunch the tool from the Office System.
