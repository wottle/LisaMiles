import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lint_lisa_subset import find_problems


class LintTests(unittest.TestCase):
    def kinds(self, text, lisa_only=False):
        return [m for _, m in find_problems(text, lisa_only)]

    def test_clean_code_passes(self):
        self.assertEqual(self.kinds("unit X;\ninterface\nimplementation\nend.\n"), [])

    def test_forbidden_constructs_flagged(self):
        for code in ["exit(Foo);", "inc(i);", "dec(i);", "break;", "continue;",
                     "x := a shl 2;", "x := a shr 2;", "Result := 1;",
                     "otherwise x := 1;", "uses crt;", "{$mode tp}", "(*$R+*)"]:
            self.assertTrue(self.kinds(code), code)

    def test_comments_and_strings_are_ignored(self):
        self.assertEqual(self.kinds("{ no exit(x) or inc(y) here }\n"), [])
        self.assertEqual(self.kinds("(* uses break *)\n"), [])
        self.assertEqual(self.kinds("s := 'exit(x)';\n"), [])

    def test_unsized_string_flagged_but_sized_string_ok(self):
        self.assertTrue(self.kinds("function f(e: integer): string;\n"))
        self.assertTrue(self.kinds("var s: String;\n"))
        self.assertEqual(self.kinds("type ErrStr = string[63];\n"), [])
        self.assertEqual(self.kinds("type ErrStr = string [63];\n"), [])

    def test_function_returning_string_flagged(self):
        # Lisa Pascal error 118: a function result must be scalar, subrange or pointer.
        self.assertTrue(self.kinds("function ErrText(e: integer): ErrStr;\n"))
        self.assertTrue(self.kinds("function Name: string;\n"))
        self.assertTrue(self.kinds("function Name(n: integer): string[20];\n"))
        self.assertEqual(self.kinds("function Count(s: ErrStr): integer;\n"), [])
        self.assertEqual(self.kinds("procedure ErrText(e: integer; var s: ErrStr);\n"), [])

    def test_unit_directive_allowed_other_directives_not(self):
        self.assertEqual(self.kinds("uses (*$U MILES/LOGIC.OBJ *) MilesLogic;\n"), [])
        self.assertTrue(self.kinds("(*$R+ *)\n"))
        self.assertTrue(self.kinds("{$mode tp}\n"))

    def test_portable_uses_only_miles_units(self):
        self.assertEqual(self.kinds("uses MilesLogic, MilesLayout;\n"), [])
        self.assertEqual(self.kinds("uses (*$U MILES/A.OBJ *) MilesLogic,\n     (*$U MILES/B.OBJ *) MilesLayout;\n"), [])
        self.assertTrue(self.kinds("uses MilesLogic, QuickDraw;\n"))
        self.assertTrue(self.kinds("uses crt;\n"))

    def test_brace_inside_a_brace_comment_flagged(self):
        self.assertTrue(self.kinds("{ installed as {T202}Obj }\n"))
        self.assertTrue(self.kinds("{ a { b }\n", lisa_only=True))
        self.assertEqual(self.kinds("{ a comment }\nx := 1; { another }\n"), [])
        self.assertEqual(self.kinds("p := pos('}', s);\n"), [])

    def test_lisa_only_profile_allows_toolbox_idioms_but_not_known_errors(self):
        ok = "uses QuickDraw;\nexit(Foo);\ncase x of\n  1: y;\n  otherwise\nend;\n"
        self.assertEqual(self.kinds(ok, lisa_only=True), [])
        self.assertTrue(self.kinds("function F: Str255;\n", lisa_only=True))
        self.assertTrue(self.kinds("x := 1; { café }\n", lisa_only=True))

    def test_non_ascii_flagged(self):
        self.assertTrue(self.kinds("x := 1; { café }\n"))

    def test_line_numbers(self):
        probs = find_problems("a := 1;\nb := 2;\nexit(c);\n")
        self.assertEqual(probs[0][0], 3)


if __name__ == "__main__":
    unittest.main()
