#!/usr/bin/env bash
# test-converter.sh — Unit tests for huawei-latex-converter.rb
# Feeds minimal AsciiDoc snippets through the converter and verifies
# the LaTeX output contains expected strings.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONVERTER="$REPO_ROOT/templates/_base/huawei-latex-converter.rb"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
PASS=0; FAIL=0
CONVERT_ERR="$TMPDIR/convert-err.log"

# ── Helpers ──────────────────────────────────────────────────────────────────

# convert: feed an AsciiDoc snippet through the converter; echo the .tex output.
# On failure, echoes nothing and captures stderr to $CONVERT_ERR (a file, which
# persists across the command-substitution subshell). assert_* detect failure
# via empty output and report the captured stderr.
convert() {
  local adoc="$1"
  local adoc_file="$TMPDIR/test.adoc"
  printf '%s\n' "$adoc" > "$adoc_file"
  if ! asciidoctor -b huawei-latex -r "$CONVERTER" "$adoc_file" -o "$TMPDIR/test.tex" 2>"$CONVERT_ERR"; then
    echo ""
    return 0
  fi
  cat "$TMPDIR/test.tex"
}

# _check_output: fail the test if output is empty (conversion failed).
# Prints the captured stderr to aid diagnosis.
_check_output() {
  local label="$1" actual="$2"
  if [[ -z "$actual" ]]; then
    echo "  FAIL: $label (conversion failed or produced empty output)"
    echo "        stderr: $(head -c 300 "$CONVERT_ERR" 2>/dev/null)"
    FAIL=$((FAIL + 1))
    return 1
  fi
  return 0
}

