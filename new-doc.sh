#!/usr/bin/env bash
# ─── new-doc.sh — Create a new Huawei Cloud document ─────────────────────────
#
# Description:   Interactive (or flag-driven) scaffolder that lets you choose
#                a template (guide / technical / ppt) and creates a
#                self-contained project folder under documents/<name>/.
#
# Usage:
#   ./new-doc.sh                                  # interactive
#   ./new-doc.sh --yes                            # non-interactive, all defaults
#   ./new-doc.sh --type guide --title "ECS Setup" --lang en --name ecs-setup
#   ./new-doc.sh --type technical --title "ECS Report" --lang pt --yes
#   ./new-doc.sh --list                           # list available templates
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCUMENTS_DIR="$SCRIPT_DIR/documents"

# ── Colors (TTY-aware) ──
if [ -t 1 ]; then
  C_RESET="\033[0m"  C_BOLD="\033[1m"  C_DIM="\033[2m"
  C_RED="\033[31m"   C_GREEN="\033[32m" C_YELLOW="\033[33m"
  C_CYAN="\033[36m"
else
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_CYAN=""
fi

log_step()  { echo -e "\n${C_BOLD}${C_CYAN}── $1 ──${C_RESET}"; }
log_ok()    { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_warn()  { echo -e "  ${C_YELLOW}⚠${C_RESET}  $1"; }
log_error() { echo -e "  ${C_RED}✗${C_RESET} $1"; }
log_dim()   { echo -e "    ${C_DIM}$1${C_RESET}"; }

# ── Defaults ──
TYPE=""
TITLE=""
LANG=""
NAME=""
AUTO_YES=false

# ── Parse arguments ──
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)    TYPE="$2"; shift 2 ;;
        --title)   TITLE="$2"; shift 2 ;;
        --lang)    LANG="$2"; shift 2 ;;
        --name)    NAME="$2"; shift 2 ;;
        --yes|-y)  AUTO_YES=true; shift ;;
        --list)    echo "Available templates:"; echo "  guide     — LaTeX guide (PDF)"; echo "  technical — technical report (DOCX)"; echo "  ppt       — slide deck (PPTX)"; exit 0 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "Unknown argument: $1 (see --help)"; exit 1 ;;
    esac
done

# ── Banner ──
echo ""
echo -e "  ${C_BOLD}${C_CYAN}Huawei Document Templates — new document${C_RESET}"
echo ""

# ── Validate documents/ dir ──
mkdir -p "$DOCUMENTS_DIR"

# ── Choose template type ──
if [[ -z "$TYPE" ]]; then
    if [[ "$AUTO_YES" == true ]]; then
        TYPE="guide"
    else
        echo -e "  ${C_BOLD}Which template?${C_RESET}"
        echo -e "    ${C_DIM}1) guide     — LaTeX guide (PDF, training/how-to)${C_RESET}"
        echo -e "    ${C_DIM}2) technical — technical report (DOCX, incident/analysis)${C_RESET}"
        echo -e "    ${C_DIM}3) ppt       — slide deck (PPTX, presentation)${C_RESET}"
        echo ""
        read -rp "  Choice [1-3, default 1]: " choice
        case "${choice:-1}" in
            1|"") TYPE="guide" ;;
            2)    TYPE="technical" ;;
            3)    TYPE="ppt" ;;
            *)    log_error "Invalid choice"; exit 1 ;;
        esac
    fi
fi

case "$TYPE" in
    guide|technical|ppt) ;;
    *) log_error "Unknown type '$TYPE' (use: guide, technical, ppt)"; exit 1 ;;
esac

# ── Title ──
if [[ -z "$TITLE" ]]; then
    if [[ "$AUTO_YES" == true ]]; then
        TITLE="Untitled Document"
    else
        read -rp "  Title: " TITLE
        TITLE="${TITLE:-Untitled Document}"
    fi
fi

# ── Language ──
if [[ -z "$LANG" ]]; then
    if [[ "$AUTO_YES" == true ]]; then
        LANG="en"
    else
        read -rp "  Language [en/pt, default en]: " LANG
        LANG="${LANG:-en}"
    fi
fi
case "$LANG" in
    en|pt) ;;
    *) log_error "Unknown language '$LANG' (use: en or pt)"; exit 1 ;;
esac

# ── Project name (folder) ──
if [[ -z "$NAME" ]]; then
    # Derive a slug from the title
    NAME="$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')"
    NAME="${NAME:-untitled}"
    if [[ "$AUTO_YES" != true ]]; then
        read -rp "  Project folder name [default: $NAME]: " custom_name
        NAME="${custom_name:-$NAME}"
    fi
fi

PROJECT_DIR="$DOCUMENTS_DIR/$NAME"

# ── Check for existing folder ──
if [[ -d "$PROJECT_DIR" ]]; then
    log_error "Folder already exists: documents/$NAME"
    log_dim "Choose a different name with --name, or remove the existing folder."
    exit 1
fi

log_step "Creating documents/$NAME ($TYPE, $LANG)"

mkdir -p "$PROJECT_DIR/assets"
touch "$PROJECT_DIR/assets/.gitkeep"

