#!/usr/bin/env bash
# build.sh — Interactive format selection menu for Huawei Cloud Document Builder
#
# Usage:
#   ./scripts/build.sh                           # interactive, current directory
#   ./scripts/build.sh documents/guide-en         # interactive, specified project
#   ./scripts/build.sh --pdf documents/guide-en   # non-interactive: PDF only
#   ./scripts/build.sh --pdf --docx documents/guide-en
#   ./scripts/build.sh --all documents/guide-en

set -euo pipefail

# ── Resolve repo root (parent of scripts/ directory) ──────────────────────
REPO_ROOT="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"

# ── Template detection ─────────────────────────────────────────────────────
TEMPLATE=""  # set by --template flag or auto-detected

# ── Parse arguments (first pass: extract --template) ──────────────────────
_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --template)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --template requires an argument (template name, e.g. guide, technical)" >&2
                exit 1
            fi
            TEMPLATE="$2"; shift 2
            ;;
        --template=*)
            TEMPLATE="${1#--template=}"; shift
            ;;
        *)
            _ARGS+=("$1"); shift
            ;;
    esac
done
set -- "${_ARGS[@]}"

# ── Pandoc resource paths (relative to repo root) ────────────────────────
# Auto-detect template from .latexmkrc if not specified via --template
if [ -z "$TEMPLATE" ]; then
    # Will be resolved after PROJECT_DIR is known (see below)
    _DETECT_TEMPLATE=true
else
    _DETECT_TEMPLATE=false
fi

# Placeholder paths — will be finalized after template is resolved
REF_DOCX=""
HTML_TMPL=""

# ── Color support ─────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput &>/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN=''
    RED=''
    BOLD=''
    RESET=''
fi

# ── Flags ─────────────────────────────────────────────────────────────────
FLAG_PDF=false
FLAG_DOCX=false
FLAG_MD=false
FLAG_HTML=false
DRY_RUN=0
PROJECT_DIR=""

# ── Parse arguments ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pdf)     FLAG_PDF=true;  shift ;;
        --docx)    FLAG_DOCX=true; shift ;;
        --md)      FLAG_MD=true;   shift ;;
        --html)    FLAG_HTML=true; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --all)     FLAG_PDF=true; FLAG_DOCX=true; FLAG_MD=true; FLAG_HTML=true; shift ;;
        -h|--help)
            cat <<'EOF'
Usage: ./scripts/build.sh [OPTIONS] [PROJECT-DIR]

Options:
  --pdf       Generate PDF only
  --docx      Generate DOCX only
  --md        Generate Markdown only
  --html      Generate HTML only
  --all       Generate all formats
  --dry-run   Show what would be built without building
  --template T  Use template T (auto-detected from .latexmkrc if omitted)
  -h, --help  Show this help message

Examples:
  ./scripts/build.sh                           # interactive, current dir
  ./scripts/build.sh documents/guide-en         # interactive, specified project
  ./scripts/build.sh --pdf documents/guide-en   # PDF only
  ./scripts/build.sh --all documents/guide-en   # all formats
EOF
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            exit 1
            ;;
        *)
            PROJECT_DIR="$1"; shift ;;
    esac
done

# Default project directory
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="."
fi

# Resolve to absolute path
orig_dir="$PROJECT_DIR"
PROJECT_DIR="$(realpath "$PROJECT_DIR" 2>/dev/null)" || {
    echo "Error: Project directory does not exist: $orig_dir" >&2
    exit 1
}

# ── Source directory (src/ subfolder) ───────────────────────────────────
SRC_DIR="$PROJECT_DIR/src"
if [ ! -d "$SRC_DIR" ]; then
    SRC_DIR="$PROJECT_DIR"  # fallback for non-restructured projects
fi

# ── Auto-detect source file (.adoc preferred, .tex fallback) ────────────
ADOC_FILE=""
TEX_FILE=""

# Derive document name from project directory basename (for non-main.adoc files)
DOC_NAME="$(basename "$PROJECT_DIR")"

# Detect .adoc source
if [[ -f "$SRC_DIR/main.adoc" ]]; then
    ADOC_FILE="$SRC_DIR/main.adoc"
elif [[ -f "$SRC_DIR/${DOC_NAME}.adoc" ]]; then
    ADOC_FILE="$SRC_DIR/${DOC_NAME}.adoc"
fi

