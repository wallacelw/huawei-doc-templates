#!/usr/bin/env bash
# test-docx-fix.sh — Smoke test for DOCX post-processing for all templates
# Verifies that the --fix pipeline produces correct heading styles,
# list indentation, and footer page numbers in the generated DOCX.
# Also verifies pandoc version pin and loud-failure assertions.
# Tests both guide and technical templates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Temp directory (cleaned up on exit)
TMPDIR_FIX="$(mktemp -d "${TMPDIR:-/tmp}/rt-docx-fix.XXXXXX")"
trap 'rm -rf "$TMPDIR_FIX"' EXIT

PASS=0; FAIL=0

fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }

# ── Pandoc version check ──────────────────────────────────────────────────
# Must be in supported range >=3.1.0, <3.2.0 (matches SUPPORTED_PANDOC_RANGE
# in docx-fix.py)
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
# Compare: >=3.1.0 and <3.2.0
PANDOC_NUM=$((PANDOC_MAJOR * 10000 + PANDOC_MINOR * 100 + PANDOC_PATCH))
MIN_NUM=$((3 * 10000 + 1 * 100 + 0))   # 30100 = 3.1.0
MAX_NUM=$((3 * 10000 + 2 * 100 + 0))   # 30200 = 3.2.0
if [ "$PANDOC_NUM" -lt "$MIN_NUM" ] || [ "$PANDOC_NUM" -ge "$MAX_NUM" ]; then
  echo "  FAIL: pandoc $PANDOC_VERSION is outside supported range (3.1.0–3.2.0)"
  exit 1
fi
echo "  pandoc version: $PANDOC_VERSION (in supported range 3.1.0–3.2.0)"

# ── Template test function ────────────────────────────────────────────────
# run_template_tests <template_name> <fix_script> <filter> <ref_docx> <sample_dir> <common_assets>
run_template_tests() {
  local TEMPLATE_NAME="$1"
  local FIX_SCRIPT="$2"
  local FILTER="$3"
  local REF_DOCX="$4"
  local SAMPLE_DIR="$5"
  local COMMON_ASSETS="$6"

  local TEX_FILE="$SAMPLE_DIR/src/main.tex"
  local DOCX_OUT="$TMPDIR_FIX/${TEMPLATE_NAME}-main.docx"

  echo ""
  echo "=== DOCX --fix smoke test: $TEMPLATE_NAME ==="

  # ── Generate DOCX from en sample ───────────────────────────────────────
  echo "Generating DOCX..."
  pandoc -f latex+raw_tex --lua-filter="$FILTER" \
    --reference-doc="$REF_DOCX" --number-sections \
    --resource-path="$SAMPLE_DIR:$REPO_ROOT/templates/${tmpl_name}:$COMMON_ASSETS" \
    -t docx "$TEX_FILE" -o "$DOCX_OUT" 2>/dev/null

  echo "Running --fix..."
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

  # ── Loud-failure assertions ────────────────────────────────────────────
  echo ""
  echo "=== Loud-failure assertion tests: $TEMPLATE_NAME ==="

  # 8. Missing Heading1 style → RuntimeError
  BROKEN_DOCX="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_heading1.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX"
  python3 - "$BROKEN_DOCX" << 'PYEOF'
import sys, zipfile, shutil, tempfile, os
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
docx_path = sys.argv[1]
with zipfile.ZipFile(docx_path, 'r') as z:
    styles_xml = z.read('word/styles.xml')
root = etree.fromstring(styles_xml)
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "Heading1":
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

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing Heading1 style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing Heading1 style causes --fix to fail with non-zero exit"
  fi

  # 9. Missing Title style → RuntimeError
  BROKEN_DOCX2="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_title.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX2"
  python3 - "$BROKEN_DOCX2" << 'PYEOF'
import sys, zipfile, shutil
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
docx_path = sys.argv[1]
with zipfile.ZipFile(docx_path, 'r') as z:
    styles_xml = z.read('word/styles.xml')
root = etree.fromstring(styles_xml)
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "Title":
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

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX2" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing Title style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing Title style causes --fix to fail with non-zero exit"
  fi

  # 10. Missing Normal style → RuntimeError
  BROKEN_DOCX3="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_normal.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX3"
  python3 - "$BROKEN_DOCX3" << 'PYEOF'
import sys, zipfile, shutil
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
docx_path = sys.argv[1]
with zipfile.ZipFile(docx_path, 'r') as z:
    styles_xml = z.read('word/styles.xml')
root = etree.fromstring(styles_xml)
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "Normal":
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

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX3" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing Normal style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing Normal style causes --fix to fail with non-zero exit"
  fi

  # 11. Missing VerbatimChar style → RuntimeError
  BROKEN_DOCX4="$TMPDIR_FIX/${TEMPLATE_NAME}-broken_verbatim.docx"
  cp "$DOCX_OUT" "$BROKEN_DOCX4"
  python3 - "$BROKEN_DOCX4" << 'PYEOF'
import sys, zipfile, shutil
from lxml import etree
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
docx_path = sys.argv[1]
with zipfile.ZipFile(docx_path, 'r') as z:
    styles_xml = z.read('word/styles.xml')
root = etree.fromstring(styles_xml)
for s in root.findall(f"{{{W}}}style"):
    if s.get(f"{{{W}}}styleId") == "VerbatimChar":
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

  if python3 "$FIX_SCRIPT" --fix "$BROKEN_DOCX4" 2>/dev/null; then
    fail "$TEMPLATE_NAME: Missing VerbatimChar style did not cause --fix to fail"
  else
    pass "$TEMPLATE_NAME: Missing VerbatimChar style causes --fix to fail with non-zero exit"
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
    sample_dir="$REPO_ROOT/examples/${tmpl_name}/en"
    common_assets="$REPO_ROOT/templates/${tmpl_name}/common-assets"

    if [ -f "$fix_script" ] && [ -f "$filter" ] && [ -f "$ref_docx" ]; then
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
