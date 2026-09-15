#!/usr/bin/env bash
# ─── install.sh — One-command setup for Huawei Document Templates ───────────
#
# Domain:        LaTeX document templates
# Description:   Installs XeLaTeX, LaTeX packages, latexmk, brand fonts
#                (HarmonyOS Sans + Cascadia Code), opencode skill, and
#                VS Code LaTeX Workshop (user-level). Tested on Ubuntu 22.04+
#
# Usage:
#   ./install.sh                # full install (idempotent — safe to re-run)
#   ./install.sh --yes          # non-interactive (skip confirmation prompt)
#   curl ... | bash             # auto-detects pipe: clones repo + installs non-interactively
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Parse arguments ──
AUTO_YES=false
DO_CLONE=false
for arg in "$@"; do
    case "$arg" in
        --yes|-y) AUTO_YES=true ;;
        --clone)  DO_CLONE=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Determine if running from pipe (curl | bash) or from a file ──
REPO_URL="https://github.com/wallacelw/huawei-doc-templates.git"
CLONE_DIR="/home/huawei-doc-templates"

# Helper: update an existing repo in place
update_repo() {
    local repo_path="$1"
    cd "$repo_path"
    SCRIPT_DIR="$(pwd)"
    local current_tag latest_tag new_tag
    current_tag=$(git describe --tags 2>/dev/null || echo "unknown")
    latest_tag=$(git ls-remote --tags --sort=-v:refname origin 2>/dev/null | head -1 | awk -F/ '{print $3}')
    [ -z "$latest_tag" ] && latest_tag="unknown"
    echo ""
    echo "  Existing installation found: $repo_path ($current_tag)"
    if [[ "$current_tag" == "$latest_tag" ]]; then
        echo "  Already up to date."
        if [ -c /dev/tty ] 2>/dev/null; then
            echo -ne "  Re-run install anyway? [y/N] "
            read -r response < /dev/tty
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                exit 0
            fi
        else
            exit 0
        fi
    else
        echo "  Latest version available: $latest_tag"
        if [ -c /dev/tty ] 2>/dev/null; then
            echo -ne "  Update $current_tag → $latest_tag? [Y/n] "
            read -r response < /dev/tty
            if [[ "$response" =~ ^[Nn]$ ]]; then
                echo "  Aborted."
                exit 0
            fi
        fi
        echo "  Pulling updates..."
        git pull --quiet
        new_tag=$(git describe --tags 2>/dev/null || echo "unknown")
        echo "  Updated: $current_tag → $new_tag"
    fi
}

if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    # Running from a file (./install.sh)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # If --clone flag, clone first
    if [[ "$DO_CLONE" == true ]]; then
        if [[ -d "$CLONE_DIR/.git" ]]; then
            echo "  $CLONE_DIR already exists — skipping clone"
        else
            git clone "$REPO_URL" "$CLONE_DIR"
        fi
        cd "$CLONE_DIR"
        SCRIPT_DIR="$(pwd)"
    fi
else
    # Running from pipe (curl | bash)
    AUTO_YES=true
    if [[ -d .git ]] && [[ -f scripts/install.sh ]]; then
        # Already inside the repo — update in place
        update_repo "$(pwd)"
    elif [[ -d "$CLONE_DIR/.git" ]]; then
        # Repo exists at default path — update it
        update_repo "$CLONE_DIR"
    else
        # Fresh install — clone to default path
        git clone "$REPO_URL" "$CLONE_DIR"
        cd "$CLONE_DIR"
        SCRIPT_DIR="$(pwd)"
    fi
fi

# ── Colors (TTY-aware) ──
if [ -t 1 ]; then
  C_RESET="\033[0m"  C_BOLD="\033[1m"  C_DIM="\033[2m"
  C_RED="\033[31m"   C_GREEN="\033[32m" C_YELLOW="\033[33m"
  C_BLUE="\033[34m"  C_CYAN="\033[36m"
else
  C_RESET="" C_BOLD="" C_DIM=""
  C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

