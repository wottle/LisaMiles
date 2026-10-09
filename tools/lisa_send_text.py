#!/usr/bin/env python3
"""Send a text file to a Lisa running the Workshop 'Transfer' program (Receive From Remote).

Line endings become CR (what the Lisa expects), text is encoded as Mac Roman, lines go out one
at a time with a pause after each so a slow receiver cannot overrun, and one extra CR is sent at
the end because the Transfer program does not add a final RETURN and the Pascal compiler needs one.

  python3 tools/lisa_send_text.py PORT FILE [--baud 9600] [--line-delay-ms 100]
  python3 tools/lisa_send_text.py --dry-run FILE        (no serial port needed)
"""
import argparse
import sys
import time


def prepare_lines(raw: bytes):
    """Split on any of LF / CRLF / CR; return a list of Mac Roman encoded lines, no terminators."""
    text = raw.decode("utf-8")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if text.endswith("\n"):
        text = text[:-1]
    return [line.encode("mac-roman") for line in text.split("\n")]


def main(argv):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("items", nargs="+", metavar="PORT FILE | FILE",
                   help="PORT and FILE, or just FILE with --dry-run")
    p.add_argument("--baud", type=int, default=9600)
    p.add_argument("--line-delay-ms", type=int, default=100)
    p.add_argument("--dry-run", action="store_true", help="only show what would be sent")
    args = p.parse_args(argv)

    if args.dry_run:
        if len(args.items) != 1:
            p.error("--dry-run takes just FILE")
        port, path = None, args.items[0]
    else:
        if len(args.items) != 2:
            p.error("give PORT and FILE")
        port, path = args.items
    with open(path, "rb") as handle:
        lines = prepare_lines(handle.read())
    total = sum(len(line) + 1 for line in lines) + 1          # +1 CR per line, +1 final CR
    longest = max(len(line) for line in lines)
    print("%s: %d lines, %d bytes to send, longest line %d" % (path, len(lines), total, longest))
    if args.dry_run:
        return 0
    import serial  # imported late so --dry-run works without pyserial

    with serial.Serial(port, args.baud, bytesize=8, parity="N", stopbits=1, timeout=1,
                       rtscts=False, xonxoff=False) as lisa:
        for number, line in enumerate(lines, 1):
            lisa.write(line + b"\r")
            lisa.flush()
            time.sleep(args.line_delay_ms / 1000.0)
            if number % 10 == 0:
                print("  sent %d / %d lines" % (number, len(lines)))
        lisa.write(b"\r")                                    # final RETURN
        lisa.flush()
        time.sleep(0.5)
    print("done: %d lines sent" % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
