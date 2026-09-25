#!/usr/bin/env bash
set -euo pipefail

# render-pages.sh — render a document's built outputs (PDF, DOCX, HTML)
# to PNG page images for visual verification.
#
# Part of the AGENTS.md "Visual verification" standard: text-based checks
# (compile logs, pdftotext, grep) cannot see layout defects. This script
# produces the page images that a vision-capable agent (or human) inspects.
#
# Usage:
#   scripts/render-pages.sh <doc-dir> [--format pdf,docx,html]
#                           [--pages all|N|N-M] [--dpi 150] [--out <dir>]
#   scripts/render-pages.sh --samples
#
# Output: <doc-dir>/visual-qa/<format>/page-*.png (gitignored; pdftoppm
#         pads to the document's total page count, e.g. page-01.png for
#         10+ pages, page-1.png for < 10).
#
# Rendering paths:
#   pdf  : pdftoppm (poppler-utils)
#   html : chromium --headless --print-to-pdf -> pdftoppm
#          (uses the puppeteer-cached chromium; override with CHROME_BIN)
#   docx : soffice --headless -> PDF -> pdftoppm
#          (override with SOFFICE_BIN; graceful skip when not installed)
#
# DOCX notes (researched 2026): LibreOffice is the only headless renderer
# that uses system fonts via fontconfig. Never use --convert-to png
# (LibreOffice exports only the FIRST page — tdf#157425); always go
# DOCX -> PDF -> PNG. soffice exit codes are unreliable: assert the output
# file exists. Each run gets an isolated profile (LibreOffice locks its
# default profile) and a timeout (corrupt input can hang).

DPI="150"
FORMATS="pdf,docx,html"
PAGES="all"
OUT=""
DOC_DIR=""
SAMPLES=0
RENDERED=0
SKIPPED=0
TMP_ROOT="$(mktemp -d /tmp/render-pages.XXXXXX)"

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

command -v pdftoppm >/dev/null 2>&1 || die "pdftoppm not found (install poppler-utils)"

usage() {
  cat <<'EOF'
Usage: scripts/render-pages.sh <doc-dir> [options]
       scripts/render-pages.sh --samples

Renders a document's built outputs (PDF, DOCX, HTML) to PNG page images
for visual verification (AGENTS.md "Visual verification" standard).

Options:
  --format pdf,docx,html   formats to render (default: pdf,docx,html)
  --pages all|N|N-M        page selection (default: all)
  --dpi N                  rasterization DPI (default: 150)
  --out <dir>              output root (default: <doc-dir>/visual-qa)
  --samples                render all template samples (documents/<name>-{pt,en})
  -h, --help               show this help

Environment:
  CHROME_BIN    override the chromium binary (default: puppeteer cache)
  SOFFICE_BIN   override the soffice binary (default: PATH lookup)
EOF
  exit "${1:-1}"
}

# --- argument parsing ----------------------------------------------------

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) [[ $# -ge 2 ]] || usage; FORMATS="$2"; shift 2 ;;
    --pages) [[ $# -ge 2 ]] || usage; PAGES="$2"; shift 2 ;;
    --dpi) [[ $# -ge 2 ]] || usage; DPI="$2"; shift 2 ;;
    --out) [[ $# -ge 2 ]] || usage; OUT="$2"; shift 2 ;;
    --samples) SAMPLES=1; shift ;;
    -h|--help) usage 0 ;;
    -*) usage ;;
    *) [[ -z "$DOC_DIR" ]] || usage; DOC_DIR="$1"; shift ;;
  esac
done

[[ "$SAMPLES" -eq 1 && -n "$DOC_DIR" ]] && usage
[[ "$SAMPLES" -eq 1 && -n "$OUT" ]] && die "cannot combine --samples with --out"
[[ -d templates ]] || die "run from the repo root (templates/ not found)"

# --- helpers --------------------------------------------------------------

find_file() { # find_file <dir> <preferred-name> <glob>
  local dir="$1" pref="$2" glob="$3" f
  [[ -f "$dir/$pref" ]] && { echo "$dir/$pref"; return 0; }
  for f in "$dir"/$glob; do
    [[ -f "$f" ]] && { echo "$f"; return 0; }
  done
  return 1
}

page_args() { # emit pdftoppm -f/-l for $PAGES (empty for all)
  if [[ "$PAGES" == "all" ]]; then
    return 0
  elif [[ "$PAGES" =~ ^[0-9]+$ ]]; then
    echo "-f $PAGES -l $PAGES"
  elif [[ "$PAGES" =~ ^[0-9]+-[0-9]+$ ]]; then
    echo "-f ${PAGES%-*} -l ${PAGES#*-}"
  else
    die "invalid --pages '$PAGES' (use all, N, or N-M)"
  fi
}

rasterize() { # rasterize <pdf> <outdir> — prints page count
  local pdf="$1" outdir="$2" args n
  mkdir -p "$outdir"
  rm -f "$outdir"/page-*.png  # clear stale pages from prior runs
  args="$(page_args)"
  # shellcheck disable=SC2086
  pdftoppm -png -r "$DPI" $args "$pdf" "$outdir/page"
  n="$(find "$outdir" -maxdepth 1 -name 'page-*.png' | wc -l)"
  [[ "$n" -gt 0 ]] || die "pdftoppm produced no pages for $pdf"
  echo "$n"
}

# --- format renderers (return 0 = rendered, 2 = skipped) ------------------

render_pdf() { # render_pdf <doc-dir> <out-root>
  local dir="$1" out="$2/pdf" pdf n
  pdf="$(find_file "$dir" main.pdf '*.pdf')" || { warn "pdf: no PDF found in $dir — skipped"; return 2; }
  n="$(rasterize "$pdf" "$out")"
  echo "pdf:  $n page(s) -> $out"
}

render_html() { # render_html <doc-dir> <out-root>
  local dir="$1" out="$2/html" html chrome tmp_pdf n
  html="$(find_file "$dir" main.html '*.html')" || { warn "html: no HTML found in $dir — skipped"; return 2; }
  chrome="${CHROME_BIN:-}"
  if [[ -z "$chrome" ]]; then
    chrome="$(find "${XDG_CACHE_HOME:-$HOME/.cache}/puppeteer/chrome" -type f -name chrome 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$chrome" || ! -x "$chrome" ]]; then
    warn "html: no chromium found (install puppeteer cache or set CHROME_BIN) — skipped"
    return 2
  fi
  tmp_pdf="$TMP_ROOT/html-print.pdf"
  "$chrome" --headless --no-sandbox --disable-gpu \
    --virtual-time-budget=10000 --no-pdf-header-footer \
    --print-to-pdf="$tmp_pdf" "file://$(readlink -f "$html")" >/dev/null 2>&1 \
    || die "html: chromium print-to-pdf failed"
  [[ -s "$tmp_pdf" ]] || die "html: chromium produced no PDF"
  n="$(rasterize "$tmp_pdf" "$out")"
  echo "html: $n page(s) -> $out"
}

