#!/usr/bin/env bash
# build.sh — Interactive format selection menu for Huawei Cloud Document Builder
#
# Usage:
#   ./build.sh                           # interactive, current directory
#   ./build.sh examples/guide/en         # interactive, specified project
#   ./build.sh --pdf examples/guide/en   # non-interactive: PDF only
#   ./build.sh --pdf --docx examples/guide/en
#   ./build.sh --all examples/guide/en

set -euo pipefail

# ── Resolve repo root (where this script lives) ──────────────────────────
REPO_ROOT="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

# ── Pandoc resource paths (relative to repo root) ────────────────────────
LUA_FILTER="${REPO_ROOT}/templates/guide/guide-pandoc.lua"
REF_DOCX="${REPO_ROOT}/templates/guide/guide-reference.docx"
HTML_TMPL="${REPO_ROOT}/templates/guide/guide-template.html"

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
            echo "Usage: ./build.sh [OPTIONS] [PROJECT-DIR]"
            echo ""
            echo "Options:"
            echo "  --pdf       Generate PDF only"
            echo "  --docx      Generate DOCX only"
            echo "  --md        Generate Markdown only"
            echo "  --html      Generate HTML only"
            echo "  --all       Generate all formats"
            echo "  --dry-run   Show what would be built without building"
            echo "  -h, --help  Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build.sh                           # interactive, current dir"
            echo "  ./build.sh examples/guide/en         # interactive, specified project"
            echo "  ./build.sh --pdf examples/guide/en   # PDF only"
            echo "  ./build.sh --all examples/guide/en   # all formats"
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

# ── Validate project directory ───────────────────────────────────────────
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

# ── Source directory (src/ subfolder) ───────────────────────────────────
SRC_DIR="$PROJECT_DIR/src"
if [ ! -d "$SRC_DIR" ]; then
    SRC_DIR="$PROJECT_DIR"  # fallback for non-restructured projects
fi

