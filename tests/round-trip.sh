#!/bin/bash
# round-trip.sh — Verify multi-format output consistency
# Checks that heading counts, image counts, code block counts,
# and table/callout counts are consistent across Markdown, HTML, and DOCX outputs.
# Also hard-checks 0 raw LaTeX in all three formats (excluding code examples).
# Format generation is DELEGATED to scripts/build.sh so the test exercises the
# real production pipeline (preprocessor → asciidoctor -b docbook → pandoc →
# post-processors) instead of a drifting re-implementation.  Exception:
# setup-guide's committed .md/.html/.docx are checked as-is, never regenerated
# here (see the policy note in the main loop).
# Count tolerances are calibrated per sample to the ACTUAL measured divergence
# (see the tolerance table in the main loop) — never wider.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

# Temp directory (cleaned up on exit)
RT_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/rt-roundtrip.XXXXXX")"
trap 'rm -rf "$RT_TMPDIR"' EXIT

# ── Raw LaTeX policy ────────────────────────────────────────────────────────
# Since v6.5.1 the pre-processor (adoc_docx_preprocessor.py) converts all
# passthrough content before these outputs are generated, so ANY raw LaTeX
# outside code blocks is a bug.  The old exclusion list (which masked leaks
# of the pre-v6.4 pipeline) was removed — no patterns are excluded.

# ── Helpers ────────────────────────────────────────────────────────────────

# Safe grep -c: returns "0" even when no matches (grep exits 1).
count() { local n; n=$(grep -c "$1" "$2" 2>/dev/null || true); echo "${n:-0}"; }

# Count occurrences of a pattern in MD outside fenced code blocks (```).
# Needed because the real pipeline produces MD where:
# - code blocks contain lines that look like headings (bash `#` comments)
# - pandoc falls back to raw HTML blocks (<img>, <table>) for content
#   that GFM pipe syntax cannot express (figures, tables with lists)
count_md() {
  local md_file=$1 pattern=$2
  python3 - "$md_file" "$pattern" << 'PYEOF'
import sys, re
md_file, pattern = sys.argv[1], sys.argv[2]
pat = re.compile(pattern)
n = 0
in_fenced = False
with open(md_file) as f:
  for line in f:
    if line.startswith("```"):
      in_fenced = not in_fenced
      continue
    if in_fenced:
      continue
    n += len(pat.findall(line))
print(n)
PYEOF
}

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
# - imgs: content images only — badge pill PNGs (short one-line pills;
#   the exclusion threshold BADGE_MAX_CY=300000 EMU has headroom above
#   the tallest pill at ~210000) for [Pass]-family markers are excluded
#   so the count is comparable with MD/HTML, where badges are text.
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
WP = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
callout_colors = {"C7000B", "ED6D00", "62B230", "30B5C5"}
# Badge pills are short one-line pills (≤0.6cm tall, ~210000 EMU);
# content images are taller.  Pill width varies with label length
# (auto-fit canvas, up to ~3.6cm), so height is the stable discriminator.
BADGE_MAX_CY = 300000

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
    # Images: <w:drawing> in paragraph, excluding short badge pill PNGs
    for drawing in p.findall(f".//{{{W}}}drawing"):
        extent = drawing.find(f".//{{{WP}}}extent")
        if extent is None or int(extent.get("cy", "0")) > BADGE_MAX_CY:
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

# ── Sample list (auto-discovered) ────────────────────────────────────────────
# v6.0.0: all samples use .adoc source.
SAMPLES=()
for tmpl_dir in "$REPO_ROOT"/templates/*/; do
    tmpl_name=$(basename "$tmpl_dir")
    [ "$tmpl_name" = "_base" ] && continue
    [ ! -f "$tmpl_dir/${tmpl_name}.cls" ] && continue

    for doc_dir in "$REPO_ROOT/documents/$tmpl_name"-*/; do
        [ ! -d "$doc_dir" ] && continue
        doc_name=$(basename "$doc_dir")
        if [ -f "$doc_dir/src/main.adoc" ]; then
            SAMPLES+=("documents/$doc_name main adoc")
        fi
    done
done
# Setup guide (special case — uses guide template, different filename)
if [ -f "$REPO_ROOT/documents/setup-guide/src/setup-guide.adoc" ]; then
    SAMPLES+=("documents/setup-guide setup-guide adoc")
fi