# ── Scaffold based on type ──
scaffold_guide() {
    local cls_opt=""
    if [[ "$LANG" == "pt" ]]; then cls_opt="[portuguese]"; fi

    mkdir -p "$PROJECT_DIR/src"

    cat > "$PROJECT_DIR/src/.latexmkrc" <<'LATEXMKRC'
$ENV{TEXINPUTS} = "../../templates/_base/:../../templates/guide/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";  # default GMT-3 — override here if needed
$pdf_mode = 5;
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
$out_dir = '..';
LATEXMKRC

    cat > "$PROJECT_DIR/src/main.tex" <<TEX
\\documentclass${cls_opt}{guide}

\\setguidetitle{${TITLE}}
\\setheadertitle{Huawei Cloud -- ${TITLE}}
\\setcovertext{Huawei Technologies CO., LTD}
\\setdocversion{1.0.0}
\\setdocdate{\\today}

\\begin{document}
\\makecover
\\maketoc
\\startbody

\\section{Introduction}

\\begin{infobox}
  This is a new Huawei Cloud guide created with the \\texttt{guide} template.
  Replace this content with your own.
\\end{infobox}

\\subsection{Objective}

\\objective{Describe the objective of this guide.}

\\stepbystep
\\begin{enumerate}
  \\item First step.
  \\item Second step.
\\end{enumerate}

% --- Changelog (after all sections, before \\end{document}) ---
\\begin{changelog}
  \\changelogentry{1.0.0}{\\today}{
    \\item Initial version.
  }
\\end{changelog}

\\end{document}
TEX
    log_ok "Created src/main.tex, src/.latexmkrc, assets/"
    log_dim "Next: cd documents/$NAME/src && latexmk main.tex"
}

scaffold_technical() {
    local docstring="Generate a Huawei Cloud technical report."
    if [[ "$LANG" == "pt" ]]; then
        docstring="Gera um relatório técnico da Huawei Cloud."
    fi
    cat > "$PROJECT_DIR/generate.py" <<PY
#!/usr/bin/env python3
"""${docstring}"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', 'templates', 'technical'))
from huawei_technical import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    replacements = {
        'PROBLEM_DESCRIPTION': 'Describe the problem and its impact.',
        'ROOT_CAUSE_ANALYSIS': '1. First analysis step\\n2. Second step',
        'ROOT_CAUSE': 'The identified root cause.',
        'TRIGGER_CONDITION': 'When this condition is met, the issue occurs.',
        'IMPACT': 'Impact of applying the workaround.',
        'BACKUP_DATA': 'N/A — no data modification required.',
        'WORKAROUND': '1. Step one\\n2. Step two\\n3. Step three',
        'VERIFICATION': 'How to verify the fix worked.',
        'ROLLBACK': 'How to undo the workaround.',
        'CLEANUP': 'No cleanup required.',
        'VERSION': 'HCS 8.5.1',
        'SCENARIO': 'Standard Scenario',
    }

    doc = create_technical_report(replacements)
    path = save_report(doc, os.path.join(OUT_DIR, "report.docx"))
    print(f"Saved: {path}")

if __name__ == "__main__":
    main()
PY
    chmod +x "$PROJECT_DIR/generate.py"
    log_ok "Created generate.py, assets/"
    log_dim "Next: cd documents/$NAME && python3 generate.py"
}

scaffold_ppt() {
    local docstring="Huawei Cloud slide deck."
    if [[ "$LANG" == "pt" ]]; then
        docstring="Apresentação da Huawei Cloud."
    fi
    cat > "$PROJECT_DIR/generate.py" <<PY
#!/usr/bin/env python3
"""${docstring}"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', 'templates', 'ppt'))
from huawei_ppt import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    prs, layouts = new_deck()

    # Title slide
    title_slide(prs, layouts,
                "${TITLE}",
                "Subtitle goes here",
                "Author | ${LANG}")

    # Content slide
    s = content_slide(prs, layouts, "Overview")
    callout(s, 'infobox', "Replace this with your content.", top=2.0)

    # Last slide
    last_slide(prs, layouts)

    path = save_deck(prs, os.path.join(OUT_DIR, "deck.pptx"))
    print(f"Saved: {path}")

if __name__ == "__main__":
    main()
PY
    chmod +x "$PROJECT_DIR/generate.py"
    log_ok "Created generate.py, assets/"
    log_dim "Next: cd documents/$NAME && python3 generate.py"
}

case "$TYPE" in
    guide)     scaffold_guide ;;
    technical) scaffold_technical ;;
    ppt)       scaffold_ppt ;;
esac

# ── Summary ──
echo ""
echo -e "  ${C_BOLD}${C_GREEN}✓ Created documents/$NAME${C_RESET}"
echo ""
printf "    ${C_DIM}%-14s${C_RESET} %s\n" "Template:"  "$TYPE"
printf "    ${C_DIM}%-14s${C_RESET} %s\n" "Language:"  "$LANG"
printf "    ${C_DIM}%-14s${C_RESET} %s\n" "Title:"     "$TITLE"
printf "    ${C_DIM}%-14s${C_RESET} %s\n" "Location:"  "documents/$NAME/"
echo ""