# ── Auto-detect .tex file ────────────────────────────────────────────────
TEX_FILE=""
TEX_COUNT=0
for f in "$SRC_DIR"/*.tex; do
    [ -f "$f" ] || continue
    TEX_COUNT=$((TEX_COUNT + 1))
done

if [ "$TEX_COUNT" -eq 0 ]; then
    echo "Error: No .tex file found in $SRC_DIR" >&2
    exit 1
elif [ "$TEX_COUNT" -eq 1 ]; then
    TEX_FILE="$(basename "$SRC_DIR"/*.tex)"
else
    # Multiple .tex files — prefer main.tex, then setup-guide.tex
    if [ -f "$SRC_DIR/main.tex" ]; then
        TEX_FILE="main.tex"
    elif [ -f "$SRC_DIR/setup-guide.tex" ]; then
        TEX_FILE="setup-guide.tex"
    else
        echo "Error: Multiple .tex files found in $SRC_DIR and no main.tex or setup-guide.tex" >&2
        echo "Please specify the file manually." >&2
        exit 1
    fi
fi

BASENAME="${TEX_FILE%.tex}"

# Relative path from project dir to .tex file (for pandoc resource resolution)
if [ "$SRC_DIR" = "$PROJECT_DIR" ]; then
    TEX_REL="$TEX_FILE"
else
    TEX_REL="src/$TEX_FILE"
fi

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
    echo ""
    echo "========================================"
    echo "Huawei Cloud Document Builder"
    echo "========================================"
    echo "Project: ${REL_DIR}"
    echo "Source:  ${TEX_FILE}"
    echo ""
    echo "Select output formats (enter numbers separated by spaces, or 'all'):"
    echo ""
    echo "  1) PDF      (via XeLaTeX + latexmk)"
    echo "  2) DOCX     (via Pandoc)"
    echo "  3) Markdown (via Pandoc)"
    echo "  4) HTML     (via Pandoc)"
    echo "  5) All formats"
    echo ""

    while true; do
        printf "Enter choice: "
        read -r choice

        # Normalize input
        choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]' | xargs)"

        if [ -z "$choice" ]; then
            echo "Please enter a selection."
            continue
        fi

        # Handle 'all' keyword
        if [ "$choice" = "all" ]; then
            FLAG_PDF=true
            FLAG_DOCX=true
            FLAG_MD=true
            FLAG_HTML=true
            break
        fi

        # Parse numbers
        valid=true
        for token in $choice; do
            case "$token" in
                1) FLAG_PDF=true  ;;
                2) FLAG_DOCX=true ;;
                3) FLAG_MD=true   ;;
                4) FLAG_HTML=true ;;
                5)
                    FLAG_PDF=true
                    FLAG_DOCX=true
                    FLAG_MD=true
                    FLAG_HTML=true
                    ;;
                *)
                    echo "Invalid selection: '$token'. Enter numbers 1-5 or 'all'."
                    valid=false
                    break
                    ;;
            esac
        done

        if [ "$valid" = true ]; then
            # Ensure at least one format selected
            if [ "$FLAG_PDF" = false ] && [ "$FLAG_DOCX" = false ] && \
               [ "$FLAG_MD" = false ] && [ "$FLAG_HTML" = false ]; then
                echo "No format selected. Please try again."
                continue
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
    local rc=0
    (cd "$SRC_DIR" && latexmk "$TEX_FILE") 2>&1 || rc=$?
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
    local label=$1 fmt=$2 ext=$3; shift 3
    local extra_args=("$@")
    local out="${BASENAME}.${ext}"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  Would generate ${label}: ${REL_DIR}/$out"
        RESULTS_OK+=("${label}:$out (dry-run)")
        return
    fi
    echo "  Generating ${label}..."
    local err
    err=$(cd "$PROJECT_DIR" && pandoc -f latex+raw_tex \
        --lua-filter="$LUA_FILTER" \
        --resource-path=".:${REPO_ROOT}/templates/guide/common-assets" \
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
    generate_pandoc_format "DOCX" docx docx --reference-doc="$REF_DOCX"
    # Post-process: fix heading styles (pandoc overrides reference doc styles)
    if [ "$DRY_RUN" -eq 0 ] && [ -f "${PROJECT_DIR}/${BASENAME}.docx" ]; then
        if ! python3 "${REPO_ROOT}/templates/guide/create-reference-docx.py" --fix "${PROJECT_DIR}/${BASENAME}.docx" 2>&1; then
            echo "  ⚠ Warning: DOCX post-processing failed (heading styles may not match PDF)" >&2
        fi
    fi
}
generate_md() {
    generate_pandoc_format "Markdown" markdown md
    # Post-process: embed images as base64 data URIs (self-contained MD)
    if [ "$DRY_RUN" -eq 0 ] && [ -f "${PROJECT_DIR}/${BASENAME}.md" ]; then
        python3 "${REPO_ROOT}/templates/guide/embed-images.py" \
            "${PROJECT_DIR}/${BASENAME}.md" \
            --resource-path="${PROJECT_DIR}:${REPO_ROOT}/templates/guide/common-assets" 2>&1 | sed 's/^/  /'
    fi
}
generate_html() { generate_pandoc_format "HTML" html5 html --template="$HTML_TMPL" -s --embed-resources; }

# ── Summary ──────────────────────────────────────────────────────────────
show_summary() {
    echo ""
    echo "========================================"
    echo "Generation Complete"
    echo "========================================"

    pad_label() {
        case "$1" in
            PDF)      echo "PDF:     " ;;
            DOCX)     echo "DOCX:    " ;;
            Markdown) echo "Markdown:" ;;
            HTML)     echo "HTML:    " ;;
            *)        echo "${1}: " ;;
        esac
    }

    for entry in "${RESULTS_OK[@]}"; do
        local label="${entry%%:*}"
        local detail="${entry#*:}"
        printf "${GREEN}✓${RESET} %s %s\n" "$(pad_label "$label")" "$detail"
    done

    for entry in "${RESULTS_FAIL[@]}"; do
        local label="${entry%%:*}"
        local detail="${entry#*:}"
        printf "${RED}✗${RESET} %s %s\n" "$(pad_label "$label")" "$detail"
    done

    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────

# If no format flags set, go interactive
if [ "$FLAG_PDF" = false ] && [ "$FLAG_DOCX" = false ] && \
   [ "$FLAG_MD" = false ] && [ "$FLAG_HTML" = false ]; then
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
