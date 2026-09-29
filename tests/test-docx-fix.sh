#!/usr/bin/env bash
# test-docx-fix.sh — Smoke test for DOCX post-processing for all templates
# Verifies that the --fix pipeline produces correct heading styles,
# list indentation, and footer page numbers in the generated DOCX.
# Also verifies pandoc tested-range check and loud-failure assertions.
# Tests all templates (guide, technical, testbook, poc).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Temp directory (cleaned up on exit)
TMPDIR_FIX="$(mktemp -d "${TMPDIR:-/tmp}/rt-docx-fix.XXXXXX")"
trap 'rm -rf "$TMPDIR_FIX"' EXIT

PASS=0; FAIL=0

fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }

# ── Pandoc version check ──────────────────────────────────────────────────
# Tested range is >=3.1.0, <3.6.0 (matches SUPPORTED_PANDOC_RANGE in
# docx-fix.py).  An out-of-range pandoc now only warns — builds must
# keep working on future releases; the loud style assertions catch
# actual structure changes.  Only a parse failure stays a hard exit.
echo "=== Pandoc version check ==="
PANDOC_VERSION_LINE="$(pandoc --version | head -1)"
PANDOC_VERSION="$(echo "$PANDOC_VERSION_LINE" | sed -n 's/^pandoc \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')"
if [ -z "$PANDOC_VERSION" ]; then
  echo "  FAIL: Could not parse pandoc version from: $PANDOC_VERSION_LINE"
  exit 1
fi
PANDOC_MAJOR="$(echo "$PANDOC_VERSION" | cut -d. -f1)"
PANDOC_MINOR="$(echo "$PANDOC_VERSION" | cut -d. -f2)"
PANDOC_PATCH="$(echo "$PANDOC_VERSION" | cut -d. -f3)"
# Compare: >=3.1.0 and <3.6.0
PANDOC_NUM=$((PANDOC_MAJOR * 10000 + PANDOC_MINOR * 100 + PANDOC_PATCH))
MIN_NUM=$((3 * 10000 + 1 * 100 + 0))   # 30100 = 3.1.0
MAX_NUM=$((3 * 10000 + 6 * 100 + 0))   # 30600 = 3.6.0
if [ "$PANDOC_NUM" -lt "$MIN_NUM" ] || [ "$PANDOC_NUM" -ge "$MAX_NUM" ]; then
  echo "  WARN: pandoc $PANDOC_VERSION is outside the tested range (3.1.0–3.6.0) — DOCX structure may differ; proceeding"
else
  echo "  pandoc version: $PANDOC_VERSION (in tested range 3.1.0–3.6.0)"
fi

# ── Helper: remove a style from a DOCX file's styles.xml ──────────────────
# Usage: break_style_in_docx <docx_path> <style_id>
# Removes the style with the given styleId from word/styles.xml inside the DOCX.
break_style_in_docx() {
  local docx_path="$1"
  local style_id="$2"
  python3 - "$docx_path" "$style_id" <<'PYEOF'
import sys, zipfile, shutil
from lxml import etree

docx_path = sys.argv[1]
style_id = sys.argv[2]
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

with zipfile.ZipFile(docx_path, 'r') as z:
    styles_xml = z.read('word/styles.xml')
root = etree.fromstring(styles_xml)
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == style_id:
        root.remove(s)
        break
modified_xml = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone=True)
tmp_path = docx_path + '.tmp'
with zipfile.ZipFile(docx_path, 'r') as zin:
    with zipfile.ZipFile(tmp_path, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename == 'word/styles.xml':
                zout.writestr(item, modified_xml)
            else:
                zout.writestr(item, zin.read(item.filename))
shutil.move(tmp_path, docx_path)
PYEOF
}