render_docx() { # render_docx <doc-dir> <out-root>
  local dir="$1" out="$2/docx" docx soffice tmp_pdf n fm
  docx="$(find_file "$dir" main.docx '*.docx')" || { warn "docx: no DOCX found in $dir — skipped"; return 2; }
  soffice="${SOFFICE_BIN:-$(command -v soffice || command -v libreoffice || true)}"
  if [[ -z "$soffice" ]]; then
    warn "docx: LibreOffice not installed (apt-get install --no-install-recommends libreoffice-writer-nogui) — skipped"
    return 2
  fi
  # Font transparency: silent fontconfig substitution changes layout.
  # L8 blesses HarmonyOS Sans -> Liberation Sans and Cascadia Code ->
  # DejaVu Sans Mono as fallbacks; anything else deserves a loud note.
  for fm in "HarmonyOS Sans" "Cascadia Code"; do
    echo "docx: fc-match '$fm' -> $(fc-match "$fm" 2>/dev/null | head -1)"
  done
  tmp_pdf="$TMP_ROOT/$(basename "${docx%.docx}").pdf"
  if ! timeout 120 "$soffice" --headless \
       -env:UserInstallation="file://$TMP_ROOT/lo-profile" \
       --convert-to 'pdf:writer_pdf_Export' --outdir "$TMP_ROOT" "$docx" >/dev/null 2>&1; then
    die "docx: soffice conversion failed or timed out"
  fi
  [[ -s "$tmp_pdf" ]] || die "docx: soffice produced no PDF (exit codes are unreliable)"
  n="$(rasterize "$tmp_pdf" "$out")"
  echo "docx: $n page(s) -> $out"
}

# --- per-document driver ---------------------------------------------------

render_doc() { # render_doc <doc-dir>
  local dir="$1" out f
  [[ -d "$dir" ]] || die "not a directory: $dir"
  out="${OUT:-$dir/visual-qa}"
  echo "=== $dir ==="
  for f in ${FORMATS//,/ }; do
    case "$f" in
      pdf)
        if render_pdf "$dir" "$out"; then RENDERED=$((RENDERED + 1)); else SKIPPED=$((SKIPPED + 1)); fi ;;
      html)
        if render_html "$dir" "$out"; then RENDERED=$((RENDERED + 1)); else SKIPPED=$((SKIPPED + 1)); fi ;;
      docx)
        if render_docx "$dir" "$out"; then RENDERED=$((RENDERED + 1)); else SKIPPED=$((SKIPPED + 1)); fi ;;
      *)
        die "unknown format '$f' (use pdf, docx, html)" ;;
    esac
  done
}

# --- main -------------------------------------------------------------------

if [[ "$SAMPLES" -eq 1 ]]; then
  for t in templates/*/; do
    for lang in pt en; do
      d="documents/$(basename "$t")-$lang"
      [[ -d "$d" ]] && render_doc "$d"
    done
  done
else
  [[ -n "$DOC_DIR" ]] || usage
  render_doc "$DOC_DIR"
fi

echo "=== done: $RENDERED format(s) rendered, $SKIPPED skipped ==="
[[ "$RENDERED" -gt 0 ]] || die "nothing rendered"
