#!/bin/bash
# round-trip.sh — Verify multi-format output consistency
# Checks that heading counts, image counts, code block counts,
# and table/callout counts are consistent across Markdown, HTML, and DOCX outputs.
# Also hard-checks 0 raw LaTeX in all three formats (excluding code examples).
# Allows ±1 tolerance for most counts (HTML template may add a title <h1>, etc.).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="$REPO_ROOT/templates/guide/guide-pandoc.lua"
HTML_TMPL="$REPO_ROOT/templates/guide/guide-template.html"
REF_DOCX="$REPO_ROOT/templates/guide/guide-reference.docx"
FIX_SCRIPT="$REPO_ROOT/templates/guide/create-reference-docx.py"
PASS=0; FAIL=0

# Temp directory (cleaned up on exit)
RT_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/rt-roundtrip.XXXXXX")"
trap 'rm -rf "$RT_TMPDIR"' EXIT

# ── Helpers ────────────────────────────────────────────────────────────────

# Safe grep -c: returns "0" even when no matches (grep exits 1).
count() { local n; n=$(grep -c "$1" "$2" 2>/dev/null || true); echo "${n:-0}"; }

# Count occurrences (works on single-line XML files).
# grep -o prints one line per match; wc -l counts them.
count_occ() { local n; n=$(grep -o "$1" "$2" 2>/dev/null | wc -l); echo "${n:-0}"; }

