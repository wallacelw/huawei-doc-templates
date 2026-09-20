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

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "OK: DOCX --fix verified for all templates ($PASS checks passed)"
else
  echo "FAIL: $FAIL check(s) failed, $PASS passed"
fi
exit $FAIL