assert_contains() {
  local label="$1" expected="$2" actual="$3"
  _check_output "$label" "$actual" || return 0
  if printf '%s' "$actual" | grep -qF -- "$expected"; then
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
  _check_output "$label" "$actual" || return 0
  if printf '%s' "$actual" | grep -qF -- "$unexpected"; then
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
  _check_output "$label" "$actual" || return 0
  if printf '%s' "$actual" | grep -qE -- "$pattern"; then
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

[.badge-pass]#Pass#, [.badge-partial]#Partial# and [.badge-fail]#Fail#.')
assert_contains "badge-pass → testresultbadge Pass" '\testresultbadge{Pass}' "$OUT"
assert_contains "badge-partial → testresultbadge Partial" '\testresultbadge{Partial}' "$OUT"
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
assert_contains "param role → param cmd" '\param{my\_param}' "$OUT"

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
## 17. Underscore escaping in prose
# ════════════════════════════════════════════════════════════════════════════
echo "=== 17. Underscore escaping in prose ==="

OUT=$(convert '= Test
:template: guide

[.note]#my_var#')
assert_contains "note role underscore → escaped" '\note{my\_var}' "$OUT"

OUT=$(convert '= Test
:template: guide

[.badge]#a_b#')
assert_contains "badge role underscore → escaped" '\badge{a\_b}' "$OUT"

OUT=$(convert '= Test
:template: guide

* item x_y')
assert_contains "list item underscore → escaped" '\item item x\_y' "$OUT"

OUT=$(convert '= Test
:template: guide

The my_var value.')
assert_contains "paragraph underscore → escaped" 'my\_var' "$OUT"

OUT=$(convert '= Test
:template: guide

[.hutable]
|===
| Col n_1 | Col B
|===')
assert_contains "table cell underscore → escaped" 'Col n\_1' "$OUT"

# No double-escape: a backslash-escaped underscore in source stays \_, not \\_
OUT=$(convert '= Test
:template: guide

Value one\_two here.')
assert_contains "no double-escape → stays \_" 'one\_two' "$OUT"
assert_not_contains "no double-escape → not \\_" 'one\\_two' "$OUT"

# No double-escape: monospaced underscore survives escape_inline_content
OUT=$(convert '= Test
:template: guide

Mono `my_var` in prose.')
assert_contains "mono underscore escaped once" '\inlinecode{my\_var}' "$OUT"
assert_not_contains "mono underscore not double-escaped" '\inlinecode{my\\_var}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 18. Cross-reference mechanism
# ════════════════════════════════════════════════════════════════════════════
echo "=== 18. Cross-reference mechanism ==="

# Inline anchor [[a_b]] → \label{a-b}\hypertarget{a-b}{}
OUT=$(convert '= Test
:template: guide

See [[a_b]] inline.')
assert_contains "inline ref → label+hypertarget sanitized" '\label{a-b}\hypertarget{a-b}{}' "$OUT"

# xref <<a_b,Text>> → \hyperlink{a-b}{Text}
OUT=$(convert '= Test
:template: guide

See <<a_b,Text>> here.')
assert_contains "xref with text → hyperlink sanitized" '\hyperlink{a-b}{Text}' "$OUT"

# Section with explicit id emits \label{...}\hypertarget{...}
OUT=$(convert '= Test
:template: guide

[[my_section]]
== My Section

Content.')
assert_contains "section explicit id → anchor" '\label{my-section}\hypertarget{my-section}{}' "$OUT"
# M1: anchor must appear AFTER the sectioning command (not before), because
# \section is redefined to \clearpage\lg@origsection.
assert_matches "section anchor after \\section" '\\section\{My Section\}\\label\{my-section\}' "$OUT"

# Auto-generated section id also gets an anchor
OUT=$(convert '= Test
:template: guide

== Some Section

Content.')
assert_contains "section auto id → anchor" '\hypertarget{' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 19. Evidence list, kbd, footnote, badges
# ════════════════════════════════════════════════════════════════════════════
echo "=== 19. Evidence list, kbd, footnote, badges ==="

# Evidence list renders plain bullets (v6.5.0: checkbox markers removed)
OUT=$(convert '= Test
:template: guide

[.evidence]
* Item one')
assert_contains "evidence list → plain bullet" '\item Item one' "$OUT"

# kbd macro escapes special chars (requires :experimental:)
OUT=$(convert '= Test
:template: guide
:experimental:

kbd:[a&b]')
assert_contains "kbd → inlinecode escaped" '\inlinecode{a\&b}' "$OUT"

# Footnote escapes $ and & (and does not crash)
OUT=$(convert '= Test
:template: guide

Costs footnote:[Costs $5 & up].')
assert_contains "footnote → escaped" '\footnote{Costs \$5 \& up}' "$OUT"

# POC result role ignores contradictory text
OUT=$(convert '= Test
:template: poc

[.result-pass]#Fail#')
assert_contains "result-pass ignores text" '\pocresult{Pass}' "$OUT"
assert_not_contains "result-pass no leak" '\pocresult{Fail}' "$OUT"

# badge-pass escapes special chars
OUT=$(convert '= Test
:template: testbook

[.badge-pass]#P&ss#')
assert_contains "badge-pass → escaped" '\testresultbadge{P\&ss}' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 20. Coverage for previously-untested converters
# ════════════════════════════════════════════════════════════════════════════
echo "=== 20. Coverage for previously-untested converters ==="

# Passthrough block emits raw content
OUT=$(convert '= Test
:template: guide

++++
\raw{latex}
++++')
assert_contains "pass → raw passthrough" '\raw{latex}' "$OUT"

# Quote with attribution
OUT=$(convert '= Test
:template: guide

[quote, Author Name]
Quoted text.')
assert_contains "quote attribution → --- Author" '--- Author Name' "$OUT"

# Callout list
OUT=$(convert '= Test
:template: guide

----
code <1>
----

<1> First callout
<2> Second callout')
assert_contains "colist → item" '\item First callout' "$OUT"

# Floating title → \section*
OUT=$(convert '= Test
:template: guide

[discrete]
== Discrete Title')
assert_contains "floating_title → section*" '\section*{Discrete Title}' "$OUT"

# Thematic break → \rule
OUT=$(convert '= Test
:template: guide

Before.

---

After.')
assert_contains "thematic_break → rule" '\rule{\linewidth}{0.5pt}' "$OUT"

# Inline break → \\
OUT=$(convert '= Test
:template: guide

Line one +
Line two.')
assert_contains "inline_break → \\\\" 'one\\' "$OUT"

# Inline button → \textbf
OUT=$(convert '= Test
:template: guide
:experimental:

Press btn:[Save] now.')
assert_contains "inline_button → textbf" '\textbf{Save}' "$OUT"

# Example with title → infobox
OUT=$(convert '= Test
:template: guide

.Basic example
====
Content here.
====')
assert_contains "example with title → infobox" '\begin{infobox}' "$OUT"
assert_contains "example title present" 'Basic example' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 21. Zero-width-space stripping & title entity resolution
# ════════════════════════════════════════════════════════════════════════════
echo "=== 21. ZWS strip & title entities ==="

# Asciidoctor expands -- to em dash + U+200B; U+200B must be stripped.
OUT=$(convert '= Test
:template: guide

After 5--30 minutes.')
assert_contains "em dash present" '5—30' "$OUT"
assert_not_contains "no zero-width space" $'\u200b' "$OUT"

# Section title with -- and ... : entities resolved, no raw &#8212; leak
OUT=$(convert '= Test
:template: guide

== Range 5--30...End

Text.')
assert_contains "section title em dash resolved" '\section{Range 5—30…End}' "$OUT"
assert_not_contains "section title no entity leak" '&#8212;' "$OUT"

# Document title with entities resolved
OUT=$(convert '= My--Doc...Title
:template: guide

Text.')
assert_contains "doctitle entities resolved" '\setdoctitle{My—Doc…Title}' "$OUT"

# Floating title with entities resolved
OUT=$(convert '= Test
:template: guide

[discrete]
== Float--Title...X

Text.')
assert_contains "floating title entities resolved" '\section*{Float—Title…X}' "$OUT"

# Image caption with entities resolved
OUT=$(convert '= Test
:template: guide

.Cap--tion...Y
image::arch.png[alt]')
assert_contains "image caption entities resolved" '\imagecap{arch.png}{Cap—tion…Y}' "$OUT"

# Example title with entities resolved
OUT=$(convert '= Test
:template: guide

.Ex--ample...W
====
Body.
====')
assert_contains "example title entities resolved" 'Ex—ample…W' "$OUT"
assert_not_contains "example title no entity leak" '&#8230;' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
## 22. Wave 1 regression coverage
# ════════════════════════════════════════════════════════════════════════════
echo "=== 22. Wave 1 regression coverage ==="

# Objectives inline roles (were silently dropped before the fix)
OUT=$(convert '= Test
:template: guide

[.general-objective]#Master the console#
[.objective]#First objective#')
assert_contains "general-objective inline → generalobjective" '\generalobjective{Master the console}' "$OUT"
assert_contains "objective inline → objective" '\objective{First objective}' "$OUT"

# Objectives block form (crashed with NoMethodError before the fix: the
# converter called block.text, which Asciidoctor::Block does not respond to).
# NOTE: block roles must sit on their own line — with the role prefix on the
# same line as the text, Asciidoctor parses the whole line as plain paragraph
# text (role=nil) and no converter can remap it.
OUT=$(convert '= Test
:template: guide

[.objectives]
--
[.general-objective]
General objective text

[.objective]
First objective text
--')
assert_contains "objectives block → generalobjective" '\generalobjective{General objective text}' "$OUT"
assert_contains "objectives block → objective" '\objective{First objective text}' "$OUT"

# Unknown code language passes through verbatim — the .sty handles fallback
# highlighting for languages minted/listings do not know.
OUT=$(convert '= Test
:template: guide

[source,go]
----
package main
----')
assert_contains "unknown lang go → begin code[go]" '\begin{code}[go]' "$OUT"
assert_contains "unknown lang go → end code"       '\end{code}'         "$OUT"

# Multi-author document (header author line) — was first-author-only before
# the fix (attr('author') holds just the first; attr('authors') holds all,
# comma-separated).
OUT=$(convert '= My Document
John Doe; Jane Smith
:template: guide

Text.')
assert_contains "multi-author → all authors in setdocauthors" '\setdocauthors{John Doe, Jane Smith}' "$OUT"

# Error handling: a malformed construct (block [.badge] role routes to the
# inline-only convert_role_badge, which calls node.text on a Block) must exit
# non-zero with an actionable one-line message — not the ~14 KB raw Ruby
# object inspect dumped before the fix. NoMethodError messages embed the
# node inspect from ~char 35 — inside the old 300-char truncation window —
# so the message must be stripped of the inspect, not just truncated.
ERR_AD="$TMPDIR/err-case.adoc"
printf '%s\n' '= Test
:template: guide

[.badge]
Block badge text' > "$ERR_AD"
set +e
asciidoctor -b huawei-latex -r "$CONVERTER" "$ERR_AD" -o "$TMPDIR/err-case.tex" 2>"$TMPDIR/err-case.log"
ERR_STATUS=$?
set -e
if [[ "$ERR_STATUS" -ne 0 ]]; then
  echo "  PASS: error case → non-zero exit"
  PASS=$((PASS + 1))
else
  echo "  FAIL: error case → non-zero exit"
  echo "        converter exited 0 on a malformed construct"
  FAIL=$((FAIL + 1))
fi
ERR_LOG="$(<"$TMPDIR/err-case.log")"
assert_contains "error case → actionable message" 'failed to convert' "$ERR_LOG"
assert_contains "error case → node type reported" 'paragraph node'    "$ERR_LOG"
assert_not_contains "error case → no raw node inspect" '#<Asciidoctor' "$ERR_LOG"
ERR_BYTES=$(wc -c < "$TMPDIR/err-case.log")
if [[ "$ERR_BYTES" -lt 1000 ]]; then
  echo "  PASS: error case → bounded output ($ERR_BYTES bytes)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: error case → bounded output"
  echo "        stderr was $ERR_BYTES bytes (raw Ruby object inspect dumped?)"
  FAIL=$((FAIL + 1))
fi

# ════════════════════════════════════════════════════════════════════════════
## 23. Prerequisites / stepbystep roles
# ════════════════════════════════════════════════════════════════════════════
echo "=== 23. Prerequisites / stepbystep roles ==="

# [.prerequisites] directly on a ulist inside [.objectives] (the form
# documented in templates/poc/SKILL.md): label + ALL items. Before the fix
# every item was dropped — Asciidoctor aliases List#blocks to the ListItems
# and ListItem#content is "" (text lives in ListItem#text), so the old
# handler emitted only the label.
OUT=$(convert '= Test
:template: poc

[.objectives]
--
[.prerequisites]
* Item one
* Item two
--')
assert_contains "prerequisites on list → label"    '\prerequisites'  "$OUT"
assert_contains "prerequisites on list → itemize"  '\begin{itemize}' "$OUT"
assert_contains "prerequisites on list → item one" '\item Item one'   "$OUT"
assert_contains "prerequisites on list → item two" '\item Item two'   "$OUT"

# [.stepbystep] directly on an olist inside [.objectives]: the old handler
# emitted only the label and never rendered the list at all.
OUT=$(convert '= Test
:template: poc

[.objectives]
--
[.stepbystep]
. Step one
. Step two
--')
assert_contains "stepbystep on list → label"     '\stepbystep'       "$OUT"
assert_contains "stepbystep on list → enumerate" '\begin{enumerate}' "$OUT"
assert_contains "stepbystep on list → step one"  '\item Step one'    "$OUT"
assert_contains "stepbystep on list → step two"  '\item Step two'    "$OUT"

# Standalone role-on-list (outside [.objectives]) emits label + items too
OUT=$(convert '= Test
:template: poc

[.prerequisites]
* Solo item one
* Solo item two')
assert_contains "standalone prerequisites → label"    '\prerequisites'      "$OUT"
assert_contains "standalone prerequisites → item one" '\item Solo item one' "$OUT"
assert_contains "standalone prerequisites → item two" '\item Solo item two' "$OUT"

OUT=$(convert '= Test
:template: poc

[.stepbystep]
. Solo step one
. Solo step two')
assert_contains "standalone stepbystep → label"    '\stepbystep'        "$OUT"
assert_contains "standalone stepbystep → step one" '\item Solo step one' "$OUT"
assert_contains "standalone stepbystep → step two" '\item Solo step two' "$OUT"

# ════════════════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASS passed, $FAIL failed"
# Exit with status, not the failure count: `exit $FAIL` wrapped mod 256 past
# 255 failures (e.g. 256 failures → exit 0 → CI would see success).
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
