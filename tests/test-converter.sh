#!/usr/bin/env bash
# test-converter.sh — Unit tests for huawei-latex-converter.rb
# Feeds minimal AsciiDoc snippets through the converter and verifies
# the LaTeX output contains expected strings.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONVERTER="$REPO_ROOT/templates/_base/huawei-latex-converter.rb"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
PASS=0; FAIL=0; SKIP=0

# ── Helpers ──────────────────────────────────────────────────────────────────

convert() {
  local adoc="$1"
  local adoc_file="$TMPDIR/test.adoc"
  printf '%s\n' "$adoc" > "$adoc_file"
  if ! asciidoctor -b huawei-latex -r "$CONVERTER" "$adoc_file" -o "$TMPDIR/test.tex" 2>/dev/null; then
    echo ""
    return 1
  fi
  cat "$TMPDIR/test.tex"
}

assert_contains() {
  local label="$1" expected="$2" actual="$3"
  if printf '%s' "$actual" | grep -qF "$expected"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "        expected to contain: $expected"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" unexpected="$2" actual="$3"
  if printf '%s' "$actual" | grep -qF "$unexpected"; then
    echo "  FAIL: $label"
    echo "        expected NOT to contain: $unexpected"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  fi
}

assert_matches() {
  local label="$1" pattern="$2" actual="$3"
  if printf '%s' "$actual" | grep -qE "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "        expected to match regex: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

# ════════════════════════════════════════════════════════════════════════════
## 1. Document structure
# ════════════════════════════════════════════════════════════════════════════
echo "=== 1. Document structure ==="

OUT=$(convert '= My Document
:template: guide

== Section One

Content here.

=== Subsection Alpha

Sub-content here.')
assert_contains "Title → setdoctitle"    '\setdoctitle{My Document}' "$OUT"
assert_contains "Section → section"      '\section{Section One}'     "$OUT"
assert_contains "Subsection → subsection" '\subsection{Subsection Alpha}' "$OUT"

# Subsubsection and paragraph levels
OUT=$(convert '= Test
:template: guide

== L1

=== L2

==== L3

===== L4')
assert_contains "Level 3 → subsubsection" '\subsubsection{L3}' "$OUT"
assert_contains "Level 4 → paragraph"     '\paragraph{L4}'     "$OUT"

# Document boundaries
OUT=$(convert '= Test
:template: guide

Text.')
assert_contains "Has begin document" '\begin{document}' "$OUT"
assert_contains "Has end document"   '\end{document}'   "$OUT"
assert_contains "Has makecover"      '\makecover'       "$OUT"
assert_contains "Has maketoc"        '\maketoc'         "$OUT"
assert_contains "Has startbody"     '\startbody'       "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 2. Inline formatting
# ════════════════════════════════════════════════════════════════════════════
echo "=== 2. Inline formatting ==="

OUT=$(convert '= Test
:template: guide

Bold *text* here.')
assert_contains "Bold → textbf" '\textbf{text}' "$OUT"

OUT=$(convert '= Test
:template: guide

Italic _text_ here.')
assert_contains "Italic → emph" '\emph{text}' "$OUT"

OUT=$(convert '= Test
:template: guide

Mono `code` here.')
assert_contains "Monospaced → inlinecode" '\inlinecode{code}' "$OUT"

OUT=$(convert '= Test
:template: guide

Link http://example.com[Example].')
assert_contains "Link → weblink" '\weblink{http://example.com}{Example}' "$OUT"

OUT=$(convert '= Test
:template: guide

This is #highlighted# text.')
assert_contains "Highlight → textcolor huaweired" '\textcolor{huaweired}{highlighted}' "$OUT"

OUT=$(convert '= Test
:template: guide

Super^script^ text.')
assert_contains "Superscript → textsuperscript" '\textsuperscript{script}' "$OUT"

OUT=$(convert '= Test
:template: guide

Sub~script~ text.')
assert_contains "Subscript → textsubscript" '\textsubscript{script}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 3. Special character escaping
# ════════════════════════════════════════════════════════════════════════════
echo "=== 3. Special character escaping ==="

OUT=$(convert '= Test
:template: guide

Underscore in mono `my_variable` here.')
assert_contains "Underscore in monospaced → escaped" '\inlinecode{my\_variable}' "$OUT"

OUT=$(convert '= Test
:template: guide

Percent 100%.')
assert_contains "Percent → escaped" '100\%' "$OUT"

OUT=$(convert '= Test
:template: guide

Dollar $100.')
assert_contains "Dollar → escaped" '\$100' "$OUT"

OUT=$(convert '= Test
:template: guide

Ampersand A & B.')
assert_contains "Ampersand → escaped" 'A \& B' "$OUT"

OUT=$(convert '= Test
:template: guide

Hash C #3.')
assert_contains "Hash → escaped" 'C \#3' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 4. Admonitions
# ════════════════════════════════════════════════════════════════════════════
echo "=== 4. Admonitions ==="

OUT=$(convert '= Test
:template: guide

NOTE: This is a note.')
assert_contains "NOTE → infobox env" '\begin{infobox}' "$OUT"
assert_contains "NOTE → infobox end" '\end{infobox}'   "$OUT"

OUT=$(convert '= Test
:template: guide

WARNING: This is a warning.')
assert_contains "WARNING → warning env" '\begin{warning}' "$OUT"
assert_contains "WARNING → warning end" '\end{warning}'   "$OUT"

OUT=$(convert '= Test
:template: guide

TIP: This is a tip.')
assert_contains "TIP → tip env" '\begin{tip}' "$OUT"
assert_contains "TIP → tip end" '\end{tip}'   "$OUT"

OUT=$(convert '= Test
:template: guide

CAUTION: Be careful.')
assert_contains "CAUTION → warning env" '\begin{warning}' "$OUT"

OUT=$(convert '= Test
:template: guide

IMPORTANT: Read this.')
assert_contains "IMPORTANT → warning env" '\begin{warning}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 5. Tables
# ════════════════════════════════════════════════════════════════════════════
echo "=== 5. Tables ==="

OUT=$(convert '= Test
:template: guide

[.hutable]
|===
| Col A | Col B

| Data 1 | Data 2
|===')
assert_contains "hutable → begin hutable" '\begin{hutable}' "$OUT"
assert_contains "hutable → end hutable"   '\end{hutable}'   "$OUT"
assert_contains "hutable → m{} column spec" 'm{'              "$OUT"
assert_contains "hutable → header rowcolor"  '\rowcolor{huaweired}' "$OUT"
assert_contains "hutable → thd in header"   '\thd{Col A}'          "$OUT"

# Table without header row
OUT=$(convert '= Test
:template: guide

[.hutable]
|===
| Header A | Header B
| Cell 1 | Cell 2
|===')
assert_contains "hutable no header → tbody" '\tbody' "$OUT"
assert_not_contains "hutable no header → no rowcolor" '\rowcolor{huaweired}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 6. Code blocks
# ════════════════════════════════════════════════════════════════════════════
echo "=== 6. Code blocks ==="

OUT=$(convert '= Test
:template: guide

[source,bash]
----
echo "hello world"
----')
assert_contains "source bash → begin code"    '\begin{code}[bash]' "$OUT"
assert_contains "source bash → end code"      '\end{code}'         "$OUT"
assert_contains "source bash → code content"  'echo "hello world"' "$OUT"

# Code without language
OUT=$(convert '= Test
:template: guide

----
plain code
----')
assert_contains "no lang → begin code" '\begin{code}' "$OUT"
assert_not_contains "no lang → no bracket" '\begin{code}[' "$OUT"

# Code with special chars (no escaping in code blocks)
OUT=$(convert '= Test
:template: guide

[source,python]
----
x = 100 % 3
y = "$var"
----')
assert_contains "code special chars → raw percent" '100 % 3' "$OUT"
assert_contains "code special chars → raw dollar"  '"$var"'  "$OUT"

# Literal block
OUT=$(convert '= Test
:template: guide

....
literal text
....')
assert_contains "literal → begin code" '\begin{code}' "$OUT"
assert_contains "literal → content"    'literal text' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 7. Images
# ════════════════════════════════════════════════════════════════════════════
echo "=== 7. Images ==="

OUT=$(convert '= Test
:template: guide

image::file.png[alt]')
assert_contains "image → image cmd" '\image{file.png}' "$OUT"

OUT=$(convert '= Test
:template: guide

image::photo.png[alt,600]')
assert_contains "image with px width → linewidth" '\image[width=0.8\linewidth]{photo.png}' "$OUT"

OUT=$(convert '= Test
:template: guide

image::diagram.png[alt,50%]')
assert_contains "image with % width → fraction" '\image[width=0.5\linewidth]{diagram.png}' "$OUT"

OUT=$(convert '= Test
:template: guide

.Caption text
image::arch.png[alt]')
assert_contains "image with caption → imagecap" '\imagecap{arch.png}{Caption text}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 8. Header attributes
# ════════════════════════════════════════════════════════════════════════════
echo "=== 8. Header attributes ==="

OUT=$(convert '= Test
:template: guide

Text.')
assert_contains "template guide → documentclass guide" '\documentclass{guide}' "$OUT"

OUT=$(convert '= Test
:template: technical

Text.')
assert_contains "template technical → documentclass technical" '\documentclass{technical}' "$OUT"

OUT=$(convert '= Test
:template: guide
:lang: pt

Text.')
assert_contains "lang pt → portuguese option" '\documentclass[portuguese]{guide}' "$OUT"

OUT=$(convert '= Test
:template: guide
:version: 1.0.0

Text.')
assert_contains "version → setdocversion" '\setdocversion{1.0.0}' "$OUT"

OUT=$(convert '= Test
:template: guide
:date: 2025-01-15

Text.')
assert_contains "date → setdocdate" '\setdocdate{2025-01-15}' "$OUT"

OUT=$(convert '= Test
:template: guide
:authors: John Doe

Text.')
assert_contains "authors → setdocauthors" '\setdocauthors{John Doe}' "$OUT"

OUT=$(convert '= Test
:template: guide
:authors: Jane
:noauthors:

Text.')
assert_contains "noauthors → class option" '\documentclass[noauthors]{guide}' "$OUT"
assert_not_contains "noauthors → no setdocauthors" '\setdocauthors' "$OUT"

OUT=$(convert '= Test
:template: guide
:notime:

Text.')
assert_contains "notime → class option" '\documentclass[notime]{guide}' "$OUT"

OUT=$(convert '= Test
:template: guide
:nochangelog:

Text.')
assert_contains "nochangelog → class option" '\documentclass[nochangelog]{guide}' "$OUT"

OUT=$(convert '= Test
:template: testbook
:noanswers:

Text.')
assert_contains "noanswers → class option" '\documentclass[noanswers]{testbook}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 9. Edge cases
# ════════════════════════════════════════════════════════════════════════════
echo "=== 9. Edge cases ==="

# Empty document (no body content)
OUT=$(convert '= Test
:template: guide')
assert_contains "empty doc → has documentclass" '\documentclass{guide}' "$OUT"
assert_contains "empty doc → has begin document" '\begin{document}' "$OUT"
assert_contains "empty doc → has end document"   '\end{document}'   "$OUT"

# Unicode characters passed through (XeLaTeX handles)
OUT=$(convert '= Test
:template: guide

Unicode: café, naïve, über, 日本語, 中文')
assert_contains "unicode → café passed through" 'café'   "$OUT"
assert_contains "unicode → 日本語 passed through" '日本語' "$OUT"
assert_contains "unicode → 中文 passed through" '中文'   "$OUT"

# Nested formatting (bold + italic)
OUT=$(convert '= Test
:template: guide

Bold with *bold _italic_* inside.')
assert_contains "nested bold+italic → textbf" '\textbf{' "$OUT"

# Page break
OUT=$(convert '= Test
:template: guide

Before.

<<<

After.')
assert_contains "page break → clearpage" '\clearpage' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 10. Lists
# ════════════════════════════════════════════════════════════════════════════
echo "=== 10. Lists ==="

OUT=$(convert '= Test
:template: guide

* Item one
* Item two
* Item three')
assert_contains "ulist → begin itemize" '\begin{itemize}' "$OUT"
assert_contains "ulist → end itemize"   '\end{itemize}'   "$OUT"
assert_contains "ulist → item"          '\item Item one'  "$OUT"

OUT=$(convert '= Test
:template: guide

. First
. Second
. Third')
assert_contains "olist → begin enumerate" '\begin{enumerate}' "$OUT"
assert_contains "olist → end enumerate"   '\end{enumerate}'   "$OUT"
assert_contains "olist → item"            '\item First'       "$OUT"

OUT=$(convert '= Test
:template: guide

Term A:: Definition A
Term B:: Definition B')
assert_contains "dlist → begin description" '\begin{description}' "$OUT"
assert_contains "dlist → end description"   '\end{description}'   "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 11. Technical template roles
# ════════════════════════════════════════════════════════════════════════════
echo "=== 11. Technical template roles ==="

OUT=$(convert '= Test
:template: technical

[.problem]
The system crashes.

[.workaround]
Restart the service.')
assert_contains "problem role → begin problem" '\begin{problem}' "$OUT"
assert_contains "problem role → end problem"   '\end{problem}'   "$OUT"
assert_contains "workaround role → begin workaround" '\begin{workaround}' "$OUT"
assert_contains "workaround role → end workaround"   '\end{workaround}'   "$OUT"

OUT=$(convert '= Test
:template: technical

[.rootcause]
Root cause identified.

[.triggercondition]
Trigger condition met.')
assert_contains "rootcause role" '\begin{rootcause}' "$OUT"
assert_contains "triggercondition role" '\begin{triggercondition}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 12. POC result badges
# ════════════════════════════════════════════════════════════════════════════
echo "=== 12. POC result badges ==="

OUT=$(convert '= Test
:template: poc

[.result-pass]#Pass#
[.result-fail]#Fail#')
assert_contains "result-pass → pocresult Pass" '\pocresult{Pass}' "$OUT"
assert_contains "result-fail → pocresult Fail" '\pocresult{Fail}' "$OUT"

OUT=$(convert '= Test
:template: poc

[.result-partial]#Partial#
[.result-skip]#Skip#')
assert_contains "result-partial → pocresult Partial" '\pocresult{Partial}' "$OUT"
assert_contains "result-skip → pocresult Skip"     '\pocresult{Skip}'     "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 13. Testbook badges
# ════════════════════════════════════════════════════════════════════════════
echo "=== 13. Testbook badges ==="

OUT=$(convert '= Test
:template: testbook

[.badge-pass]#Pass# and [.badge-fail]#Fail#.')
assert_contains "badge-pass → testresultbadge Pass" '\testresultbadge{Pass}' "$OUT"
assert_contains "badge-fail → testresultbadge Fail" '\testresultbadge{Fail}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 14. Inline roles
# ════════════════════════════════════════════════════════════════════════════
echo "=== 14. Inline roles ==="

OUT=$(convert '= Test
:template: guide

Select [.menu]#File ▸ Open# to continue.')
assert_contains "menu role → menu cmd" '\menu{File, Open}' "$OUT"

OUT=$(convert '= Test
:template: guide

[.note]#Important note#')
assert_contains "note role → note cmd" '\note{Important note}' "$OUT"

OUT=$(convert '= Test
:template: guide

[.param]#my_param#')
assert_contains "param role → param cmd" '\param{my_param}' "$OUT"

OUT=$(convert '= Test
:template: guide

[.badge]#custom#')
assert_contains "badge role → badge cmd" '\badge{custom}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 15. Cross-references
# ════════════════════════════════════════════════════════════════════════════
echo "=== 15. Cross-references ==="

OUT=$(convert '= Test
:template: guide

See <<section1>> for details.

[[section1]]
== Section One

Content.')
assert_contains "xref → hyperlink" '\hyperlink{' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 16. Objectives role
# ════════════════════════════════════════════════════════════════════════════
echo "=== 16. Objectives role ==="

OUT=$(convert '= Test
:template: guide

[.objectives]
--
[.general-objective]#Understand the system#
--')
assert_contains "objectives → begin objectives" '\begin{objectives}' "$OUT"
assert_contains "objectives → end objectives"   '\end{objectives}'   "$OUT"
assert_contains "objectives → content present"   'Understand the system' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════#═════════════════════════════════════════════════════════
echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