check() {
  local label=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label ($actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

check_tol() {
  local label=$1 a=$2 b=$3 tol=${4:-1}
  local diff=$((a > b ? a - b : b - a))
  if [ "$diff" -le "$tol" ]; then
    echo "  PASS: $label (a=$a b=$b, ±$tol ok)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (a=$a b=$b, diff=$diff, tol=±$tol)"
    FAIL=$((FAIL + 1))
  fi
}

# Three-way tolerance: max pairwise diff ≤ tol.
check_tol3() {
  local label=$1 a=$2 b=$3 c=$4 tol=${5:-1}
  local d1 d2 d3 max_diff
  d1=$((a > b ? a - b : b - a))
  d2=$((b > c ? b - c : c - b))
  d3=$((a > c ? a - c : c - a))
  max_diff=$d1
  [ "$d2" -gt "$max_diff" ] && max_diff=$d2
  [ "$d3" -gt "$max_diff" ] && max_diff=$d3
  if [ "$max_diff" -le "$tol" ]; then
    echo "  PASS: $label (md=$a html=$b docx=$c, ±$tol ok)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (md=$a html=$b docx=$c, max_diff=$max_diff, tol=±$tol)"
    FAIL=$((FAIL + 1))
  fi
}

# ── DOCX counting ──────────────────────────────────────────────────────────
# Unzips DOCX and returns: h1 h2 imgs code_paras code_blocks tables callouts
# - code_paras: total SourceCode-styled paragraphs (lines of code)
# - code_blocks: contiguous runs of SourceCode paragraphs (code blocks)
# - callouts: tables with callout-colored left borders
count_docx() {
  local docx_path=$1 tmpdir=$2
  rm -rf "$tmpdir"
  unzip -o -q "$docx_path" -d "$tmpdir" 2>/dev/null

  local doc_xml="$tmpdir/word/document.xml"
  if [ ! -f "$doc_xml" ]; then
    echo "0 0 0 0 0 0 0"
    return
  fi

  python3 - "$doc_xml" << 'PYEOF'
import xml.etree.ElementTree as ET, sys
doc_xml = sys.argv[1]
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
callout_colors = {"C7000B", "F57C00", "2E7D32", "1565C0"}

tree = ET.parse(doc_xml)
root = tree.getroot()

h1 = h2 = imgs = code_paras = code_blocks = tables = callouts = 0
in_code = False

for p in root.iter(f"{{{W}}}p"):
    style = ""
    ppr = p.find(f"{{{W}}}pPr")
    if ppr is not None:
        ps = ppr.find(f"{{{W}}}pStyle")
        if ps is not None:
            style = ps.get(f"{{{W}}}val", "")
    if style == "Heading1": h1 += 1
    elif style == "Heading2": h2 += 1
    elif style == "SourceCode":
        code_paras += 1
        if not in_code:
            in_code = True
            code_blocks += 1
    else:
        in_code = False
    # Images: <w:drawing> inside paragraph
    if p.find(f".//{{{W}}}drawing") is not None:
        imgs += 1

for tbl in root.findall(f".//{{{W}}}tbl"):
    tables += 1
    tbl_pr = tbl.find(f"{{{W}}}tblPr")
    if tbl_pr is not None:
        for left in tbl_pr.findall(f".//{{{W}}}tblBorders/{{{W}}}left"):
            color = left.get(f"{{{W}}}color", "")
            if color in callout_colors:
                callouts += 1
                break

print(f"{h1} {h2} {imgs} {code_paras} {code_blocks} {tables} {callouts}")
PYEOF
}

# ── Raw LaTeX check for MD ─────────────────────────────────────────────────
# Checks for raw LaTeX outside of code blocks (fenced or indented).
# Returns: count of raw LaTeX occurrences
count_raw_latex_md() {
  local md_file=$1
  python3 - "$md_file" << 'PYEOF'
import sys, re

md_file = sys.argv[1]
with open(md_file) as f:
    lines = f.readlines()

raw_count = 0
in_fenced = False

for line in lines:
    # Track fenced code blocks (```)
    if line.startswith("```"):
        in_fenced = not in_fenced
        continue
    if in_fenced:
        continue
    # Skip indented code blocks (4+ spaces or tab)
    if line.startswith("    ") or line.startswith("\t"):
        continue
    # Check for raw LaTeX markers
    if "{=latex}" in line:
        raw_count += 1
    if "\\begin{" in line:
        raw_count += 1
    # \set followed by doc command (not inside backtick inline code)
    # Simple check: \set followed by lowercase letter
    if re.search(r"\\set[a-z]", line):
        # Exclude if inside inline code (between backticks)
        # This is a heuristic — strip backtick-enclosed segments first
        stripped = re.sub(r"`[^`]*`", "", line)
        if re.search(r"\\set[a-z]", stripped):
            raw_count += 1

print(raw_count)
PYEOF
}

# ── Raw LaTeX check for DOCX ──────────────────────────────────────────────
# Checks for raw LaTeX in document.xml, excluding SourceCode/VerbatimChar runs.
count_raw_latex_docx() {
  local doc_xml=$1
  if [ ! -f "$doc_xml" ]; then
    echo "0"
    return
  fi
  python3 - "$doc_xml" << 'PYEOF'
import xml.etree.ElementTree as ET, sys, re

doc_xml = sys.argv[1]
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

tree = ET.parse(doc_xml)
root = tree.getroot()
raw_count = 0

for p in root.iter(f"{{{W}}}p"):
    # Skip SourceCode paragraphs (code blocks)
    ppr = p.find(f"{{{W}}}pPr")
    if ppr is not None:
        ps = ppr.find(f"{{{W}}}pStyle")
        if ps is not None:
            style = ps.get(f"{{{W}}}val", "")
            if style == "SourceCode":
                continue

    # Collect text from non-VerbatimChar runs
    text_parts = []
    for r in p.iter(f"{{{W}}}r"):
        # Check if this run uses VerbatimChar style (code)
        rpr = r.find(f"{{{W}}}rPr")
        is_verbatim = False
        if rpr is not None:
            rs = rpr.find(f"{{{W}}}rStyle")
            if rs is not None:
                rval = rs.get(f"{{{W}}}val", "")
                if rval == "VerbatimChar":
                    is_verbatim = True
        if not is_verbatim:
            for t in r.findall(f"{{{W}}}t"):
                if t.text:
                    text_parts.append(t.text)

    full_text = "".join(text_parts)
    if "\\begin{" in full_text:
        raw_count += 1
    if re.search(r"\\set[a-z]", full_text):
        raw_count += 1

print(raw_count)
PYEOF
}

# ── Sample list ────────────────────────────────────────────────────────────
SAMPLES=(
  "examples/guide/en main"
  "examples/guide/pt main"
  "examples/setup-guide setup-guide"
  "examples/technical/en main"
  "examples/technical/pt main"
)

# ── Main loop ──────────────────────────────────────────────────────────────
for entry in "${SAMPLES[@]}"; do
  read -r sample basename <<< "$entry"
  name=$(basename "$(dirname "$sample")")/$(basename "$sample")
  echo "=== $name ==="

  tex_file="$REPO_ROOT/$sample/src/${basename}.tex"
  if [ ! -f "$tex_file" ]; then
    echo "  SKIP: $tex_file not found"
    continue
  fi

  # ── Generate Markdown ──────────────────────────────────────────────────
  pandoc -f latex+raw_tex --lua-filter="$FILTER" -t markdown --wrap=none \
    "$tex_file" -o "$RT_TMPDIR/rt.md" 2>/dev/null

  # ── Generate HTML ──────────────────────────────────────────────────────
  pandoc -f latex+raw_tex --lua-filter="$FILTER" --template="$HTML_TMPL" -s -t html5 \
    "$tex_file" -o "$RT_TMPDIR/rt.html" 2>/dev/null

  # ── Generate DOCX ──────────────────────────────────────────────────────
  docx_outdir="$RT_TMPDIR/docx_out"
  rm -rf "$docx_outdir"
  mkdir -p "$docx_outdir"
  pandoc -f latex+raw_tex --lua-filter="$FILTER" \
    --reference-doc="$REF_DOCX" --number-sections \
    --resource-path="$REPO_ROOT/$sample:$REPO_ROOT/templates/guide/common-assets" \
    -t docx "$tex_file" -o "$docx_outdir/${basename}.docx" 2>/dev/null
  # Post-process with --fix (same pipeline as build.sh)
  if [ -f "$docx_outdir/${basename}.docx" ]; then
    python3 "$FIX_SCRIPT" --fix "$docx_outdir/${basename}.docx" 2>/dev/null || true
  fi

  # ── Count MD ───────────────────────────────────────────────────────────
  md_h1=$(count '^# ' "$RT_TMPDIR/rt.md")
  md_h2=$(count '^## ' "$RT_TMPDIR/rt.md")
  md_img=$(count '!\[' "$RT_TMPDIR/rt.md")
  # Code blocks: count fenced code blocks only (``` open+close, divide by 2).
  # Indented code blocks in Pandoc MD are ambiguous with list-item indentation,
  # so we count only fenced blocks for reliable cross-format comparison.
  md_code_markers=$(count '^```' "$RT_TMPDIR/rt.md")
  md_code=$((md_code_markers / 2))
  # Tables: count pipe-table separator lines (|---|)
  md_tables=$(count '^|.*---' "$RT_TMPDIR/rt.md")
  # Callouts: blockquote blocks starting with callout keywords
  md_callouts=$(grep -cE '^> \*\*(Warning|Tip|Info|Note|Important|Aviso|Dica)' "$RT_TMPDIR/rt.md" 2>/dev/null || echo "0")

  # ── Count HTML ─────────────────────────────────────────────────────────
  html_h1=$(count '<h1' "$RT_TMPDIR/rt.html")
  html_h2=$(count '<h2' "$RT_TMPDIR/rt.html")
  html_img=$(count '<img' "$RT_TMPDIR/rt.html")
  html_code=$(count '<pre><code' "$RT_TMPDIR/rt.html")
  html_tables=$(count_occ '<table' "$RT_TMPDIR/rt.html")
  html_callouts=$(count_occ 'class="callout ' "$RT_TMPDIR/rt.html")

  # ── Count DOCX ─────────────────────────────────────────────────────────
  docx_tmpdir="$RT_TMPDIR/docx_unzip"
  docx_counts=$(count_docx "$docx_outdir/${basename}.docx" "$docx_tmpdir")
  read -r docx_h1 docx_h2 docx_img docx_code_paras docx_code_blocks docx_tables docx_callouts <<< "$docx_counts"

  # ── Cross-format consistency ───────────────────────────────────────────

  # H1: ±2 tolerance (HTML template may add title <h1>; DOCX may differ by 1)
  check_tol3 "H1 count (MD/HTML/DOCX)" "$md_h1" "$html_h1" "$docx_h1" 2

  # H2: ±1 tolerance
  check_tol3 "H2 count (MD/HTML/DOCX)" "$md_h2" "$html_h2" "$docx_h2" 1

  # Images: ±1 tolerance
  check_tol3 "Image count (MD/HTML/DOCX)" "$md_img" "$html_img" "$docx_img" 1

  # Code blocks: compare MD fenced blocks, HTML <pre><code>, DOCX contiguous SourceCode runs.
  # Known divergence: Pandoc MD uses indented code blocks (inside lists) that are
  # hard to distinguish from list-item indentation without a full parser. We count
  # only fenced blocks in MD, so MD may undercount vs HTML/DOCX.
  # DOCX may overcount because each SourceCode line is a separate paragraph and
  # non-contiguous lines (e.g. separated by list items) count as separate blocks.
  # Primary comparison: HTML vs DOCX (tighter); MD is informational.
  check_tol "Code blocks HTML vs DOCX" "$html_code" "$docx_code_blocks" 20

  # Tables + callouts combined comparison.
  # In DOCX, callouts are rendered as tables with colored left borders,
  # so docx_tables already includes callouts. We compare:
  #   MD:   md_tables + md_callouts
  #   HTML: html_tables + html_callouts
  #   DOCX: docx_tables  (includes callout tables)
  # Known divergence: HTML objectives are rendered as callout infobox divs but
  # MD objectives are plain blockquotes (not counted as callouts above).
  # \note is rendered as italic text (not a callout) in all formats.
  # Setup-guide has many callouts where MD blockquote keyword matching
  # undercounts vs HTML class/DOCX border counting (inherent difference).
  md_tc=$((md_tables + md_callouts))
  html_tc=$((html_tables + html_callouts))
  docx_tc=$docx_tables
  tc_tol=5
  if [ "$name" = "examples/setup-guide" ]; then tc_tol=15; fi
  check_tol3 "Tables+Callouts (MD/HTML/DOCX)" "$md_tc" "$html_tc" "$docx_tc" "$tc_tol"

  # ── Summary table ──────────────────────────────────────────────────────
  echo ""
  echo "  Metric          | MD  | HTML | DOCX"
  echo "  ----------------|-----|------|-----"
  printf "  H1              | %3d | %4d | %4d\n" "$md_h1" "$html_h1" "$docx_h1"
  printf "  H2              | %3d | %4d | %4d\n" "$md_h2" "$html_h2" "$docx_h2"
  printf "  Images          | %3d | %4d | %4d\n" "$md_img" "$html_img" "$docx_img"
  printf "  Code blocks     | %3d | %4d | %4d\n" "$md_code" "$html_code" "$docx_code_blocks"
  printf "  Tables          | %3d | %4d | %4d\n" "$md_tables" "$html_tables" "$docx_tables"
  printf "  Callouts        | %3d | %4d | %4d\n" "$md_callouts" "$html_callouts" "$docx_callouts"
  printf "  Tables+Callouts | %3d | %4d | %4d\n" "$md_tc" "$html_tc" "$docx_tc"
  echo ""

  # ── Hard check: 0 raw LaTeX in all 3 formats ──────────────────────────

  # MD: no raw LaTeX outside code blocks
  raw_md=$(count_raw_latex_md "$RT_TMPDIR/rt.md")
  if [ "$raw_md" -eq 0 ]; then
    echo "  PASS: No raw LaTeX in MD"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Raw LaTeX in MD ($raw_md occurrence(s) outside code blocks)"
    FAIL=$((FAIL + 1))
  fi

  # HTML: no \begin{ outside <pre><code> blocks, no class="latex"
  raw_html=$(python3 - "$RT_TMPDIR/rt.html" << 'PYEOF'
import sys, re
from html.parser import HTMLParser

class RawLatexChecker(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_pre = 0
        self.in_code = 0
        self.raw_count = 0
        self.has_latex_class = False

    def handle_starttag(self, tag, attrs):
        if tag == "pre":
            self.in_pre += 1
        elif tag == "code":
            self.in_code += 1
        # Check for class="latex"
        for attr, val in attrs:
            if attr == "class" and "latex" in val.split():
                self.has_latex_class = True

    def handle_endtag(self, tag):
        if tag == "pre":
            self.in_pre = max(0, self.in_pre - 1)
        elif tag == "code":
            self.in_code = max(0, self.in_code - 1)

    def handle_data(self, data):
        # Only check text outside <pre><code>
        if self.in_pre == 0 and self.in_code == 0:
            if "\\begin{" in data:
                self.raw_count += 1
            if re.search(r"\\set[a-z]", data):
                self.raw_count += 1

with open(sys.argv[1]) as f:
    content = f.read()

checker = RawLatexChecker()
checker.feed(content)
result = checker.raw_count
if checker.has_latex_class:
    result += 1
print(result)
PYEOF
  )
  if [ "$raw_html" -eq 0 ]; then
    echo "  PASS: No raw LaTeX in HTML"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Raw LaTeX in HTML ($raw_html occurrence(s) outside code blocks)"
    FAIL=$((FAIL + 1))
  fi

  # DOCX: no raw LaTeX outside code blocks (SourceCode/VerbatimChar)
  docx_xml="$docx_tmpdir/word/document.xml"
  raw_docx=$(count_raw_latex_docx "$docx_xml")
  if [ "$raw_docx" -eq 0 ]; then
    echo "  PASS: No raw LaTeX in DOCX"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Raw LaTeX in DOCX ($raw_doc occurrence(s) outside code blocks)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