# Detect .tex source (fallback for legacy projects)
if [[ -f "$SRC_DIR/main.tex" ]]; then
    TEX_FILE="$SRC_DIR/main.tex"
elif [[ -f "$SRC_DIR/${DOC_NAME}.tex" ]]; then
    TEX_FILE="$SRC_DIR/${DOC_NAME}.tex"
fi

if [[ -z "$ADOC_FILE" && -z "$TEX_FILE" ]]; then
    echo "Error: No .adoc or .tex file found in $SRC_DIR" >&2
    exit 1
fi

# Determine basename from whichever source is available
if [[ -n "$ADOC_FILE" ]]; then
    BASENAME="$(basename "${ADOC_FILE%.adoc}")"
else
    BASENAME="$(basename "${TEX_FILE%.tex}")"
fi

# Relative path from project dir to .tex file (for pandoc resource resolution)
if [ "$SRC_DIR" = "$PROJECT_DIR" ]; then
    TEX_REL="${BASENAME}.tex"
else
    TEX_REL="src/${BASENAME}.tex"
fi

# ── Auto-detect template from .latexmkrc if not specified ────────────────
if [ "$_DETECT_TEMPLATE" = true ]; then
    # Look for .latexmkrc in src/ or project root
    _LMKRC=""
    if [ -f "$SRC_DIR/.latexmkrc" ]; then
        _LMKRC="$SRC_DIR/.latexmkrc"
    elif [ -f "$PROJECT_DIR/.latexmkrc" ]; then
        _LMKRC="$PROJECT_DIR/.latexmkrc"
    fi
    if [ -n "$_LMKRC" ]; then
        # Extract template name from TEXINPUTS path in .latexmkrc
        # The .latexmkrc contains: $ENV{TEXINPUTS} = "...:templates/<name>/:templates/_base/:..."
        TEMPLATE=$(grep -oP 'templates/\K[^/]+(?=/)' "$_LMKRC" 2>/dev/null | grep -v '^_base$' | head -1)
        if [ -z "$TEMPLATE" ]; then
            TEMPLATE="guide"  # default fallback
        fi
    else
        TEMPLATE="guide"  # default fallback
    fi
fi

# Validate template exists
if [ ! -f "${REPO_ROOT}/templates/${TEMPLATE}/${TEMPLATE}.cls" ]; then
    echo "Error: Template '$TEMPLATE' not found (templates/${TEMPLATE}/${TEMPLATE}.cls does not exist)" >&2
    exit 1
fi

# Finalize template paths
REF_DOCX="${REPO_ROOT}/templates/${TEMPLATE}/${TEMPLATE}-reference.docx"
HTML_TMPL="${REPO_ROOT}/templates/${TEMPLATE}/${TEMPLATE}-template.html"

# Display path relative to repo root for readability
REL_DIR="$(realpath --relative-to="$REPO_ROOT" "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")"

# ── Check dependencies ───────────────────────────────────────────────────
check_deps() {
    local missing=false
    if ! command -v latexmk &>/dev/null; then
        echo "Error: latexmk is not installed." >&2
        echo "  Install: sudo apt install latexmk  (or equivalent for your OS)" >&2
        missing=true
    fi
    if ! command -v xelatex &>/dev/null; then
        echo "Error: xelatex is not installed." >&2
        echo "  Install: sudo apt install texlive-xetex  (or equivalent for your OS)" >&2
        missing=true
    fi
    if [ "$FLAG_DOCX" = true ] || [ "$FLAG_MD" = true ] || [ "$FLAG_HTML" = true ]; then
        if ! command -v pandoc &>/dev/null; then
            echo "Error: pandoc is not installed." >&2
            echo "  Install: sudo apt install pandoc  (or https://pandoc.org/installing.html)" >&2
            missing=true
        fi
    fi
    if [ "$missing" = true ]; then
        exit 1
    fi
}

