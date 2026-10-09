#!/usr/bin/env python3
"""Reject Pascal constructs that Lisa Pascal may not accept.

Two profiles:
  portable (default)  the units that also compile on the Mac (LOGIC, LAYOUT, CTRL): a conservative
                      subset, plus 'uses' may only name other MilesXxx units.
  --lisa-only         the units that only ever compile on the Lisa (GLOBALS, DRAW, MAIN): they use
                      Lisa toolbox units, exit(), otherwise, etc.; only mistakes the Lisa compiler
                      is known to reject are checked.
"""
import re
import sys

PORTABLE_RULES = [
    (r"\bexit\s*\(", "exit(...) is not portable; restructure the code"),
    (r"\binc\s*\(", "inc() is not available in Lisa Pascal"),
    (r"\bdec\s*\(", "dec() is not available in Lisa Pascal"),
    (r"\bbreak\b", "break is not available in Lisa Pascal"),
    (r"\bcontinue\b", "continue is not available in Lisa Pascal"),
    (r"\bshl\b", "shl is not available in Lisa Pascal"),
    (r"\bshr\b", "shr is not available in Lisa Pascal"),
    (r"\bresult\b", "Result is Free Pascal only; assign to the function name"),
    (r"\botherwise\b", "otherwise differs between compilers; use if-chains"),
    (r"\bstring\b(?!\s*\[)", "unsized string: declare a sized one such as string[63]"),
]

# Found by compiling on a real Lisa (error 118): a function result must be scalar, subrange or pointer.
LISA_RULES = [
    (r"\bfunction\b[^;]*:\s*(?:string|ErrStr|CapStr|Str255)\s*(?:\[[^\]]*\])?\s*;",
     "a function cannot return a string (Lisa Pascal error 118); use a procedure with a var parameter"),
]

ALLOWED_DIRECTIVE = re.compile(r"\(\*\$U [^*]*\*\)")      # (*$U MILES/LOGIC.OBJ *) names a unit's object file


def blank(match):
    return re.sub(r"[^\n]", " ", match.group(0))


def brace_comment_problems(text):
    """A { comment ends at the FIRST }, so a stray { or } inside one turns the rest into code."""
    problems = []
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
        if c == "'":                                   # skip a string literal
            j = i + 1
            while j < n and text[j] != "'" and text[j] != "\n":
                j += 1
            i = j + 1
            continue
        if c == "{":
            j = i + 1
            while j < n and text[j] != "}":
                if text[j] == "{":
                    problems.append((line, "'{' inside a { } comment ends it early"))
                if text[j] == "\n":
                    line += 1
                j += 1
            i = j + 1
            continue
        i += 1
    return problems


def find_problems(text, lisa_only=False):
    problems = []
    for n, line in enumerate(text.split("\n"), 1):
        if any(ord(ch) > 127 for ch in line):
            problems.append((n, "non-ASCII character"))
        if not lisa_only and re.search(r"\{\$|\(\*\$(?!U )", line):
            problems.append((n, "compiler directives are not portable"))
    problems += brace_comment_problems(text)
    code = re.sub(r"\(\*.*?\*\)", blank, text, flags=re.S)       # this also removes (*$U ... *)
    code = re.sub(r"\{.*?\}", blank, code, flags=re.S)
    code = re.sub(r"'[^'\n]*'", blank, code)
    rules = LISA_RULES if lisa_only else PORTABLE_RULES + LISA_RULES
    for n, line in enumerate(code.split("\n"), 1):
        for pattern, message in rules:
            if re.search(pattern, line, flags=re.I):
                problems.append((n, message))
    if not lisa_only:
        for m in re.finditer(r"\buses\b([^;]*);", code, flags=re.I):
            line = code.count("\n", 0, m.start()) + 1
            for name in m.group(1).split(","):
                if not re.fullmatch(r"\s*Miles[A-Za-z0-9]*\s*", name, flags=re.I):
                    problems.append((line, "portable units may only use other Miles units, not '%s'" % name.strip()))
    return sorted(set(problems))


def main(argv):
    args = argv[1:]
    lisa_only = "--lisa-only" in args
    paths = [a for a in args if not a.startswith("--")] or ["src/MILES-LOGIC.TEXT"]
    bad = 0
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            problems = find_problems(handle.read(), lisa_only)
        for n, message in problems:
            print("%s:%d: %s" % (path, n, message))
        bad += len(problems)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
