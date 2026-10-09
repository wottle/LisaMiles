import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lint_lisa_subset import find_problems


class LintTests(unittest.TestCase):
    def kinds(self, text):
        return [m for _, m in find_problems(text)]

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

    def test_non_ascii_flagged(self):
        self.assertTrue(self.kinds("x := 1; { café }\n"))

    def test_line_numbers(self):
        probs = find_problems("a := 1;\nb := 2;\nexit(c);\n")
        self.assertEqual(probs[0][0], 3)


if __name__ == "__main__":
    unittest.main()