# ── Interactive menu ─────────────────────────────────────────────────────
interactive_menu() {
    local -a opts=("PDF      (via XeLaTeX + latexmk)" "DOCX     (via Pandoc)" "Markdown (via Pandoc)" "HTML     (via Pandoc)" "All formats")
    echo ""
    echo "========================================"
    echo "Huawei Cloud Document Builder"
    echo "========================================"
    echo "Project: ${REL_DIR}"
    echo "Source:  ${ADOC_FILE:-$TEX_FILE}"
    echo ""
    echo "Select output formats (enter numbers separated by spaces, or 'all'):"
    echo ""
    for i in "${!opts[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${opts[$i]}"
    done
    echo ""

    while true; do
        printf "Enter choice: "
        read -r choice
        choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]' | xargs)"

        if [ -z "$choice" ]; then echo "Please enter a selection."; continue; fi

        # Handle 'all' keyword or option 5
        if [ "$choice" = "all" ] || [ "$choice" = "5" ]; then
            FLAG_PDF=true; FLAG_DOCX=true; FLAG_MD=true; FLAG_HTML=true; break
        fi

        valid=true
        for token in $choice; do
            case "$token" in
                1) FLAG_PDF=true  ;;
                2) FLAG_DOCX=true ;;
                3) FLAG_MD=true   ;;
                4) FLAG_HTML=true ;;
                *) echo "Invalid selection: '$token'. Enter numbers 1-5 or 'all'."; valid=false; break ;;
            esac
        done

        if [ "$valid" = true ]; then
            if [ "$FLAG_PDF" = false ] && [ "$FLAG_DOCX" = false ] && \
               [ "$FLAG_MD" = false ] && [ "$FLAG_HTML" = false ]; then
                echo "No format selected. Please try again."; continue
            fi
            break
        fi
    done
}

# ── Generation functions ─────────────────────────────────────────────────
# Results arrays
declare -a RESULTS_OK=()
declare -a RESULTS_FAIL=()

generate_pdf() {
    local out="${BASENAME}.pdf"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  Would generate PDF: ${REL_DIR}/$out"
        RESULTS_OK+=("PDF:$out (dry-run)")
        return
    fi
    echo "  Generating PDF..."
    # Convert .adoc -> .tex if AsciiDoc source exists
    if [[ -n "$ADOC_FILE" ]]; then
        echo "  Converting ${ADOC_FILE} -> ${SRC_DIR}/${BASENAME}.tex"
        "$REPO_ROOT/scripts/build-adoc.sh" "$ADOC_FILE" -o "$SRC_DIR/${BASENAME}.tex" || {
            RESULTS_FAIL+=("PDF:build-adoc.sh failed")
            return
        }
        TEX_FILE="$SRC_DIR/${BASENAME}.tex"
    fi
    local rc=0
    (cd "$SRC_DIR" && latexmk "${BASENAME}.tex") 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        RESULTS_OK+=("PDF:$out")
        # Check for font fallback warnings
        local logfile="${SRC_DIR}/${BASENAME}.log"
        if [ -f "$logfile" ]; then
            if grep -q "PackageWarning.*Font.*not found" "$logfile" 2>/dev/null || \
               grep -q "falling back to" "$logfile" 2>/dev/null; then
                echo "  ⚠ Warning: PDF built with fallback fonts (brand fonts not found)"
            fi
        fi
    else
        RESULTS_FAIL+=("PDF:latexmk failed")
        # Show last 20 lines of log on failure
        local logfile="${SRC_DIR}/${BASENAME}.log"
        if [ -f "$logfile" ]; then
            echo "  ┌─ Last 20 lines of ${BASENAME}.log:"
            tail -20 "$logfile" | sed 's/^/  │ /'
            echo "  └─"
        fi
    fi
}

generate_pandoc_format() {
    # Legacy .tex-only pipeline (backward compatibility)
    local label=$1 fmt=$2 ext=$3; shift 3
    local extra_args=("$@")
    local out="${BASENAME}.${ext}"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  Would generate ${label}: ${REL_DIR}/$out"
        RESULTS_OK+=("${label}:$out (dry-run)")
        return
    fi
    echo "  Generating ${label} (from .tex)..."
    local err
    err=$(cd "$PROJECT_DIR" && export TZ="${TZ:-America/Sao_Paulo}" && pandoc -f latex+raw_tex \
        --resource-path=".:${REPO_ROOT}/templates/${TEMPLATE}:${REPO_ROOT}/templates/${TEMPLATE}/common-assets" \
        --number-sections \
        "${extra_args[@]}" \
        -t "$fmt" "$TEX_REL" -o "$out" 2>&1) || {
        RESULTS_FAIL+=("$label:pandoc failed")
        echo "  ┌─ pandoc error output:"
        echo "$err" | tail -20 | sed 's/^/  │ /'
        echo "  └─"
        return
    }
    echo "$err"
    local size=""
    local output="${PROJECT_DIR}/${BASENAME}.${ext}"
    if [ -f "$output" ]; then
        size="$(du -k "$output" 2>/dev/null | cut -f1)"
    fi
    if [ -n "$size" ]; then
        RESULTS_OK+=("${label}:${REL_DIR}/${BASENAME}.${ext} (${size} KB)")
    else
        RESULTS_OK+=("${label}:${REL_DIR}/${BASENAME}.${ext}")
    fi
}