# ── Logging helpers ──
log_step()  { echo -e "\n${C_BOLD}${C_CYAN}── $1 ──${C_RESET}"; }
log_desc()  { echo -e "  ${C_DIM}$1${C_RESET}"; }
log_info()  { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_ok()    { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_warn()  { echo -e "  ${C_YELLOW}⚠${C_RESET}  $1"; }
log_error() { echo -e "  ${C_RED}✗${C_RESET} $1"; }
log_done()  { echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}$1${C_RESET}"; }
log_dim()   { echo -e "    ${C_DIM}$1${C_RESET}"; }

# ── Banner ──
_banner_text="Huawei Document Templates — install.sh"
_banner_width=$(( ${#_banner_text} + 4 ))
_banner_border=$(printf '═%.0s' $(seq 1 $_banner_width))
echo ""
echo -e "${C_BOLD}${C_CYAN}╔${_banner_border}╗${C_RESET}"
echo -e "${C_BOLD}${C_CYAN}║  ${_banner_text}  ║${C_RESET}"
echo -e "${C_BOLD}${C_CYAN}╚${_banner_border}╝${C_RESET}"
echo ""

echo -e "  ${C_BOLD}What:${C_RESET}  AsciiDoc document templates for Huawei Cloud guides (XeLaTeX + latexmk, AsciiDoc + asciidoctor)"
echo ""
echo -e "  ${C_BOLD}Installs:${C_RESET}"
local -a installs=(
    "• XeLaTeX + latexmk + LaTeX packages"
    "• AsciiDoc + asciidoctor (source format + converter)"
    "• HarmonyOS Sans (body font, free commercial use)"
    "• Cascadia Code (code font, open source)"
    "• opencode skills (/skill huawei-template-guide, /skill huawei-template-technical, /skill huawei-template-testbook)"
    "• VS Code LaTeX Workshop (local + remote config)"
)
for line in "${installs[@]}"; do log_dim "$line"; done
echo ""
echo -e "  ${C_BOLD}Prerequisites:${C_RESET}"
local -a prereqs=(
    "• Ubuntu 22.04+ (WSL or native)     (required)"
    "• apt-get, sudo                      (required)"
    "• VS Code CLI (code)                 (optional — for extension install)"
)
for line in "${prereqs[@]}"; do log_dim "$line"; done
echo ""

# ── Confirmation ──
INSTALL_SKILLS=true
INSTALL_VSCODE=true

if [[ "$AUTO_YES" != true ]]; then
    echo -ne "  ${C_BOLD}Proceed with installation?${C_RESET} [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "  ${C_DIM}Aborted.${C_RESET}"
        exit 0
    fi
    # Optional components (default yes)
    echo -ne "  ${C_BOLD}Install opencode skills?${C_RESET} [Y/n] "
    read -r response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        INSTALL_SKILLS=false
    fi
    echo -ne "  ${C_BOLD}Configure VS Code LaTeX Workshop?${C_RESET} [Y/n] "
    read -r response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        INSTALL_VSCODE=false
    fi
fi

# ── Pre-flight checks ──
log_step "Pre-flight checks"

if [[ $EUID -eq 0 ]]; then
    log_warn "Running as root — sudo steps will be skipped."
    SUDO=""
else
    SUDO="sudo"
fi

if ! command -v apt-get &>/dev/null; then
    log_error "apt-get not found. This script targets Ubuntu/Debian."
    echo ""
    echo -e "  ${C_BOLD}For Fedora/RHEL, install manually:${C_RESET}"
    log_dim "sudo dnf install texlive-collection-xetex texlive-collection-latexextra \\"
    log_dim "                  texlive-collection-lang-portuguese latexmk \\"
    log_dim "                  liberation-sans-fonts"
    exit 1
fi
log_ok "apt-get detected"

# ── Install TeX Live packages ──
log_step "Installing TeX Live packages"
log_desc "xelatex, latexmk, texlive-latex-extra, texlive-lang-portuguese, fonts, poppler-utils"

$SUDO apt-get update -qq
log_dim "Installing packages..."
$SUDO apt-get install -y \
    texlive-xetex \
    texlive-latex-extra \
    texlive-lang-portuguese \
    latexmk \
    fonts-liberation \
    fonts-cascadia-code \
    poppler-utils \
    pandoc \
    graphviz \
    plantuml \
    python3-docx \
    ruby-full \
    2>&1 | grep -v "^$\|Reading\|Building\|Need to get\|After this\|Fetched\|Selecting\|Setting up\|Unpacking\|Preparing\|Processing\|update-alternatives\|man-db\|trigger\|qemu\|VM guests\|systemd\|already the newest\|automatically installed\|autoremove\|not upgraded\|newly installed\|upgraded" || true

log_done "TeX Live packages installed"

# ── Install asciidoctor (AsciiDoc processor) ──
log_step "Installing asciidoctor"

if command -v asciidoctor &>/dev/null; then
    log_ok "asciidoctor: already installed ($(asciidoctor --version 2>/dev/null | head -1))"
else
    log_desc "Installing asciidoctor Ruby gem..."
    gem install asciidoctor 2>&1 | grep -v "^$\|Fetching\|Successfully installed\|Parsing\|Installing\|Building" || true
    if command -v asciidoctor &>/dev/null; then
        log_done "asciidoctor: installed ($(asciidoctor --version 2>/dev/null | head -1))"
    else
        log_warn "Failed to install asciidoctor — AsciiDoc pipeline unavailable"
        log_dim "Install manually: gem install asciidoctor"
    fi
fi

# ── Update fvextra for backgroundcolor support ──
# fvextra >= 1.5 introduced the backgroundcolor option (TeX Live 2024+).
# TeX Live 2023 ships an older version without it, so we download from CTAN.
log_step "Updating fvextra (backgroundcolor support)"

FVEXTRA_STY=$(kpsewhich fvextra.sty 2>/dev/null)
if [[ -n "$FVEXTRA_STY" ]] && grep -q 'backgroundcolor' "$FVEXTRA_STY" 2>/dev/null; then
    log_ok "fvextra: already has backgroundcolor support"
else
    log_desc "Downloading and building latest fvextra from CTAN..."
    FVEXTRA_ZIP="/tmp/fvextra.zip"
    FVEXTRA_BUILD="/tmp/fvextra-build"
    if wget -q "https://mirrors.ctan.org/macros/latex/contrib/fvextra.zip" -O "$FVEXTRA_ZIP"; then
        rm -rf "$FVEXTRA_BUILD"
        unzip -q "$FVEXTRA_ZIP" -d "$FVEXTRA_BUILD"
        (
            cd "$FVEXTRA_BUILD/fvextra" || exit 1
            latex fvextra.ins >/dev/null 2>&1
            if [[ -f fvextra.sty ]] && grep -q 'backgroundcolor' fvextra.sty; then
                FVEXTRA_TARGET="${FVEXTRA_STY:-/usr/share/texlive/texmf-dist/tex/latex/fvextra/fvextra.sty}"
                $SUDO cp fvextra.sty "$FVEXTRA_TARGET"
                $SUDO texhash 2>/dev/null
                log_done "fvextra: updated with backgroundcolor support"
            else
                log_warn "fvextra build failed — code block backgrounds may show two colors"
            fi
        )
        rm -rf "$FVEXTRA_ZIP" "$FVEXTRA_BUILD"
    else
        log_warn "Failed to download fvextra — code block backgrounds may show two colors"
        log_dim "Download manually from: https://ctan.org/pkg/fvextra"
    fi
fi

# ── Install HarmonyOS Sans font ──
log_step "Installing HarmonyOS Sans font"

HARMONYOS_DEB_URL="https://github.com/zhiyuan1i/fonts-harmonyos-sans-cn/releases/download/v1.0.0/harmonyos_sans.deb"
HARMONYOS_DEB="/tmp/harmonyos_sans.deb"
HARMONYOS_DEB_SHA256="d1fdaccd6d8f7a8918db366430c586503480d6e0d44ace33715fb7d999537123"

if fc-list : family | grep -qi "HarmonyOS Sans"; then
    log_ok "HarmonyOS Sans: already installed"
else
    log_desc "Downloading from GitHub releases..."
    if wget -q "$HARMONYOS_DEB_URL" -O "$HARMONYOS_DEB"; then
        if echo "$HARMONYOS_DEB_SHA256  $HARMONYOS_DEB" | sha256sum -c - 2>/dev/null; then
            $SUDO apt install -y "$HARMONYOS_DEB" >/dev/null 2>&1
            rm -f "$HARMONYOS_DEB"
            log_done "HarmonyOS Sans: installed"
        else
            log_error "HarmonyOS Sans: checksum mismatch — possible tampered download"
            rm -f "$HARMONYOS_DEB"
        fi
    else
        log_warn "Failed to download HarmonyOS Sans — using fallback fonts"
        log_dim "Download manually from: $HARMONYOS_DEB_URL"
    fi
fi

# ── Update font cache ──
log_step "Updating font cache"
fc-cache -f || log_warn "fc-cache failed — font discovery may be incomplete"
log_ok "Font cache updated"

# ── Install shared LaTeX modules to TDS (texmf-local) ──
log_step "Installing Huawei shared modules (TDS)"

TEXMF_LOCAL=$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null)
HUAWEI_STY_DIR="$TEXMF_LOCAL/tex/latex/huawei"

if [[ -n "$TEXMF_LOCAL" ]] && [[ -d "$TEXMF_LOCAL" ]]; then
    $SUDO mkdir -p "$HUAWEI_STY_DIR"
    MODULE_COUNT=0
    for sty_file in "$SCRIPT_DIR"/templates/_base/huawei-*.sty; do
        if [[ -f "$sty_file" ]]; then
            $SUDO cp "$sty_file" "$HUAWEI_STY_DIR/"
            MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done
    $SUDO texhash 2>/dev/null
    log_done "Installed $MODULE_COUNT modules → $HUAWEI_STY_DIR"
else
    log_warn "TEXMFLOCAL not found — modules will be found via TEXINPUTS instead"
    log_dim "Documents still compile if .latexmkrc includes templates/_base/ in TEXINPUTS"
fi

# ── Verify toolchain ──
log_step "Verifying toolchain and fonts"

verify() {
    if command -v "$1" &>/dev/null; then
        log_ok "$1: $($1 --version 2>/dev/null | head -1)"
    else
        log_error "$1 not found after installation"
        return 1
    fi
}

verify xelatex
verify latexmk

log_step "Verifying asciidoctor"
if command -v asciidoctor &>/dev/null; then
    log_done "asciidoctor $(asciidoctor --version 2>/dev/null | head -1)"
else
    log_warn "asciidoctor not found — AsciiDoc pipeline unavailable (LaTeX still works)"
fi

log_step "Verifying pandoc"
if command -v pandoc &>/dev/null; then
    log_done "pandoc $(pandoc --version | head -1)"
else
    log_warn "pandoc not found — DOCX/MD/HTML output unavailable (PDF still works)"
fi

# Font checks
check_font() {
    if fc-list : family | grep -qi "$1"; then
        log_ok "$1: available ($2)"
    else
        log_warn "$1 not found — $2 will fall back to $3"
    fi
}

check_font "HarmonyOS Sans"    "body text (required)"      "Liberation Sans"
check_font "Liberation Sans"   "body fallback"             "(install fonts-liberation)"
check_font "Cascadia Code"     "code font (required)"      "DejaVu Sans Mono"
check_font "DejaVu Sans Mono"  "code fallback"             "(preinstalled on most distros)"

# ── Install opencode skills ──
if [[ "$INSTALL_SKILLS" == true ]]; then
    log_step "Installing opencode skills"

    GLOBAL_SKILLS_DIR="$HOME/.config/opencode/skills"
    SKILL_COUNT=0

    for skill_file in "$SCRIPT_DIR"/templates/*/SKILL.md; do
        if [[ -f "$skill_file" ]]; then
            skill_name=$(awk 'FNR==1 && /^---$/{f=1; next} f && /^---$/{f=0} f && /^name:/{print $2; exit}' "$skill_file")
            skill_dst_dir="$GLOBAL_SKILLS_DIR/$skill_name"
            mkdir -p "$skill_dst_dir"
            cp "$skill_file" "$skill_dst_dir/SKILL.md"
            log_ok "Skill '$skill_name' → $skill_dst_dir/SKILL.md"
            SKILL_COUNT=$((SKILL_COUNT + 1))
        fi
    done

    if [[ $SKILL_COUNT -eq 0 ]]; then
        log_warn "No skills found in templates/*/SKILL.md — skipping"
    else
        log_dim "$SKILL_COUNT skill(s) installed — restart opencode to discover them"
        log_dim "Project-level discovery also works via opencode.json (skills.paths)"
    fi
else
    log_step "opencode skills"
    log_dim "Skipped by user"
fi

# ── Fix system-wide latexmk default ──
log_step "Fixing system-wide latexmk default (/etc/LatexMk)"

if [[ -f /etc/LatexMk ]]; then
    if grep -q '^\$pdf_mode\s*=\s*[14];' /etc/LatexMk; then
        $SUDO sed -i 's/^\$pdf_mode\s*=\s*[14];/$pdf_mode = 5;  # xelatex — required by fontspec/' /etc/LatexMk
        log_ok "/etc/LatexMk: fixed \$pdf_mode → 5 (xelatex)"
    else
        log_ok "/etc/LatexMk: already xelatex or custom"
    fi
else
    echo '$pdf_mode = 5;  # xelatex — required by fontspec' | $SUDO tee /etc/LatexMk >/dev/null
    log_ok "/etc/LatexMk: created with \$pdf_mode = 5 (xelatex)"
fi

# ── Configure VS Code (local + remote) ──
if [[ "$INSTALL_VSCODE" == true ]]; then
    log_step "Configuring VS Code"

    # LaTeX Workshop settings for XeLaTeX via latexmk
    merge_vscode_settings() {
        local settings_path="$1"
        local settings_dir
        settings_dir="$(dirname "$settings_path")"
        mkdir -p "$settings_dir"

        python3 - "$settings_path" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]

# Load existing settings (or empty dict)
if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            settings = {}
else:
    settings = {}

# LaTeX Workshop settings for XeLaTeX via latexmk
latex_settings = {
    "latex-workshop.latex.recipe.default": "latexmk",
    "latex-workshop.latex.recipes": [
        {"name": "latexmk", "tools": ["latexmk"]},
        {"name": "xelatex×2", "tools": ["xelatex", "xelatex"]},
        {"name": "xelatex", "tools": ["xelatex"]}
    ],
    "latex-workshop.latex.tools": [
        {
            "name": "latexmk",
            "command": "latexmk",
            "args": ["-cd", "-xelatex", "-interaction=nonstopmode", "%DOC%"]
        },
        {
            "name": "xelatex",
            "command": "xelatex",
            "args": ["-synctex=1", "-interaction=nonstopmode",
                     "-file-line-error", "%DOC%"]
        }
    ],
    "latex-workshop.view.pdf.viewer": "tab",
    "latex-workshop.latex.autoBuild.run": "onSave"
}

# Merge (only update keys that differ or are missing)
changed = False
for key, value in latex_settings.items():
    if key not in settings or settings[key] != value:
        settings[key] = value
        changed = True

if changed:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print(f"  \033[32m✓\033[0m Updated {settings_path}")
else:
    print(f"  \033[32m✓\033[0m {settings_path} already configured")
PYEOF
    }

    # Local VS Code (desktop)
    VSCODE_LOCAL="$HOME/.config/Code/User/settings.json"
    merge_vscode_settings "$VSCODE_LOCAL"
    log_dim "Local: $VSCODE_LOCAL"

    # VS Code Remote (vscode-server) — machine-level settings
    VSCODE_REMOTE="$HOME/.vscode-server/data/Machine/settings.json"
    if [[ -d "$HOME/.vscode-server" ]]; then
        merge_vscode_settings "$VSCODE_REMOTE"
        log_dim "Remote: $VSCODE_REMOTE"
    else
        log_dim "Remote: not detected (no ~/.vscode-server)"
    fi

    # Install LaTeX Workshop extension if VS Code CLI is available
    if command -v code &>/dev/null; then
        log_desc "VS Code CLI: $(command -v code)"
        lw_out=$(code --install-extension James-Yu.latex-workshop --force 2>&1)
        if echo "$lw_out" | grep -q "successfully installed"; then
            log_ok "Extension: LaTeX Workshop (James-Yu.latex-workshop)"
        else
            log_warn "Failed to install LaTeX Workshop extension"
            log_dim "$(echo "$lw_out" | tail -2)"
        fi
    else
        log_warn "VS Code CLI (code) not found — extensions not installed"
        log_dim "Settings were still written to the paths above"
        log_dim "To install manually: https://code.visualstudio.com/ → LaTeX Workshop"
    fi
else
    log_step "VS Code LaTeX Workshop"
    log_dim "Skipped by user"
fi

# ── Test compilation ──
log_step "Test compilation"

compile_sample() {
    local dir="$1" label="$2" file="${3:-}"
    local src_dir="$dir/src"

    # Detect source file (.adoc only — all samples use AsciiDoc)
    if [[ -f "$src_dir/main.adoc" ]]; then
        local adoc_file="$src_dir/main.adoc"
        local tex_file="$src_dir/main.tex"
        echo "  Converting $adoc_file -> $tex_file"
        "$SCRIPT_DIR/scripts/build-adoc.sh" "$adoc_file" -o "$tex_file" || { log_warn "$label: build-adoc.sh failed"; return 1; }
        file="main.tex"
    elif [[ -n "$file" && -f "$src_dir/$file" ]]; then
        : # use provided file
    else
        log_warn "$label not found at $src_dir — skipping"
        return 1
    fi

    cd "$src_dir"
    latexmk -C "$file" >/dev/null 2>&1
    if latexmk "$file" >/dev/null 2>&1; then
        local pdf="${file%.tex}.pdf"
        # .latexmkrc sets $out_dir='..' — PDF goes to parent dir
        [[ ! -f "$pdf" ]] && pdf="../$pdf"
        local pages=$(pdfinfo "$pdf" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
        log_ok "$label: ${pages:-?} pages"
        latexmk -c "$file" >/dev/null 2>&1
    else
        log_warn "$label compile failed — check $src_dir/${file%.tex}.log"
    fi
}

# Compile all template samples (auto-discover)
for tmpl_dir in "$SCRIPT_DIR"/templates/*/; do
    tmpl_name=$(basename "$tmpl_dir")
    [ "$tmpl_name" = "_base" ] && continue
    [ ! -f "$tmpl_dir/${tmpl_name}.cls" ] && continue

    for lang_dir in "$SCRIPT_DIR/examples/$tmpl_name"/*/; do
        [ ! -d "$lang_dir" ] && continue
        lang_name=$(basename "$lang_dir")
        compile_sample "$lang_dir" "${tmpl_name} ${lang_name} sample"
    done
done

# Setup guide (special case — uses guide template)
compile_sample "$SCRIPT_DIR/examples/setup-guide" "Setup guide" "setup-guide.tex"

# ── Summary ──
echo ""
echo -e "${C_BOLD}${C_GREEN}  ✓ Setup complete${C_RESET}"
echo ""
local -a summary_rows=(
    "Engine:"             "XeLaTeX (TeX Live)"
    "Build tool:"         "latexmk (.latexmkrc → xelatex)"
    "Source format:"      "AsciiDoc (.adoc → LaTeX via asciidoctor)"
    "Body font:"          "HarmonyOS Sans → Liberation Sans"
    "Code font:"          "Cascadia Code → DejaVu Sans Mono"
    "Skills:"             "/skill huawei-template-guide, /skill huawei-template-technical, /skill huawei-template-testbook"
    "VS Code:"            "LaTeX Workshop (local + remote, -cd -xelatex)"
    "Timezone:"           "America/Sao_Paulo (GMT-3, overridable)"
    "Diagrams:"           "PlantUML + graphviz (optional: mermaid-cli for mermaid)"
)
for (( i=0; i<${#summary_rows[@]}; i+=2 )); do
    printf "  ${C_DIM}%-24s${C_RESET} %s\n" "${summary_rows[$i]}" "${summary_rows[$i+1]}"
done
echo ""
echo -e "  ${C_BOLD}Next steps:${C_RESET}"
log_dim "1. Open this project in opencode"
log_dim "2. Run /skill huawei-template-guide to create a new guide"
log_dim "   New documents go in documents/<name>/ (auto-created by the skill)"
log_dim "3. Or open in VS Code — edit .adoc source files to auto-compile"
log_dim "4. Or compile manually:"
log_dim "   make project DIR=documents/my-guide"
echo ""
echo ""