# ── Template test function ────────────────────────────────────────────────
# run_template_tests <template_name> <fix_script> <filter> <ref_docx> <sample_dir> <common_assets>
run_template_tests() {
  local TEMPLATE_NAME="$1"
  local FIX_SCRIPT="$2"
  local FILTER="$3"
  local REF_DOCX="$4"
  local SAMPLE_DIR="$5"
  local COMMON_ASSETS="$6"

  local ADOC_FILE="$SAMPLE_DIR/src/main.adoc"
  local TEX_FILE="$SAMPLE_DIR/src/main.tex"
  local DOCX_OUT="$TMPDIR_FIX/${TEMPLATE_NAME}-main.docx"

  # For .adoc sources, generate .tex via custom backend if not already present
  if [[ -f "$ADOC_FILE" && ! -f "$TEX_FILE" ]]; then
    asciidoctor -b huawei-latex -r "$REPO_ROOT/templates/_base/huawei-latex-converter.rb" "$ADOC_FILE" -o "$TEX_FILE"
  fi

  echo ""
  echo "=== DOCX --fix smoke test: $TEMPLATE_NAME ==="

  # ── Generate DOCX from en sample ───────────────────────────────────────
  echo "Generating DOCX..."
  if [[ -f "$ADOC_FILE" ]]; then
    # Pre-process .adoc (same pipeline as scripts/build.sh)
    local pre_adoc="$TMPDIR_FIX/${TEMPLATE_NAME}-pre.adoc"
    if ! python3 "$REPO_ROOT/templates/_base/adoc_docx_preprocessor.py" \
          --template "$TEMPLATE_NAME" "$ADOC_FILE" -o "$pre_adoc" 2>/dev/null; then
      fail "$TEMPLATE_NAME: pre-processor failed"
      return
    fi
    # Pipeline: asciidoctor -b docbook → pandoc -f docbook (same as build.sh)
    # Fallback: pandoc -f latex+raw_tex from generated .tex
    local tmp_dbk
    tmp_dbk=$(mktemp --suffix=.dbk)
    if asciidoctor -b docbook "$pre_adoc" -o "$tmp_dbk" 2>/dev/null && \
       pandoc -f docbook \
       --reference-doc="$REF_DOCX" --number-sections \
       --resource-path="$SAMPLE_DIR:$REPO_ROOT/templates/${TEMPLATE_NAME}:$COMMON_ASSETS" \
       "$tmp_dbk" -o "$DOCX_OUT" 2>/dev/null; then
      : # success
    else
      pandoc -f latex+raw_tex "$TEX_FILE" \
        --reference-doc="$REF_DOCX" --number-sections \
        -o "$DOCX_OUT" 2>/dev/null || true
    fi
    rm -f "$tmp_dbk"
  else
    pandoc -f latex+raw_tex --lua-filter="$FILTER" \
      --reference-doc="$REF_DOCX" --number-sections \
      --resource-path="$SAMPLE_DIR:$REPO_ROOT/templates/${TEMPLATE_NAME}:$COMMON_ASSETS" \
      -t docx "$TEX_FILE" -o "$DOCX_OUT" 2>/dev/null
  fi

  echo "Running --fix..."
  # Keep a pre-fix copy for the styling-failure assertion (testbook only,
  # but cheap to make for all templates)
  cp "$DOCX_OUT" "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx"
  python3 "$FIX_SCRIPT" --fix "$DOCX_OUT" 2>/dev/null

  # ── Unzip for inspection ───────────────────────────────────────────────
  local UNZIP_DIR="$TMPDIR_FIX/${TEMPLATE_NAME}-unzipped"
  unzip -o -q "$DOCX_OUT" -d "$UNZIP_DIR"

  local STYLES_XML="$UNZIP_DIR/word/styles.xml"
  local NUMBERING_XML="$UNZIP_DIR/word/numbering.xml"

  # ── Inspect styles.xml ─────────────────────────────────────────────────

  # 1. Heading1 style exists
  if grep -q 'w:styleId="Heading1"' "$STYLES_XML"; then
    pass "$TEMPLATE_NAME: Heading1 style exists"
  else
    fail "$TEMPLATE_NAME: Heading1 style not found"
  fi

  # 2. Heading1 has a non-default color (not theme-based auto)
  if python3 - "$STYLES_XML" << 'PYEOF' 2>/dev/null; then
import xml.etree.ElementTree as ET, sys
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "Heading1":
        rPr = s.find(f"{{{W}}}rPr")
        if rPr is not None:
            color = rPr.find(f"{{{W}}}color")
            if color is not None:
                val = color.get(f"{{{W}}}val", "")
                if val and val != "auto":
                    sys.exit(0)
        break
sys.exit(1)
PYEOF
    pass "$TEMPLATE_NAME: Heading1 has explicit color"
  else
    fail "$TEMPLATE_NAME: Heading1 color is missing or auto"
  fi

  # 3. Heading1 has a bottom border with red color C7000B
  if python3 - "$STYLES_XML" << 'PYEOF' 2>/dev/null; then
import xml.etree.ElementTree as ET, sys
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "Heading1":
        pPr = s.find(f"{{{W}}}pPr")
        if pPr is not None:
            pBdr = pPr.find(f"{{{W}}}pBdr")
            if pBdr is not None:
                bottom = pBdr.find(f"{{{W}}}bottom")
                if bottom is not None:
                    color = bottom.get(f"{{{W}}}color", "")
                    if color == "C7000B":
                        sys.exit(0)
        break
sys.exit(1)
PYEOF
    pass "$TEMPLATE_NAME: Heading1 bottom border is C7000B"
  else
    fail "$TEMPLATE_NAME: Heading1 bottom border is not C7000B"
  fi

  # 4. No duplicate styleId values
  dup_count=$(grep -o 'w:styleId="[^"]*"' "$STYLES_XML" | sort | uniq -d | wc -l)
  if [ "$dup_count" -eq 0 ]; then
    pass "$TEMPLATE_NAME: No duplicate styleId values"
  else
    fail "$TEMPLATE_NAME: Duplicate styleId values found ($dup_count)"
  fi

  # ── Inspect numbering.xml ──────────────────────────────────────────────

  if [ -f "$NUMBERING_XML" ]; then
    # 5. List level 0 has indentation attributes
    if python3 - "$NUMBERING_XML" << 'PYEOF' 2>/dev/null; then
import xml.etree.ElementTree as ET, sys
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for lvl in root.iter(f"{{{W}}}lvl"):
    if lvl.get(f"{{{W}}}ilvl") == "0":
        ind = lvl.find(f"{{{W}}}pPr/{{{W}}}ind")
        if ind is not None:
            left = ind.get(f"{{{W}}}left")
            hanging = ind.get(f"{{{W}}}hanging")
            if left and hanging:
                sys.exit(0)
sys.exit(1)
PYEOF
      pass "$TEMPLATE_NAME: Level 0 list has indentation (w:left + w:hanging)"
    else
      fail "$TEMPLATE_NAME: Level 0 list missing indentation attributes"
    fi
  else
    echo "  SKIP: $TEMPLATE_NAME: numbering.xml not found"
  fi

  # ── Inspect footer XML ─────────────────────────────────────────────────

  # 6. At least one footer exists
  footer_files=("$UNZIP_DIR"/word/footer*.xml)
  if [ ${#footer_files[@]} -gt 0 ] && [ -f "${footer_files[0]}" ]; then
    pass "$TEMPLATE_NAME: Footer XML exists"

    # 7. Footer contains a PAGE field
    found_page=0
    for f in "${footer_files[@]}"; do
      if grep -q 'PAGE' "$f"; then
        found_page=1
        break
      fi
    done
    if [ "$found_page" -eq 1 ]; then
      pass "$TEMPLATE_NAME: Footer contains PAGE field"
    else
      fail "$TEMPLATE_NAME: Footer missing PAGE field"
    fi
  else
    fail "$TEMPLATE_NAME: No footer XML found"
  fi

  # No TESTCASE markers leaked into the DOCX (docx_fix must remove them)
  if grep -q 'TESTCASE-START\|TESTCASE-END' "$UNZIP_DIR/word/document.xml"; then
    fail "$TEMPLATE_NAME: TESTCASE markers leaked into DOCX"
  else
    pass "$TEMPLATE_NAME: No TESTCASE markers in DOCX"
  fi

  # No BADGE sentinels leaked (docx_fix must resolve them to styled text)
  if grep -q '\[BADGE:' "$UNZIP_DIR/word/document.xml"; then
    fail "$TEMPLATE_NAME: BADGE sentinel leaked into DOCX"
  else
    pass "$TEMPLATE_NAME: No BADGE sentinels in DOCX"
  fi

  # ── Loud-failure assertions ────────────────────────────────────────────
  echo ""
  echo "=== Loud-failure assertion tests: $TEMPLATE_NAME ==="

  # 8. Missing Heading1 style → RuntimeError
  BROKEN_DOCX="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_heading1.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX"
  break_style_in_docx "$BROKEN_DOCX" "Heading1"

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing Heading1 style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing Heading1 style causes --fix to fail with non-zero exit"
  fi

  # 9. Missing Title style → RuntimeError
  BROKEN_DOCX2="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_title.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX2"
  break_style_in_docx "$BROKEN_DOCX2" "Title"

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX2" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing Title style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing Title style causes --fix to fail with non-zero exit"
  fi

  # 10. Missing Normal style → RuntimeError
  BROKEN_DOCX3="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_normal.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX3"
  break_style_in_docx "$BROKEN_DOCX3" "Normal"

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX3" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing Normal style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing Normal style causes --fix to fail with non-zero exit"
  fi

  # 11. Missing VerbatimChar style → RuntimeError
  BROKEN_DOCX4="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_verbatim.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX4"
  break_style_in_docx "$BROKEN_DOCX4" "VerbatimChar"

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX4" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing VerbatimChar style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing VerbatimChar style causes --fix to fail with non-zero exit"
  fi

  # 12. Content-styling failure: loud exit + TESTCASE markers stripped.
  # testbook is the only template that emits TESTCASE markers; the
  # pre-processor's --target docx path adds them and docx_fix must
  # remove them even when _apply_content_styling raises.
  if [ "$TEMPLATE_NAME" = "testbook" ]; then
    result=$(python3 - "$REPO_ROOT" \
        "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" << 'PYEOF' 2>/dev/null || true
import importlib.util
import shutil
import sys
import unittest.mock
import zipfile

repo_root, prefix_path = sys.argv[1], sys.argv[2]

spec = importlib.util.spec_from_file_location(
    "docx_fix", repo_root + "/templates/_base/docx_fix.py")
docx_fix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docx_fix)

scratch = prefix_path + ".styling-fail"
shutil.copy(prefix_path, scratch)

# Patch the content-styling entry to raise — mirrors a real styling bug.
raised = False
try:
    with unittest.mock.patch.object(
            docx_fix, '_apply_content_styling',
            side_effect=RuntimeError("boom")):
        docx_fix.main(['--fix', scratch], 'testbook-reference.docx')
except RuntimeError:
    raised = True

# Markers must be gone even though styling raised.
marker_count = 0
with zipfile.ZipFile(scratch) as z:
    xml = z.read('word/document.xml').decode('utf-8')
    marker_count = xml.count('TESTCASE-START') + xml.count('TESTCASE-END')

print(f"LOUD={1 if raised else 0}")
print(f"STRIP={1 if marker_count == 0 else 0}")
PYEOF
    )
    loud=$(echo "$result" | sed -n 's/^LOUD=\([01]\)$/\1/p')
    strip=$(echo "$result" | sed -n 's/^STRIP=\([01]\)$/\1/p')
    if [ "$loud" = "1" ]; then
      pass "$TEMPLATE_NAME: styling failure exits loudly"
    else
      fail "$TEMPLATE_NAME: styling failure did not raise"
    fi
    if [ "$strip" = "1" ]; then
      pass "$TEMPLATE_NAME: markers stripped on styling failure"
    else
      fail "$TEMPLATE_NAME: markers leaked on styling failure"
    fi
  fi

  # 13. Styles-phase failure (unmocked): break Heading1 in a pre-fix
  # copy — the styles-phase assertion raises BEFORE the zip rewrite, so
  # the file on disk is pristine pandoc output; the widened finally must
  # still strip the markers (and the fix must exit non-zero).
  if [ "$TEMPLATE_NAME" = "testbook" ]; then
    STYLES_FAIL_DOCX="$TMPDIR_FIX/${TEMPLATE_NAME}-stylesfail.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$STYLES_FAIL_DOCX"
    break_style_in_docx "$STYLES_FAIL_DOCX" "Heading1"

    styles_rc=0
    python3 "$FIX_SCRIPT" --fix "$STYLES_FAIL_DOCX" 2>/dev/null || styles_rc=$?
    styles_markers=$(unzip -p "$STYLES_FAIL_DOCX" word/document.xml 2>/dev/null \
      | grep -c 'TESTCASE-START\|TESTCASE-END' || true)
    if [ "$styles_rc" -ne 0 ] && [ "$styles_markers" -eq 0 ]; then
      pass "$TEMPLATE_NAME: markers stripped on styles-phase failure"
    else
      fail "$TEMPLATE_NAME: markers stripped on styles-phase failure (rc=$styles_rc, markers=$styles_markers)"
    fi
  fi

  # 14. Technical cover: Title style is 24pt (sz=48)
  if [ "$TEMPLATE_NAME" = "technical" ]; then
    if python3 - "$STYLES_XML" << 'PYEOF' 2>/dev/null; then
import xml.etree.ElementTree as ET, sys
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "Title":
        rPr = s.find(f"{{{W}}}rPr")
        if rPr is not None:
            sz = rPr.find(f"{{{W}}}sz")
            if sz is not None and sz.get(f"{{{W}}}val") == "48":
                sys.exit(0)
        break
sys.exit(1)
PYEOF
      pass "$TEMPLATE_NAME: Title style is 24pt"
    else
      fail "$TEMPLATE_NAME: Title style is not 24pt (sz!=48)"
    fi
  fi

  # 15. Technical cover: first cover table has red label column AND
  # the first cell text is "Version" (a hijacked body table wouldn't be).
  if [ "$TEMPLATE_NAME" = "technical" ]; then
    if python3 - "$UNZIP_DIR/word/document.xml" << 'PYEOF' 2>/dev/null; then
import xml.etree.ElementTree as ET, sys
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = ET.parse(sys.argv[1])
root = tree.getroot()
tbl = root.find(f".//{{{W}}}tbl")
if tbl is not None:
    rows = tbl.findall(f"{{{W}}}tr")
    if rows:
        cells = rows[0].findall(f"{{{W}}}tc")
        if cells:
            # First cell text must be "Version"
            texts = [t.text for t in cells[0].iter(f"{{{W}}}t") if t.text]
            first_text = "".join(texts).strip()
            if first_text != "Version":
                sys.exit(1)
            # First-column cells must have red shading
            for row in rows:
                rcells = row.findall(f"{{{W}}}tc")
                if rcells:
                    tcPr = rcells[0].find(f"{{{W}}}tcPr")
                    if tcPr is not None:
                        shd = tcPr.find(f"{{{W}}}shd")
                        if shd is not None and shd.get(f"{{{W}}}fill") == "C7000B":
                            continue
                    sys.exit(1)
            sys.exit(0)
sys.exit(1)
PYEOF
      pass "$TEMPLATE_NAME: cover table has red label column"
    else
      fail "$TEMPLATE_NAME: cover table missing red label column"
    fi
  fi

  # 16. No stray Date paragraph on the cover (HIGH-1 regression guard).
  # After --fix, the cover region (before the first Heading/TOC) must
  # contain no paragraph with style_id 'Date' — the date is carried by
  # the meta line; a stray Date paragraph is a regression from the
  # meta-scan change.
  if python3 - "$DOCX_OUT" << 'PYEOF' 2>/dev/null; then
import sys
from docx import Document
doc = Document(sys.argv[1])
for p in doc.paragraphs:
    sid = p.style.style_id or ''
    if sid.startswith('Heading') or sid.startswith('TOC'):
        break
    if sid == 'Date':
        sys.exit(1)
sys.exit(0)
PYEOF
    pass "$TEMPLATE_NAME: no stray Date paragraph on cover"
  else
    fail "$TEMPLATE_NAME: stray Date paragraph on cover"
  fi

  # 17. PT footer label: --lang pt localizes the footer page label to
  # "Página" (PDF \lg@pagelabel — huawei-lang.sty).  Re-run --fix on a
  # pre-fix copy with --lang pt and inspect the footer XML: the PT label
  # must be present and the EN label absent.
  local PT_DOCX="$TMPDIR_FIX/${TEMPLATE_NAME}-pt-lang.docx"
  cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$PT_DOCX"
  python3 "$FIX_SCRIPT" --fix --lang pt "$PT_DOCX" 2>/dev/null
  local PT_UNZIP_DIR="$TMPDIR_FIX/${TEMPLATE_NAME}-pt-unzipped"
  unzip -o -q "$PT_DOCX" -d "$PT_UNZIP_DIR"
  local pt_footer_files=("$PT_UNZIP_DIR"/word/footer*.xml)
  local pt_label_ok=0
  if [ ${#pt_footer_files[@]} -gt 0 ] && [ -f "${pt_footer_files[0]}" ]; then
    for f in "${pt_footer_files[@]}"; do
      if grep -q 'Página' "$f" && ! grep -q 'Page ' "$f"; then
        pt_label_ok=1
        break
      fi
    done
  fi
  if [ "$pt_label_ok" -eq 1 ]; then
    pass "$TEMPLATE_NAME: --lang pt footer label is Página"
  else
    fail "$TEMPLATE_NAME: --lang pt footer label is not Página"
  fi

  # ── Multi-logo header + cover row (guide only — shared docx_fix code) ──
  if [ "$TEMPLATE_NAME" = "guide" ]; then
    local LOGO_DIR="$REPO_ROOT/templates/guide/common-assets"

    # 26. Header logos: --header-logo + --extra-logo-1/--extra-logo-2 →
    # borderless 3-cell TABLE in the header (logo | title | extras —
    # PDF huawei-page.sty).  The tab-based single-paragraph layout wraps
    # in LibreOffice when the line is ~full; the fixed table cannot.
    # Asserts: 3 cells, borderless, zero cell margins, fixed layout,
    # symmetric side columns summing to tblW, STYLEREF field in the
    # center cell, 1 drawing left + 2 right at 1.05cm (cy=378000), and
    # a minimal paragraph after the table (a table cannot end a header).
    local HDR_DOCX="$TMPDIR_FIX/guide-header-logos.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HDR_DOCX"
    python3 "$FIX_SCRIPT" --fix \
      --header-logo "$LOGO_DIR/huawei-logo-header.png" \
      --extra-logo-1 "$LOGO_DIR/huawei-logo-cover.png" \
      --extra-logo-2 "$LOGO_DIR/huawei-logo-header.png" \
      "$HDR_DOCX" 2>/dev/null
    local HDR_UNZIP="$TMPDIR_FIX/guide-header-unzipped"
    unzip -o -q "$HDR_DOCX" -d "$HDR_UNZIP"
    if python3 - "$HDR_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    tbls = root.findall(f"{{{W}}}tbl")
    if len(tbls) != 1:
        continue
    tbl = tbls[0]
    cells = tbl.findall(f"{{{W}}}tr/{{{W}}}tc")
    if len(cells) != 3:
        continue
    tblPr = tbl.find(f"{{{W}}}tblPr")
    # Fixed layout + full-width dxa table
    layout = tblPr.find(f"{{{W}}}tblLayout")
    tblW = tblPr.find(f"{{{W}}}tblW")
    if (layout is None or layout.get(f"{{{W}}}type") != "fixed"
            or tblW is None or tblW.get(f"{{{W}}}type") != "dxa"):
        continue
    # Borderless (all six sides val="none")
    borders = tblPr.find(f"{{{W}}}tblBorders")
    if borders is None or any(
            b.get(f"{{{W}}}val") != "none"
            for b in borders):
        continue
    # Zero left/right cell margins
    mar = tblPr.find(f"{{{W}}}tblCellMar")
    if mar is None or any(
            mar.find(f"{{{W}}}{s}").get(f"{{{W}}}w") != "0"
            for s in ("left", "right")):
        continue
    # Symmetric side columns summing to tblW
    cols = [int(c.get(f"{{{W}}}w"))
            for c in tbl.findall(f"{{{W}}}tblGrid/{{{W}}}gridCol")]
    if (len(cols) != 3 or cols[0] != cols[2]
            or sum(cols) != int(tblW.get(f"{{{W}}}w"))):
        continue
    # STYLEREF field intact in the CENTER cell (paragraph centered)
    instr = [t.text or "" for t in cells[1].iter(f"{{{W}}}instrText")]
    if not any("STYLEREF" in t for t in instr):
        continue
    jc = cells[1].find(f"{{{W}}}p/{{{W}}}pPr/{{{W}}}jc")
    if jc is None or jc.get(f"{{{W}}}val") != "center":
        continue
    # 1 drawing in the left cell, 2 in the right, all 1.05cm tall
    def dr_cys(tc):
        out = []
        for d in tc.findall(f".//{{{W}}}drawing"):
            ext = d.find(".//{http://schemas.openxmlformats.org/"
                         "drawingml/2006/wordprocessingDrawing}extent")
            if ext is not None:
                out.append(ext.get("cy"))
        return out
    left_cys, right_cys = dr_cys(cells[0]), dr_cys(cells[2])
    if (len(left_cys) != 1 or len(right_cys) != 2
            or set(left_cys + right_cys) != {"378000"}):
        continue
    # Images flush: dist*=0 on every wp:inline (LibreOffice pads bare
    # wp:inline by 0.3175cm/side — the wrap root cause).  The dist*
    # attributes are unprefixed (unqualified, per the OOXML schema).
    WP = ("http://schemas.openxmlformats.org/drawingml/2006/"
          "wordprocessingDrawing")
    inlines = tbl.findall(f".//{{{WP}}}inline")
    if len(inlines) != 3 or any(
            any(il.get(a) != "0"
                for a in ("distT", "distB", "distL", "distR"))
            for il in inlines):
        continue
    # A paragraph must follow the table (tables cannot end a header)
    if tbl.getnext() is None or tbl.getnext().tag != f"{{{W}}}p":
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: header logos: borderless 3-cell table, field centered, 1+2 drawings"
    else
      fail "$TEMPLATE_NAME: header logos: table structure wrong"
    fi

    # 27. Extras only (no --header-logo): same 3-cell table with an
    # EMPTY left cell — side columns stay symmetric, so the title in
    # the center cell stays centered on the page axis.
    local HDR2_DOCX="$TMPDIR_FIX/guide-header-extras-only.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HDR2_DOCX"
    python3 "$FIX_SCRIPT" --fix \
      --extra-logo-1 "$LOGO_DIR/huawei-logo-cover.png" \
      "$HDR2_DOCX" 2>/dev/null
    local HDR2_UNZIP="$TMPDIR_FIX/guide-header2-unzipped"
    unzip -o -q "$HDR2_DOCX" -d "$HDR2_UNZIP"
    if python3 - "$HDR2_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    tbls = root.findall(f"{{{W}}}tbl")
    if len(tbls) != 1:
        continue
    tbl = tbls[0]
    cells = tbl.findall(f"{{{W}}}tr/{{{W}}}tc")
    if len(cells) != 3:
        continue
    cols = [int(c.get(f"{{{W}}}w"))
            for c in tbl.findall(f"{{{W}}}tblGrid/{{{W}}}gridCol")]
    if len(cols) != 3 or cols[0] != cols[2]:
        continue
    if cells[0].find(f".//{{{W}}}drawing") is not None:
        continue  # left cell must be empty
    if len(cells[2].findall(f".//{{{W}}}drawing")) != 1:
        continue
    instr = [t.text or "" for t in cells[1].iter(f"{{{W}}}instrText")]
    if not any("STYLEREF" in t for t in instr):
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: extras-only header: table, empty left cell, symmetric sides"
    else
      fail "$TEMPLATE_NAME: extras-only header: table structure wrong"
    fi

    # 28. Left logo only: NO table — the long-standing tab-based layout
    # is kept for this case (backward compat: existing documents with
    # only :header-logo: render exactly as before).
    local HDR3_DOCX="$TMPDIR_FIX/guide-header-left-only.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HDR3_DOCX"
    python3 "$FIX_SCRIPT" --fix \
      --header-logo "$LOGO_DIR/huawei-logo-header.png" \
      "$HDR3_DOCX" 2>/dev/null
    local HDR3_UNZIP="$TMPDIR_FIX/guide-header3-unzipped"
    unzip -o -q "$HDR3_DOCX" -d "$HDR3_UNZIP"
    if python3 - "$HDR3_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    if root.findall(f"{{{W}}}tbl"):
        continue  # no table in the left-only case
    if len(root.findall(f".//{{{W}}}drawing")) != 1:
        continue
    vals = {t.get(f"{{{W}}}val")
            for t in root.findall(f".//{{{W}}}tab")}
    if "center" not in vals:
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: left-only header: tab layout kept (no table)"
    else
      fail "$TEMPLATE_NAME: left-only header: tab layout regressed"
    fi

    # 29. No logos at all: header untouched — no table, no drawings,
    # the STYLEREF title field stays in the header paragraph.
    local HDR4_DOCX="$TMPDIR_FIX/guide-header-nologo.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HDR4_DOCX"
    python3 "$FIX_SCRIPT" --fix "$HDR4_DOCX" 2>/dev/null
    local HDR4_UNZIP="$TMPDIR_FIX/guide-header4-unzipped"
    unzip -o -q "$HDR4_DOCX" -d "$HDR4_UNZIP"
    if python3 - "$HDR4_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    if root.findall(f"{{{W}}}tbl"):
        continue
    if root.findall(f".//{{{W}}}drawing"):
        continue
    instr = [t.text or "" for t in root.iter(f"{{{W}}}instrText")]
    if not any("STYLEREF" in t for t in instr):
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: no-logo header: untouched (no table, field intact)"
    else
      fail "$TEMPLATE_NAME: no-logo header: unexpectedly modified"
    fi

    # 30. Cover logo row: :extra-logo-1:/:extra-logo-2: → main + extras
    # in ONE centered cover paragraph at equal heights (PDF: 3 logos →
    # 2.2cm), and the row fits the text width.  The logos live in
    # <tmpdir>/assets/ and the .adoc references them document-relatively
    # (assets/...), resolved via pandoc --resource-path — same contract
    # as a real project folder.
    local COVER_ASSETS="$TMPDIR_FIX/assets"
    mkdir -p "$COVER_ASSETS"
    cp "$LOGO_DIR/huawei-logo-cover.png" "$COVER_ASSETS/main.png"
    cp "$LOGO_DIR/huawei-logo-header.png" "$COVER_ASSETS/extra1.png"
    cp "$LOGO_DIR/exemplo-login.png" "$COVER_ASSETS/extra2.png"
    local COVER_ADOC="$TMPDIR_FIX/guide-cover-row.adoc"
    cat > "$COVER_ADOC" <<'ADOC'
= Cover Row Test
:lang: en
:version: 1.0.0
:cover-logo: assets/main.png
:extra-logo-1: assets/extra1.png
:extra-logo-2: assets/extra2.png

Body.
ADOC
    local COVER_PRE="$TMPDIR_FIX/guide-cover-pre.adoc"
    python3 "$REPO_ROOT/templates/_base/adoc_docx_preprocessor.py" \
      --template "$TEMPLATE_NAME" "$COVER_ADOC" -o "$COVER_PRE" 2>/dev/null
    local COVER_DBK
    COVER_DBK=$(mktemp --suffix=.dbk)
    asciidoctor -b docbook "$COVER_PRE" -o "$COVER_DBK" 2>/dev/null
    local COVER_PREFIX="$TMPDIR_FIX/guide-cover-prefix.docx"
    pandoc -f docbook --reference-doc="$REF_DOCX" --number-sections \
      --resource-path="$TMPDIR_FIX:$SAMPLE_DIR:$COMMON_ASSETS" \
      "$COVER_DBK" -o "$COVER_PREFIX" 2>/dev/null
    rm -f "$COVER_DBK"
    local COVER_DEFAULT="$TMPDIR_FIX/guide-cover-default.docx"
    cp "$COVER_PREFIX" "$COVER_DEFAULT"
    python3 "$FIX_SCRIPT" --fix "$COVER_DEFAULT" 2>/dev/null
    if python3 - "$COVER_DEFAULT" << 'PYEOF' 2>/dev/null; then
import sys
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
EMU_PER_CM = 360000
doc = Document(sys.argv[1])
cover_paras = []
for p in doc.paragraphs:
    sid = p.style.style_id or ''
    if sid.startswith('Heading') or sid.startswith('TOC'):
        break
    cover_paras.append(p)
img_paras = [p for p in cover_paras
             if p._p.find('.//' + qn('w:drawing')) is not None]
if len(img_paras) != 1:
    sys.exit(1)  # logos must share ONE paragraph
drawings = img_paras[0]._p.findall('.//' + qn('w:drawing'))
if len(drawings) != 3:
    sys.exit(1)
cys = []
for d in drawings:
    ext = d.find('.//' + qn('wp:extent'))
    if ext is None:
        sys.exit(1)
    cys.append(int(ext.get('cy', '0')))
# Equal heights at the 3-logo default (2.2cm)
if len(set(cys)) != 1 or cys[0] != int(2.2 * EMU_PER_CM):
    sys.exit(1)
# Row (with spacer gaps) fits the text width
section = doc.sections[0]
text_width = section.page_width - section.left_margin - section.right_margin
cxs = []
for d in drawings:
    ext = d.find('.//' + qn('wp:extent'))
    cxs.append(int(ext.get('cx', '0')))
gaps = int(0.6 * EMU_PER_CM) * (len(drawings) - 1)
if sum(cxs) + gaps > text_width:
    sys.exit(1)
# Centered row
if img_paras[0].alignment != WD_ALIGN_PARAGRAPH.CENTER:
    sys.exit(1)
sys.exit(0)
PYEOF
      pass "$TEMPLATE_NAME: cover row: 3 logos, one paragraph, equal 2.2cm heights"
    else
      fail "$TEMPLATE_NAME: cover row: logos not merged or heights wrong"
    fi

    # 31. --cover-logo-height overrides the row height (2.4cm)
    local COVER_H_DOCX="$TMPDIR_FIX/guide-cover-height.docx"
    cp "$COVER_PREFIX" "$COVER_H_DOCX"
    python3 "$FIX_SCRIPT" --fix --cover-logo-height 2.4cm \
      "$COVER_H_DOCX" 2>/dev/null
    if python3 - "$COVER_H_DOCX" << 'PYEOF' 2>/dev/null; then
import sys
from docx import Document
from docx.oxml.ns import qn
EMU_PER_CM = 360000
doc = Document(sys.argv[1])
for p in doc.paragraphs:
    sid = p.style.style_id or ''
    if sid.startswith('Heading') or sid.startswith('TOC'):
        sys.exit(1)  # no cover drawing found before the first heading
    drawings = p._p.findall('.//' + qn('w:drawing'))
    if drawings:
        cys = set()
        for d in drawings:
            ext = d.find('.//' + qn('wp:extent'))
            cys.add(int(ext.get('cy', '0')))
        sys.exit(0 if cys == {int(2.4 * EMU_PER_CM)} else 1)
sys.exit(1)
PYEOF
      pass "$TEMPLATE_NAME: cover row: --cover-logo-height 2.4cm honored"
    else
      fail "$TEMPLATE_NAME: cover row: --cover-logo-height not honored"
    fi

    # 32. Single-logo cover regression: the main sample's cover logo
    # keeps the 3.6cm width sizing (multi-logo logic must not touch it).
    if python3 - "$DOCX_OUT" << 'PYEOF' 2>/dev/null; then
import sys
from docx import Document
from docx.oxml.ns import qn
doc = Document(sys.argv[1])
for p in doc.paragraphs:
    sid = p.style.style_id or ''
    if sid.startswith('Heading') or sid.startswith('TOC'):
        sys.exit(1)  # no cover drawing found before the first heading
    d = p._p.find('.//' + qn('w:drawing'))
    if d is not None:
        ext = d.find('.//' + qn('wp:extent'))
        sys.exit(0 if (ext is not None
                       and int(ext.get('cx', '0')) == 1296000) else 1)
sys.exit(1)
PYEOF
      pass "$TEMPLATE_NAME: single-logo cover keeps 3.6cm width"
    else
      fail "$TEMPLATE_NAME: single-logo cover sizing changed"
    fi

    # 33. --header-title: the STYLEREF field is replaced by ONE literal
    # run (styled like the field's own runs) — no fldChar/instrText may
    # remain anywhere in the header.
    local HT_DOCX="$TMPDIR_FIX/guide-header-title.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HT_DOCX"
    python3 "$FIX_SCRIPT" --fix --header-title "Custom Header" \
      "$HT_DOCX" 2>/dev/null
    local HT_UNZIP="$TMPDIR_FIX/guide-header-title-unzipped"
    unzip -o -q "$HT_DOCX" -d "$HT_UNZIP"
    if python3 - "$HT_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    if root.findall(f".//{{{W}}}fldChar"):
        continue  # field must be gone
    if any("STYLEREF" in (t.text or "")
           for t in root.iter(f"{{{W}}}instrText")):
        continue
    # Exactly one literal run with the custom text, styled 10pt
    hits = [t for t in root.iter(f"{{{W}}}t")
            if t.text == "Custom Header"]
    if len(hits) != 1:
        continue
    rPr = hits[0].getparent().find(f"{{{W}}}rPr")
    sz = rPr.find(f"{{{W}}}sz") if rPr is not None else None
    fonts = rPr.find(f"{{{W}}}rFonts") if rPr is not None else None
    if (sz is None or sz.get(f"{{{W}}}val") != "20"
            or fonts is None
            or fonts.get(f"{{{W}}}ascii") != "HarmonyOS Sans"):
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: --header-title: literal run replaces STYLEREF field"
    else
      fail "$TEMPLATE_NAME: --header-title: field remains or run unstyled"
    fi

    # 34. No --header-title flag: the STYLEREF field stays intact
    # (regression guard — unset :header-title: keeps today's behavior).
    local HT2_DOCX="$TMPDIR_FIX/guide-header-title-off.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HT2_DOCX"
    python3 "$FIX_SCRIPT" --fix "$HT2_DOCX" 2>/dev/null
    local HT2_UNZIP="$TMPDIR_FIX/guide-header-title-off-unzipped"
    unzip -o -q "$HT2_DOCX" -d "$HT2_UNZIP"
    if python3 - "$HT2_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    if not any("STYLEREF" in (t.text or "")
               for t in root.iter(f"{{{W}}}instrText")):
        continue
    if not root.findall(f".//{{{W}}}fldChar"):
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: no --header-title: STYLEREF field intact"
    else
      fail "$TEMPLATE_NAME: no --header-title: field lost"
    fi

    # 35. --header-title + extra logos (table path): the literal text
    # lands in the CENTER cell (not a side cell), the field is gone,
    # and the logo drawings stay in their side cells.
    local HT3_DOCX="$TMPDIR_FIX/guide-header-title-table.docx"
    cp "$TMPDIR_FIX/${TEMPLATE_NAME}-prefix.docx" "$HT3_DOCX"
    python3 "$FIX_SCRIPT" --fix --header-title "Custom Header" \
      --header-logo "$LOGO_DIR/huawei-logo-header.png" \
      --extra-logo-1 "$LOGO_DIR/huawei-logo-cover.png" \
      --extra-logo-2 "$LOGO_DIR/huawei-logo-header.png" \
      "$HT3_DOCX" 2>/dev/null
    local HT3_UNZIP="$TMPDIR_FIX/guide-header-title-table-unzipped"
    unzip -o -q "$HT3_DOCX" -d "$HT3_UNZIP"
    if python3 - "$HT3_UNZIP" << 'PYEOF' 2>/dev/null; then
import sys, glob
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
unzip_dir = sys.argv[1]
ok = False
for f in sorted(glob.glob(unzip_dir + "/word/header*.xml")):
    root = etree.parse(f).getroot()
    if root.findall(f".//{{{W}}}fldChar"):
        continue
    tbl = root.find(f"{{{W}}}tbl")
    if tbl is None:
        continue
    cells = tbl.findall(f"{{{W}}}tr/{{{W}}}tc")
    if len(cells) != 3:
        continue
    # Literal text in the CENTER cell only
    center_texts = [t.text for t in cells[1].iter(f"{{{W}}}t")
                    if t.text]
    if center_texts != ["Custom Header"]:
        continue
    # Logos intact: 1 drawing left, 2 right
    if len(cells[0].findall(f".//{{{W}}}drawing")) != 1:
        continue
    if len(cells[2].findall(f".//{{{W}}}drawing")) != 2:
        continue
    ok = True
    break
sys.exit(0 if ok else 1)
PYEOF
      pass "$TEMPLATE_NAME: --header-title + extras: literal in center cell, logos intact"
    else
      fail "$TEMPLATE_NAME: --header-title + extras: layout broken"
    fi
  fi
}

# ── Auto-discover templates and run DOCX fix tests for each ──────────────
for tmpl_dir in "$REPO_ROOT"/templates/*/; do
    tmpl_name=$(basename "$tmpl_dir")
    [ "$tmpl_name" = "_base" ] && continue
    [ ! -f "$tmpl_dir/${tmpl_name}.cls" ] && continue

    fix_script="$REPO_ROOT/templates/${tmpl_name}/create-${tmpl_name}-reference-docx.py"
    filter="$REPO_ROOT/templates/${tmpl_name}/${tmpl_name}-pandoc.lua"
    ref_docx="$REPO_ROOT/templates/${tmpl_name}/${tmpl_name}-reference.docx"
    sample_dir="$REPO_ROOT/documents/${tmpl_name}-en"
    common_assets="$REPO_ROOT/templates/${tmpl_name}/common-assets"

    # Run if fix_script + ref_docx exist, and either .adoc source or legacy Lua filter is available
    adoc_source="$sample_dir/src/main.adoc"
    if [ -f "$fix_script" ] && [ -f "$ref_docx" ] && { [ -f "$adoc_source" ] || [ -f "$filter" ]; }; then
        run_template_tests "$tmpl_name" "$fix_script" "$filter" "$ref_docx" "$sample_dir" "$common_assets"
    fi
done

# ── PT callout labels + PT testbook badges ─────────────────────────────────
# Build a minimal DOCX with callout sentinels and testbook badge markers,
# run --fix --lang pt, and verify the output uses PT labels/badges.
echo ""
echo "=== PT callout labels + PT testbook badges ==="

PT_LANG_DOCX="$TMPDIR_FIX/pt-lang-test.docx"
PT_LANG_OUT="$TMPDIR_FIX/pt-lang-fixed.docx"
# Start from the testbook reference DOCX (has the styles --fix expects)
cp "$REPO_ROOT/templates/testbook/testbook-reference.docx" "$PT_LANG_DOCX"
python3 - "$PT_LANG_DOCX" << 'PYEOF'
import sys
from docx import Document
from docx.shared import Pt
doc = Document(sys.argv[1])
# Callout sentinels (preprocessor format: **TYPE‖** text → bold "TYPE‖" run)
for sentinel, body in [('TIP', 'Dica callout body'),
                        ('NOTE', 'Info callout body'),
                        ('WARNING', 'Important callout body')]:
    p = doc.add_paragraph()
    r = p.add_run(sentinel + '\u2016' + body)
    r.bold = True
# Testbook badge markers (preprocessor emits [Pass]/[Partial]/[Fail]/
# [Untested] under pt; Blocked was dropped from the vocabulary)
for badge in ['[Pass]', '[Partial]', '[Fail]', '[Untested]']:
    p = doc.add_paragraph()
    r = p.add_run(badge)
    r.bold = True
doc.save(sys.argv[1])
PYEOF

cp "$PT_LANG_DOCX" "$PT_LANG_OUT"
python3 "$REPO_ROOT/templates/testbook/create-testbook-reference-docx.py" \
    --fix --lang pt "$PT_LANG_OUT" 2>/dev/null

# Unzip for inspection
PT_LANG_UNZIP="$TMPDIR_FIX/pt-lang-unzipped"
unzip -o -q "$PT_LANG_OUT" -d "$PT_LANG_UNZIP"

# 18. PT callout labels: Dica/Informação/Importante present, EN labels absent
pt_callout_ok=0
if python3 - "$PT_LANG_UNZIP/word/document.xml" << 'PYEOF' 2>/dev/null; then
import sys
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = etree.parse(sys.argv[1])
root = tree.getroot()
texts = [t.text for t in root.iter(f"{{{W}}}t") if t.text]
full = " ".join(texts)
# PT labels must be present
for pt_label in ['Dica:', 'Informação:', 'Importante:']:
    if pt_label not in full:
        sys.exit(1)
# EN labels must be absent
for en_label in ['Tip:', 'Info:', 'Important:']:
    if en_label in full:
        sys.exit(1)
sys.exit(0)
PYEOF
  pt_callout_ok=1
fi
if [ "$pt_callout_ok" -eq 1 ]; then
  pass "PT callout labels: Dica/Informação/Importante (no EN leak)"
else
  fail "PT callout labels: EN labels leaked or PT labels missing"
fi

# 19. PT callout labels: EN mode still uses Tip/Info/Important
EN_LANG_OUT="$TMPDIR_FIX/en-lang-fixed.docx"
cp "$PT_LANG_DOCX" "$EN_LANG_OUT"
python3 "$REPO_ROOT/templates/testbook/create-testbook-reference-docx.py" \
    --fix --lang en "$EN_LANG_OUT" 2>/dev/null
EN_LANG_UNZIP="$TMPDIR_FIX/en-lang-unzipped"
unzip -o -q "$EN_LANG_OUT" -d "$EN_LANG_UNZIP"

en_callout_ok=0
if python3 - "$EN_LANG_UNZIP/word/document.xml" << 'PYEOF' 2>/dev/null; then
import sys
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
tree = etree.parse(sys.argv[1])
root = tree.getroot()
texts = [t.text for t in root.iter(f"{{{W}}}t") if t.text]
full = " ".join(texts)
for en_label in ['Tip:', 'Info:', 'Important:']:
    if en_label not in full:
        sys.exit(1)
sys.exit(0)
PYEOF
  en_callout_ok=1
fi
if [ "$en_callout_ok" -eq 1 ]; then
  pass "EN callout labels: Tip/Info/Important (default lang)"
else
  fail "EN callout labels: missing Tip/Info/Important"
fi

# 20. PT testbook badges: PNG images embedded (Atende/Atende com
# ressalvas/Não atende/Não testado), no EN badge text leaked.
pt_badge_ok=0
if python3 - "$PT_LANG_OUT" << 'PYEOF' 2>/dev/null; then
import sys, zipfile
from docx import Document
doc = Document(sys.argv[1])
# Collect all run text (badge PNGs replace text with images, so the
# EN badge labels [Pass]/[Partial]/[Fail]/[Untested] must be gone).
all_text = []
for p in doc.paragraphs:
    for r in p.runs:
        if r.text:
            all_text.append(r.text)
for tbl in doc.tables:
    for row in tbl.rows:
        for cell in row.cells:
            for p in cell.paragraphs:
                for r in p.runs:
                    if r.text:
                        all_text.append(r.text)
full = " ".join(all_text)
for en_badge in ['[Pass]', '[Partial]', '[Fail]', '[Untested]']:
    if en_badge in full:
        sys.exit(1)
# Count embedded images (drawings) — expect >= 4 badge PNGs
img_count = 0
for p in doc.paragraphs:
    if p._p.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}drawing') is not None:
        img_count += 1
if img_count < 4:
    sys.exit(1)
sys.exit(0)
PYEOF
  pt_badge_ok=1
fi
if [ "$pt_badge_ok" -eq 1 ]; then
  pass "PT testbook badges: PNGs embedded, no EN badge text leaked"
else
  fail "PT testbook badges: EN text leaked or PNGs not embedded"
fi

# 21. PT testbook badges: the four PT PNG assets exist on disk
pt_png_ok=0
badge_dir="$REPO_ROOT/templates/_base/badge-assets"
for label in Atende "Atende com ressalvas" "Não atende" "Não testado"; do
  if [ ! -f "$badge_dir/badge-${label}-1.5cm.png" ]; then
    pt_png_ok=0
    break
  fi
  pt_png_ok=1
done
if [ "$pt_png_ok" -eq 1 ]; then
  pass "PT testbook badge PNGs exist (Atende/Atende com ressalvas/Não atende/Não testado)"
else
  fail "PT testbook badge PNGs missing"
fi

# 22. EN testbook badges: PNG images embedded, EN badge text gone
en_badge_ok=0
if python3 - "$EN_LANG_OUT" << 'PYEOF' 2>/dev/null; then
import sys
from docx import Document
doc = Document(sys.argv[1])
all_text = []
for p in doc.paragraphs:
    for r in p.runs:
        if r.text:
            all_text.append(r.text)
full = " ".join(all_text)
for en_badge in ['[Pass]', '[Partial]', '[Fail]', '[Untested]']:
    if en_badge in full:
        sys.exit(1)
img_count = 0
for p in doc.paragraphs:
    if p._p.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}drawing') is not None:
        img_count += 1
if img_count < 4:
    sys.exit(1)
sys.exit(0)
PYEOF
  en_badge_ok=1
fi
if [ "$en_badge_ok" -eq 1 ]; then
  pass "EN testbook badges: PNGs embedded, no badge text leaked"
else
  fail "EN testbook badges: text leaked or PNGs not embedded"
fi

# 23. PT testbook badges via BADGE_MARKERS: direct [Atende] marker
# (robustness — if the preprocessor ever emits PT text directly)
PT_DIRECT_DOCX="$TMPDIR_FIX/pt-direct-test.docx"
cp "$REPO_ROOT/templates/testbook/testbook-reference.docx" "$PT_DIRECT_DOCX"
python3 - "$PT_DIRECT_DOCX" << 'PYEOF'
import sys
from docx import Document
doc = Document(sys.argv[1])
for badge in ['[Atende]', '[Atende com ressalvas]', '[Não atende]', '[Não testado]']:
    p = doc.add_paragraph()
    r = p.add_run(badge)
    r.bold = True
doc.save(sys.argv[1])
PYEOF
python3 "$REPO_ROOT/templates/testbook/create-testbook-reference-docx.py" \
    --fix --lang pt "$PT_DIRECT_DOCX" 2>/dev/null

pt_direct_ok=0
if python3 - "$PT_DIRECT_DOCX" << 'PYEOF' 2>/dev/null; then
import sys
from docx import Document
doc = Document(sys.argv[1])
all_text = []
for p in doc.paragraphs:
    for r in p.runs:
        if r.text:
            all_text.append(r.text)
full = " ".join(all_text)
for pt_badge in ['[Atende]', '[Atende com ressalvas]', '[Não atende]', '[Não testado]']:
    if pt_badge in full:
        sys.exit(1)
img_count = 0
for p in doc.paragraphs:
    if p._p.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}drawing') is not None:
        img_count += 1
if img_count < 4:
    sys.exit(1)
sys.exit(0)
PYEOF
  pt_direct_ok=1
fi
if [ "$pt_direct_ok" -eq 1 ]; then
  pass "PT testbook badges: direct [Atende] markers resolved to PNGs"
else
  fail "PT testbook badges: direct PT markers not resolved"
fi

# 24. PT testbook badges: byte-level PNG verification.  Check 20 cannot
# tell a PT PNG embed from an EN one (both leave no badge text behind),
# so verify the embedded media is byte-identical to the PT pill PNGs
# (python-docx stores the original image bytes verbatim) and that no EN
# testbook PNG was embedded.  Guards TESTBOOK_PT_BADGE_LABELS.
pt_png_bytes_ok=0
if python3 - "$PT_LANG_OUT" "$REPO_ROOT/templates/_base/badge-assets" << 'PYEOF' 2>/dev/null; then
import hashlib, os, sys, zipfile

docx_path, badge_dir = sys.argv[1], sys.argv[2]

def md5(blob):
    return hashlib.md5(blob).hexdigest()

with zipfile.ZipFile(docx_path) as z:
    media_md5 = {md5(z.read(n)) for n in z.namelist()
                 if n.startswith('word/media/')}

# PT pill PNGs must be embedded (byte-identical)
for label in ('Atende', 'Atende com ressalvas', 'Não atende', 'Não testado'):
    src = os.path.join(badge_dir, 'badge-{}-1.5cm.png'.format(label))
    with open(src, 'rb') as f:
        if md5(f.read()) not in media_md5:
            sys.exit(1)

# EN pill PNGs must NOT be embedded (translation must have happened)
for label in ('Pass', 'Partial', 'Fail', 'Untested'):
    src = os.path.join(badge_dir, 'badge-{}-1.5cm.png'.format(label))
    with open(src, 'rb') as f:
        if md5(f.read()) in media_md5:
            sys.exit(1)
sys.exit(0)
PYEOF
  pt_png_bytes_ok=1
fi
if [ "$pt_png_bytes_ok" -eq 1 ]; then
  pass "PT testbook badges: PT PNGs embedded byte-identical, EN PNGs absent"
else
  fail "PT testbook badges: wrong PNG variant embedded"
fi

# 25. Badge PNG inventory: every label (EN testbook/POC + shared PT)
# exists at BOTH nominal widths (1.5cm testbook, 2cm POC) — matches the
# generate-badges.py SPECS.
png_inventory_missing=""
for label in Pass Partial Fail Skip Untested \
             Atende "Atende com ressalvas" "Não atende" "Não testado"; do
  for width in 1.5cm 2cm; do
    png="$REPO_ROOT/templates/_base/badge-assets/badge-${label}-${width}.png"
    if [ ! -f "$png" ]; then
      png_inventory_missing="$png_inventory_missing badge-${label}-${width}.png"
    fi
  done
done
if [ -z "$png_inventory_missing" ]; then
  pass "Badge PNG inventory complete (9 labels × 2 widths)"
else
  fail "Badge PNGs missing:$png_inventory_missing"
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "OK: DOCX --fix verified for all templates ($PASS checks passed)"
else
  echo "FAIL: $FAIL check(s) failed, $PASS passed"
fi
exit $FAIL