generate_docx() {
    local out="${BASENAME}.docx"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  Would generate DOCX: ${REL_DIR}/$out"
        RESULTS_OK+=("DOCX:$out (dry-run)")
        return
    fi
    echo "  Generating DOCX..."
    if [[ -n "$ADOC_FILE" ]]; then
        # Pre-process .adoc for DOCX (convert passthrough blocks + custom roles)
        # Only for templates that have a pre-processor (poc, testbook)
        local tmp_adoc=""
        local docx_adoc="$ADOC_FILE"
        if [[ "$TEMPLATE" == "poc" || "$TEMPLATE" == "testbook" ]]; then
            tmp_adoc=$(mktemp --suffix=.adoc)
            if python3 "${REPO_ROOT}/templates/_base/adoc_docx_preprocessor.py" \
              --template "$TEMPLATE" "$ADOC_FILE" -o "$tmp_adoc" 2>/dev/null; then
                docx_adoc="$tmp_adoc"
            else
                echo "  ↳ DOCX pre-processing failed, using original .adoc"
                rm -f "$tmp_adoc"
                tmp_adoc=""
            fi
        fi
        # AsciiDoc pipeline: asciidoctor -b docbook -> pandoc
        # Falls back to LaTeX pipeline if docbook fails (e.g. passthrough blocks with raw LaTeX)
        local tmp_dbk
        tmp_dbk=$(mktemp --suffix=.dbk)
        if asciidoctor -b docbook "$docx_adoc" -o "$tmp_dbk" 2>/dev/null && \
           pandoc -f docbook --reference-doc="$REF_DOCX" \
             --number-sections \
             --resource-path="${PROJECT_DIR}:${REPO_ROOT}/templates/${TEMPLATE}/common-assets" \
             "$tmp_dbk" -o "${PROJECT_DIR}/$out" 2>/dev/null; then
            rm -f "$tmp_dbk"
        else
            rm -f "$tmp_dbk"
            echo "  ↳ Docbook pipeline failed, falling back to LaTeX pipeline..."
            generate_pandoc_format "DOCX" docx docx --reference-doc="$REF_DOCX"
        fi
        rm -f "$tmp_adoc"
    else
        # Legacy .tex pipeline
        generate_pandoc_format "DOCX" docx docx --reference-doc="$REF_DOCX"
    fi
    # Post-process: fix heading styles (pandoc overrides reference doc styles)
    if [ -f "${PROJECT_DIR}/$out" ]; then
        if ! python3 "${REPO_ROOT}/templates/${TEMPLATE}/create-${TEMPLATE}-reference-docx.py" --fix "${PROJECT_DIR}/$out" 2>&1; then
            echo "  ⚠ Warning: DOCX post-processing failed (heading styles may not match PDF)" >&2
            RESULTS_FAIL+=("DOCX:post-processing failed for $TEMPLATE")
        fi
    fi
    local size=""
    if [ -f "${PROJECT_DIR}/$out" ]; then
        size="$(du -k "${PROJECT_DIR}/$out" 2>/dev/null | cut -f1)"
    fi
    if [ -n "$size" ]; then
        RESULTS_OK+=("DOCX:${REL_DIR}/$out (${size} KB)")
    else
        RESULTS_OK+=("DOCX:${REL_DIR}/$out")
    fi
}

