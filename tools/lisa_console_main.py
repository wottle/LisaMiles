#!/usr/bin/env python3
"""Hand the Lisa's console back to its screen after an ALEX/TRANSFER session (LisaEm pseudo-tty).

Alex's script sends s-c-m-y itself but LisaEm's pty does not always deliver it, so the Lisa stays
blank.  Attaching through picocom (a real terminal on the pty) and sending the keys slowly works.

  python3 tools/lisa_console_main.py [/tmp/b]
"""
import os, pty, select, sys, time


def main(port):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp('picocom', ['picocom', '-b', '9600', port])
    out = b''

    def read_for(seconds):
        nonlocal out
        end = time.time() + seconds
        while time.time() < end:
            ready, _, _ = select.select([fd], [], [], 0.2)
            if ready:
                try:
                    out += os.read(fd, 4096)
                except OSError:
                    return

    read_for(5)
    for key in b'scmy':                 # System-mgr, Console, Main, Yes
        os.write(fd, bytes([key]))
        read_for(3)
    read_for(5)
    os.write(fd, b'\x01\x18')           # Ctrl-A Ctrl-X leaves picocom
    read_for(2)
    ok = b'Moving Console to Main' in out
    print('console moved to Main' if ok else 'no confirmation seen; check the Lisa screen')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/b'))
