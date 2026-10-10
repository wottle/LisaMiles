#!/usr/bin/env python3
"""Run Alex Anderson-McLeod's lisa_serial_transfer.py with the serial lines a LisaFPGA needs.

On a LisaFPGA the Lisa only transmits while the host holds RTS high and DTR LOW.  Alex's script opens the port with
pyserial's defaults (DTR high), so the Lisa never answers.  This wrapper opens the same script but forces RTS=1 /
DTR=0 right after every port is opened.  It is harmless with LisaEm's pseudo-tty (/tmp/b).

  python3 tools/lisa_send_alex.py ~/path/to/lisa_serial_transfer.py PORT SRC [options of Alex's script]

  # real LisaFPGA over its USB serial port (about 3-4 ms per byte; 90 KB of source takes about 8 minutes):
  echo | python3 tools/lisa_send_alex.py ~/LisaSourceCompilation/scripts/lisa_serial_transfer.py \\
      /dev/cu.usbserial-140 src/MILES-MAIN.TEXT --no_handshake --baud_rate 28800 --throttle_tx_millis 4
  # LisaEm (pseudo-tty):
  echo | python3 tools/lisa_send_alex.py ... /tmp/b src --no_handshake --throttle_tx_millis 1

Run it from a scratch directory (the script writes log.txt into the current directory), on the Lisa first run
`<ALEX/TRANSFER_NO_HANDSHAKE` in Workshop, and give the script a single file or a folder of MILES-*.TEXT files.
Needs pyserial.  Alex's script is not part of this repository (see its README for the Lisa-side tools).
"""
import runpy
import sys


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    import serial                      # imported late so the usage text works without pyserial

    original = serial.Serial.__init__

    def patched(self, *args, **kwargs):
        original(self, *args, **kwargs)
        self.rts = True
        self.dtr = False

    serial.Serial.__init__ = patched
    script = sys.argv[1]
    sys.argv = [script] + sys.argv[2:]
    runpy.run_path(script, run_name="__main__")
    return 0


if __name__ == "__main__":
    sys.exit(main())