generate_md() {
    local out="${BASENAME}.md"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  Would generate Markdown: ${REL_DIR}/$out"
        RESULTS_OK+=("Markdown:$out (dry-run)")
        return
    fi
    echo "  Generating Markdown..."
    if [[ -n "$ADOC_FILE" ]]; then
        # AsciiDoc pipeline: asciidoctor -b docbook -> pandoc
        # Falls back to LaTeX pipeline if docbook fails (e.g. passthrough blocks with raw LaTeX)
        local tmp_dbk
        tmp_dbk=$(mktemp --suffix=.dbk)
        if asciidoctor -b docbook "$ADOC_FILE" -o "$tmp_dbk" 2>/dev/null && \
           pandoc -f docbook -t gfm "$tmp_dbk" -o "${PROJECT_DIR}/$out" 2>/dev/null; then
            rm -f "$tmp_dbk"
        else
            rm -f "$tmp_dbk"
            echo "  ↳ Docbook pipeline failed, falling back to LaTeX pipeline..."
            generate_pandoc_format "Markdown" markdown md
        fi
    else
        # Legacy .tex pipeline
        generate_pandoc_format "Markdown" markdown md
    fi
    # Post-process: embed images as base64 data URIs (self-contained MD)
    if [ -f "${PROJECT_DIR}/$out" ]; then
        python3 "${REPO_ROOT}/templates/_base/embed-images.py" \
            "${PROJECT_DIR}/$out" \
            --resource-path="${PROJECT_DIR}:${REPO_ROOT}/templates/${TEMPLATE}/common-assets" 2>&1 | sed 's/^/  /'
    fi
    local size=""
    if [ -f "${PROJECT_DIR}/$out" ]; then
        size="$(du -k "${PROJECT_DIR}/$out" 2>/dev/null | cut -f1)"
    fi
    if [ -n "$size" ]; then
        RESULTS_OK+=("Markdown:${REL_DIR}/$out (${size} KB)")
    else
        RESULTS_OK+=("Markdown:${REL_DIR}/$out")
    fi
}

generate_html() {
    local out="${BASENAME}.html"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  Would generate HTML: ${REL_DIR}/$out"
        RESULTS_OK+=("HTML:$out (dry-run)")
        return
    fi
    echo "  Generating HTML..."
    if [[ -n "$ADOC_FILE" ]]; then
        # AsciiDoc pipeline: asciidoctor directly
        asciidoctor -b html5 \
            -a stylesheet="$REPO_ROOT/templates/_base/huawei.css" \
            -a docinfodir="$REPO_ROOT/templates/_base" \
            -a docinfo1 \
            -r asciidoctor-diagram \
            "$ADOC_FILE" -o "${PROJECT_DIR}/$out" 2>&1 || {
            RESULTS_FAIL+=("HTML:asciidoctor failed")
            return
        }
    else
        # Legacy .tex pipeline
        generate_pandoc_format "HTML" html5 html --template="$HTML_TMPL" -s --embed-resources
    fi
    local size=""
    if [ -f "${PROJECT_DIR}/$out" ]; then
        size="$(du -k "${PROJECT_DIR}/$out" 2>/dev/null | cut -f1)"
    fi
    if [ -n "$size" ]; then
        RESULTS_OK+=("HTML:${REL_DIR}/$out (${size} KB)")
    else
        RESULTS_OK+=("HTML:${REL_DIR}/$out")
    fi
}

# ── Summary ──────────────────────────────────────────────────────────────
show_summary() {
    echo ""
    echo "========================================"
    echo "Generation Complete"
    echo "========================================"

    for entry in "${RESULTS_OK[@]}"; do
        local label="${entry%%:*}" detail="${entry#*:}"
        printf "${GREEN}✓${RESET} %-9s %s\n" "$label:" "$detail"
    done

    for entry in "${RESULTS_FAIL[@]}"; do
        local label="${entry%%:*}" detail="${entry#*:}"
        printf "${RED}✗${RESET} %-9s %s\n" "$label:" "$detail"
    done

    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────

# If no format flags set, go interactive
if [ "$FLAG_PDF" = false ] && [ "$FLAG_DOCX" = false ] && [ "$FLAG_MD" = false ] && [ "$FLAG_HTML" = false ]; then
    interactive_menu
fi

# Check dependencies for selected formats
check_deps

# Generate selected formats (Pandoc formats run sequentially — ~0.7s total, parallelization not worth the complexity)
if [ "$FLAG_PDF"   = true ]; then generate_pdf;   fi
if [ "$FLAG_DOCX"  = true ]; then generate_docx;  fi
if [ "$FLAG_MD"    = true ]; then generate_md;    fi
if [ "$FLAG_HTML"  = true ]; then generate_html;  fi

# Show summary
show_summary

# Exit with error if any format failed
if [ ${#RESULTS_FAIL[@]} -gt 0 ]; then
    exit 1
fi
exit 0