# ── Main loop ──────────────────────────────────────────────────────────────
for entry in "${SAMPLES[@]}"; do
  read -r sample basename src_fmt <<< "$entry"
  name=$(basename "$sample")
  echo "=== $name ==="

  # Resolve source file (all samples are .adoc)
  src_file="$REPO_ROOT/$sample/src/${basename}.adoc"
  if [ ! -f "$src_file" ]; then
    echo "  SKIP: source not found: $src_file"
    continue
  fi

  # ── Obtain MD/HTML/DOCX ────────────────────────────────────────────────
  # Policy (two kinds of samples):
  # * The 8 template samples (documents/<tmpl>-{pt,en}/) REGENERATE their
  #   outputs here via scripts/build.sh so the test validates the REAL
  #   pipeline (preprocessor → asciidoctor -b docbook → pandoc →
  #   post-processors) with production arguments (--toc --toc-depth=3
  #   --metadata toc-title, --lang for the DOCX fix step, embed-images.py
  #   for MD) instead of a drifting re-implementation.  build.sh writes
  #   the outputs into the document's own folder (documents/<name>/) —
  #   for these samples they are gitignored build artifacts, safe to
  #   delete and regenerate.
  # * setup-guide is DIFFERENT: its .md/.html/.docx are COMMITTED to git
  #   (see AGENTS.md).  Regenerating them here would rewrite committed
  #   files with a fresh cover timestamp (dirty tree after every test
  #   run), and the pre-build rm would leave them deleted if the build
  #   failed.  So setup-guide is never rm'd or rebuilt — the test checks
  #   its EXISTING committed outputs, which the standard validation gate
  #   (make all-formats / make setup-guide, same build.sh pipeline)
  #   keeps current.
  md_file="$REPO_ROOT/$sample/${basename}.md"
  html_file="$REPO_ROOT/$sample/${basename}.html"
  docx_file="$REPO_ROOT/$sample/${basename}.docx"
  if [ "$name" = "setup-guide" ]; then
    # Committed outputs: use as-is.  If missing, the validation gate has
    # not been run yet — skip this sample's format checks (do not fail,
    # and do not build, which would mutate the working tree).
    if [ ! -f "$md_file" ] || [ ! -f "$html_file" ] || [ ! -f "$docx_file" ]; then
      echo "  SKIP: committed outputs missing (${basename}.md/.html/.docx) — run make all-formats first"
      continue
    fi
  else
    # Remove stale outputs first so a silently failing build cannot pass
    # on artifacts left over from a previous run.
    rm -f "$md_file" "$html_file" "$docx_file"
    build_log="$RT_TMPDIR/${name}-build.log"
    if ! "$REPO_ROOT/scripts/build.sh" --docx --md --html "$REPO_ROOT/$sample" \
          >"$build_log" 2>&1; then
      echo "  FAIL: scripts/build.sh failed for $name"
      tail -20 "$build_log" | sed 's/^/  │ /'
      FAIL=$((FAIL + 1))
      continue
    fi
    if [ ! -f "$md_file" ] || [ ! -f "$html_file" ] || [ ! -f "$docx_file" ]; then
      echo "  FAIL: build.sh succeeded but an output (md/html/docx) is missing for $name"
      FAIL=$((FAIL + 1))
      continue
    fi
  fi

  # ── Count MD ───────────────────────────────────────────────────────────
  # Fenced-code-aware: bash `#` comments inside code blocks must not
  # count as headings; pandoc's raw-HTML fallbacks (<img>, <table>) must
  # count as images/tables.
  md_h1=$(count_md "$md_file" '^# ')
  md_h2=$(count_md "$md_file" '^## ')
  md_img=$(count_md "$md_file" '!\[|<img')
  # Code blocks: count fenced code blocks only (``` open+close, divide by 2).
  # Indented code blocks in Pandoc MD are ambiguous with list-item indentation,
  # so we count only fenced blocks for reliable cross-format comparison.
  md_code_markers=$(count '^```' "$md_file")
  md_code=$((md_code_markers / 2))
  # Tables: count pipe-table separator lines, grid-table separator
  # lines (indented ---), and raw-HTML <table> blocks (pandoc emits HTML
  # tables when a cell holds block content, e.g. changelog bullet lists
  # — GFM pipe tables are inline-only).
  # A pipe separator line must contain at least one "-" — pandoc emits an
  # all-spaces pipe row ("|   |   |") as the empty header of headerless
  # tables (e.g. the cover version table), which is data, not a separator,
  # and must not count as a second table.
  # Grid tables may have 2 separator lines (header + footer), so count
  # only the first separator of each contiguous group.
  md_tables=$(count_md "$md_file" '^\|[-| :]*-[-| :]*$')
  md_grid_tables=$(awk '/^[[:space:]]+---/ {if(!p) c++; p=1} !/^[[:space:]]+---/ {p=0} END{print c+0}' "$md_file")
  md_html_tables=$(count_md "$md_file" '<table')
  md_tables=$((md_tables + md_grid_tables + md_html_tables))
  # Callouts: pandoc renders docbook admonitions as raw HTML divs
  # (class="note|warning|tip|...").  DOCX cannot count them — pandoc
  # drops the admonition label and keeps only the body text.
  md_callouts=$(count_md "$md_file" '<div class="(note|warning|tip|caution|important)"')

  # ── Count HTML ─────────────────────────────────────────────────────────
  html_h1=$(count '<h1' "$html_file")
  html_h2=$(count '<h2' "$html_file")
  html_img=$(count '<img' "$html_file")
  # Code blocks: listing blocks ([source] with or without a language).
  # asciidoctor renders each as <div class="listingblock"> containing
  # either <pre class="highlight"><code ...> (with language) or a bare
  # <pre> (without). Literal blocks (<div class="literalblock">) are
  # excluded: pandoc's docbook reader does not map them to SourceCode
  # paragraphs in DOCX, so counting them would diverge.
  html_code=$(count_occ '<div class="listingblock"' "$html_file")
  # Real tables only: asciidoctor also renders admonitions (NOTE/TIP/
  # WARNING) as bare <table> layout grids — those are counted as callouts
  # below, not as tables.
  html_tables=$(count '<table class="tableblock' "$html_file")
  # Callouts: asciidoctor admonition blocks
  html_callouts=$(count_occ 'class="admonitionblock ' "$html_file")

  # ── Count DOCX ─────────────────────────────────────────────────────────
  docx_tmpdir="$RT_TMPDIR/docx_unzip"
  docx_counts=$(count_docx "$docx_file" "$docx_tmpdir")
  read -r docx_h1 docx_h2 docx_img docx_code_paras docx_code_blocks docx_tables docx_callouts <<< "$docx_counts"

  # ── Cross-format consistency ───────────────────────────────────────────
  # Tolerances are calibrated per sample to the ACTUAL max pairwise diff
  # measured with the production pipeline (scripts/build.sh) — the smallest
  # value that passes, never wider. When a divergence is fixed, or a sample's
  # content changes, re-run this test, read the measured counts from the
  # FAIL line / summary table, and update the case entry below.
  #
  # Root causes of the remaining non-zero divergences:
  #
  # * H1/H2 — asciidoctor's HTML output shifts headings down one level: the
  #   document title is the only <h1> and chapters become <h2>, while the
  #   MD/DOCX pipelines put chapters at H1. So html_h1 is always 1 and
  #   html_h2 equals the chapter count (= md_h1 = docx_h1). The H1
  #   divergence is (chapters − 1); the H2 divergence is
  #   |sections − chapters|. MD and DOCX agree exactly on both levels.
  #
  # * Tables+Callouts — DOCX loses the admonition structure: pandoc's
  #   docbook reader drops the NOTE/TIP/WARNING labels and keeps only the
  #   body text as plain paragraphs, so DOCX contributes tables only while
  #   MD/HTML count tables + callout divs. The divergence equals the
  #   document's callout count (guide 9, poc 5, technical 4, testbook 6,
  #   setup-guide 32).
  #
  # * Code blocks converged to 0: the pre-processor now inlines
  #   [.codefile,file=...] content as a real [source] block for
  #   secondary formats (L18 — the PDF typesets the file via
  #   \codefile), so HTML listing blocks and DOCX SourceCode runs map
  #   1:1 again (measured 6/6 guide-en, 3/3 guide-pt).
  #
  # * Images converged to 0 with the production pipeline: build.sh passes
  #   -r asciidoctor-diagram to every conversion, so MD/DOCX now embed the
  #   same diagram images as HTML. Code blocks also map 1:1 (HTML listing
  #   blocks → DOCX SourceCode runs).
  case "$name" in
    guide-en)     h1_tol=5;  h2_tol=3;  img_tol=0; code_tol=0; tc_tol=9 ;;
    guide-pt)     h1_tol=5;  h2_tol=2;  img_tol=0; code_tol=0; tc_tol=9 ;;
    poc-en)       h1_tol=14; h2_tol=10; img_tol=0; code_tol=0; tc_tol=5 ;;
    poc-pt)       h1_tol=14; h2_tol=10; img_tol=0; code_tol=0; tc_tol=5 ;;
    technical-en) h1_tol=3;  h2_tol=0;  img_tol=0; code_tol=0; tc_tol=4 ;;
    technical-pt) h1_tol=3;  h2_tol=0;  img_tol=0; code_tol=0; tc_tol=4 ;;
    testbook-en)  h1_tol=3;  h2_tol=5;  img_tol=0; code_tol=0; tc_tol=6 ;;
    testbook-pt)  h1_tol=3;  h2_tol=5;  img_tol=0; code_tol=0; tc_tol=6 ;;
    setup-guide)  h1_tol=8;  h2_tol=19; img_tol=0; code_tol=0; tc_tol=32 ;;
    *)
      # Uncalibrated sample (new template/document): measure its actual
      # diffs and add an entry above. img_tol/code_tol stay 0 (converged
      # formats); h1/h2/tc carry the known HTML heading shift and DOCX
      # callout drop, so small documents fit these defaults.
      h1_tol=5; h2_tol=10; img_tol=0; code_tol=0; tc_tol=5 ;;
  esac

  check_tol3 "H1 count (MD/HTML/DOCX)" "$md_h1" "$html_h1" "$docx_h1" "$h1_tol"
  check_tol3 "H2 count (MD/HTML/DOCX)" "$md_h2" "$html_h2" "$docx_h2" "$h2_tol"
  check_tol3 "Image count (MD/HTML/DOCX)" "$md_img" "$html_img" "$docx_img" "$img_tol"

  # Code blocks: HTML listing blocks vs DOCX contiguous SourceCode runs
  # (1:1 with the production pipeline). MD fenced blocks are informational
  # only — pandoc emits indented code blocks inside lists that are hard to
  # distinguish from list-item indentation without a full parser.
  check_tol "Code blocks HTML vs DOCX" "$html_code" "$docx_code_blocks" "$code_tol"

  # Tables + callouts combined comparison:
  #   MD:   md_tables + md_callouts
  #   HTML: html_tables + html_callouts
  #   DOCX: docx_tables (admonitions are dropped — see root cause above)
  md_tc=$((md_tables + md_callouts))
  html_tc=$((html_tables + html_callouts))
  docx_tc=$docx_tables
  check_tol3 "Tables+Callouts (MD/HTML/DOCX)" "$md_tc" "$html_tc" "$docx_tc" "$tc_tol"

  # ── Summary table ──────────────────────────────────────────────────────
  echo ""
  echo "  Metric          | MD  | HTML | DOCX"
  echo "  ----------------|-----|------|-----"
  metrics=("H1" "H2" "Images" "Code blocks" "Tables" "Callouts" "Tables+Callouts")
  md_vals=("$md_h1" "$md_h2" "$md_img" "$md_code" "$md_tables" "$md_callouts" "$md_tc")
  html_vals=("$html_h1" "$html_h2" "$html_img" "$html_code" "$html_tables" "$html_callouts" "$html_tc")
  docx_vals=("$docx_h1" "$docx_h2" "$docx_img" "$docx_code_blocks" "$docx_tables" "$docx_callouts" "$docx_tc")
  for i in "${!metrics[@]}"; do
    printf "  %-16s| %3d | %4d | %4d\n" "${metrics[$i]}" "${md_vals[$i]}" "${html_vals[$i]}" "${docx_vals[$i]}"
  done
  echo ""

  # ── Hard check: 0 raw LaTeX in all 3 formats ──────────────────────────

  # MD: no raw LaTeX outside code blocks
  raw_md=$(count_raw_latex_md "$md_file")
  if [ "$raw_md" -eq 0 ]; then
    echo "  PASS: No raw LaTeX in MD"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Raw LaTeX in MD ($raw_md occurrence(s) outside code blocks)"
    FAIL=$((FAIL + 1))
  fi

  # HTML: no \begin{ outside <pre><code> blocks, no class="latex"
  raw_html=$(python3 - "$html_file" << 'PYEOF'
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
    echo "  FAIL: Raw LaTeX in DOCX ($raw_docx occurrence(s) outside code blocks)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
