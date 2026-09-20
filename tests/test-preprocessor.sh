#!/usr/bin/env bash
# test-preprocessor.sh — Unit tests for adoc_docx_preprocessor.py
# Exercises process_adoc() directly (no asciidoctor/pandoc in the loop):
# pipe escaping, badge contract, changelog bullets, :noanswers:,
# signatures edge cases, and target-aware testcase markers.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$REPO_ROOT" << 'PYEOF'
import importlib.util
import sys

repo_root = sys.argv[1]
mod_path = repo_root + "/templates/_base/adoc_docx_preprocessor.py"
spec = importlib.util.spec_from_file_location(
    "adoc_docx_preprocessor", mod_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        print(f"  PASS: {name}")
        PASS += 1
    else:
        print(f"  FAIL: {name}")
        FAIL += 1


def process(content, template, target):
    return mod.process_adoc(content, template, target)


# Common header for synthetic documents
HEADER = ":lang: en\n:version: 1.0.0\n\n"


def changelog(entry):
    return "++++\n\\begin{changelog}\n" + entry + "\n\\end{changelog}\n++++\n"


print("=== Pipe escaping ===")

# 1. Pipe in changelog item is escaped for the AsciiDoc table cell
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Use (Step | Action) pairs.}"), 'guide', 'md')
check("pipe escape: cell content escaped", "(Step \\| Action)" in out)
check("pipe escape: a| cell row", "| 1.0.0 | 2026-01-01 a|" in out)
check("pipe escape: bullet line", "* Use (Step \\| Action) pairs." in out)

# 2. Already-escaped pipe is not escaped twice
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item already escaped \\| pipe}"), 'guide', 'md')
check("no double-escape: \\| kept", "escaped \\| pipe" in out)
check("no double-escape: no \\\\|", "\\\\|" not in out)

print("=== Badge contract ===")

# 3. [.badge]#text# — docx target emits the docx_fix sentinel
out = process(HEADER + "[.badge]#Ready#\n", 'guide', 'docx')
check("badge docx: sentinel with text", "**[BADGE:Ready]**" in out)

# 4. [.badge]#text# — md target keeps the text, no sentinel
out = process(HEADER + "[.badge]#Ready#\n", 'guide', 'md')
check("badge md: text preserved", "**[Ready]**" in out)
check("badge md: no sentinel", "BADGE:" not in out)

# 5. Result roles still map to fixed markers (regression)
out = process(HEADER + "[.result-pass]#Pass#\n", 'testbook', 'docx')
check("result-pass role: **[PASS]**", "**[PASS]**" in out)

print("=== Changelog bullets ===")

# 6. Multi-item entries render as bullets, not a ' + ' join
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item First change. \\item Second change.}"), 'guide', 'md')
check("changelog bullets: a| cell", "a|" in out)
check("changelog bullets: two bullet lines",
      "* First change." in out and "* Second change." in out)
check("changelog bullets: no ' + ' join", "' + '" not in out)

print("=== POC changelog ===")

# 7. POC template converts the changelog passthrough
POC_CL = HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}{\\item POC change.}")
out = process(POC_CL, 'poc', 'md')
check("poc changelog: table present", "| Version | Date | Changes" in out)

# 8. :nochangelog: suppresses it
out = process(":lang: en\n:version: 1.0.0\n:nochangelog:\n\n"
              + changelog("  \\changelogentry{1.0.0}{2026-01-01}"
                          "{\\item POC change.}"), 'poc', 'md')
check("poc changelog: suppressed by :nochangelog:",
      "| Version | Date | Changes" not in out)

print("=== :noanswers: ===")

# 9. Test Result and Remarks hidden with :noanswers: (PDF parity)
TC = ("++++\n\\begin{testcase}{Demo}\n"
      "  \\testresult{Pass}\n"
      "  \\testremarks{Works}\n"
      "\\end{testcase}\n++++\n")
out = process(HEADER + TC, 'testbook', 'docx')
check("noanswers off: Test Result shown", "Test Result" in out)
check("noanswers off: Remarks shown", "Remarks" in out)
out = process(":lang: en\n:version: 1.0.0\n:noanswers:\n\n" + TC,
              'testbook', 'docx')
check("noanswers on: Test Result hidden", "Test Result" not in out)
check("noanswers on: Remarks hidden", "Remarks" not in out)

print("=== Inline LaTeX conversions ===")

# 10. \texttt{text} → `text`
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Run \\texttt{make} now}"), 'guide', 'md')
check("texttt: `make`", "`make`" in out)

# 11. $\to$ → →
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item a $\\to$ b}"), 'guide', 'md')
check("to arrow: a → b", "a \u2192 b" in out)

# 12. LaTeX quotes → Unicode curly quotes
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Use ``make'' today}"), 'guide', 'md')
check("latex quotes: “make”", "\u201cmake\u201d" in out)

print("=== Signatures ===")

# 13. Single-cell row: no IndexError, empty second cell keeps the grid
SIG1 = ("++++\n\\begin{signatures}\n"
        "\\signaturecell{Alice}{Dev}{a@x}{City}\n"
        "\\end{signatures}\n++++\n")
sig_out = None
try:
    sig_out = process(HEADER + SIG1, 'poc', 'md')
    ok = True
except Exception:
    ok = False
check("signatures 1-cell row: no exception", ok)
check("signatures 1-cell row: Alice present",
      sig_out is not None and "Alice" in sig_out)
check("signatures 1-cell row: empty second cell",
      sig_out is not None
      and any(line == "|" for line in sig_out.split("\n")))

# 2-cell row: both signatures present
SIG2 = ("++++\n\\begin{signatures}\n"
        "\\signaturecell{Alice}{Dev}{a@x}{City} & "
        "\\signaturecell{Bob}{Lead}{b@x}{Town}\n"
        "\\end{signatures}\n++++\n")
out = process(HEADER + SIG2, 'poc', 'md')
check("signatures 2-cell row: both present",
      "Alice" in out and "Bob" in out)

print("=== Target-aware testcase markers ===")

# 14. TESTCASE-START/END only for the docx target
TC2 = ("++++\n\\begin{testcase}{Demo}\n"
       "  \\testobjective{Check.}\n"
       "\\end{testcase}\n++++\n")
out = process(HEADER + TC2, 'testbook', 'docx')
check("testcase markers: docx emits TESTCASE-START", "TESTCASE-START" in out)
out = process(HEADER + TC2, 'testbook', 'md')
check("testcase markers: md skips TESTCASE-START", "TESTCASE-START" not in out)

print("=== \\badge command ===")

# 15. \badge{text} — same target-aware contract as [.badge]#text#
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Badge \\badge{New} here}"), 'guide', 'docx')
check("badge command: docx sentinel", "**[BADGE:New]**" in out)

print("=== Cover meta line ===")

# 16. Version meta line on the cover; :nochangelog: hides it (L12)
out = process(HEADER + "Body.\n", 'guide', 'md')
check("cover meta: **v1.0.0** shown", "**v1.0.0**" in out)
out = process(":lang: en\n:version: 1.0.0\n:nochangelog:\n\nBody.\n",
              'guide', 'md')
check("cover meta: hidden by :nochangelog:", "**v1.0.0**" not in out)

print(f"\nResults: {PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)
PYEOF
