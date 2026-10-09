#!/usr/bin/env python3
"""Reject Pascal constructs outside the conservative Lisa Pascal subset."""
import re
import sys

FORBIDDEN = [
    (r"\bexit\s*\(", "exit(...) is not portable; restructure the code"),
    (r"\binc\s*\(", "inc() is not available in Lisa Pascal"),
    (r"\bdec\s*\(", "dec() is not available in Lisa Pascal"),
    (r"\bbreak\b", "break is not available in Lisa Pascal"),
    (r"\bcontinue\b", "continue is not available in Lisa Pascal"),
    (r"\bshl\b", "shl is not available in Lisa Pascal"),
    (r"\bshr\b", "shr is not available in Lisa Pascal"),
    (r"\bresult\b", "Result is Free Pascal only; assign to the function name"),
    (r"\botherwise\b", "otherwise differs between compilers; use if-chains"),
    (r"\buses\b", "MILES-LOGIC must not depend on any unit"),
    (r"\bstring\b(?!\s*\[)", "unsized string: declare a sized one such as string[63]"),
    (r"\bfunction\b[^;]*:\s*(?:string|ErrStr)\s*(?:\[[^\]]*\])?\s*;",
     "a function cannot return a string (Lisa Pascal error 118); use a procedure with a var parameter"),
]


def blank(match):
    return re.sub(r"[^\n]", " ", match.group(0))


def find_problems(text):
    problems = []
    lines = text.split("\n")
    for n, line in enumerate(lines, 1):
        if re.search(r"\{\$|\(\*\$", line):
            problems.append((n, "compiler directives are not portable"))
        if any(ord(ch) > 127 for ch in line):
            problems.append((n, "non-ASCII character"))
    code = re.sub(r"\(\*.*?\*\)", blank, text, flags=re.S)
    code = re.sub(r"\{.*?\}", blank, code, flags=re.S)
    code = re.sub(r"'[^'\n]*'", blank, code)
    for n, line in enumerate(code.split("\n"), 1):
        for pattern, message in FORBIDDEN:
            if re.search(pattern, line, flags=re.I):
                problems.append((n, message))
    return sorted(problems)


def main(argv):
    path = argv[1] if len(argv) > 1 else "src/MILES-LOGIC.TEXT"
    with open(path, encoding="utf-8") as handle:
        problems = find_problems(handle.read())
    for n, message in problems:
        print("%s:%d: %s" % (path, n, message))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
