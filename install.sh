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
CLONE_DIR="huawei-doc-templates"

if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    # Running from a file (./install.sh)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # If --clone flag, clone first
    if [[ "$DO_CLONE" == true ]]; then
        if [[ -d "$CLONE_DIR" ]]; then
            echo "  $CLONE_DIR already exists — skipping clone"
        else
            git clone "$REPO_URL" "$CLONE_DIR"
        fi
        cd "$CLONE_DIR"
        SCRIPT_DIR="$(pwd)"
    fi
else
    # Running from pipe (curl | bash) — auto-clone + non-interactive
    AUTO_YES=true
    if [[ -d "$CLONE_DIR" ]]; then
        echo "  $CLONE_DIR already exists — reusing"
    else
        git clone "$REPO_URL" "$CLONE_DIR"
    fi
    cd "$CLONE_DIR"
    SCRIPT_DIR="$(pwd)"
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
_banner_border=""
for _i in $(seq 1 $_banner_width); do _banner_border+="═"; done
echo ""
echo -e "${C_BOLD}${C_CYAN}╔${_banner_border}╗${C_RESET}"
echo -e "${C_BOLD}${C_CYAN}║  ${_banner_text}  ║${C_RESET}"
echo -e "${C_BOLD}${C_CYAN}╚${_banner_border}╝${C_RESET}"
echo ""

echo -e "  ${C_BOLD}What:${C_RESET}  LaTeX templates for Huawei Cloud guides (XeLaTeX + latexmk)"
echo ""
echo -e "  ${C_BOLD}Installs:${C_RESET}"
log_dim "• XeLaTeX + latexmk + LaTeX packages"
log_dim "• HarmonyOS Sans (body font, free commercial use)"
log_dim "• Cascadia Code (code font, open source)"
log_dim "• opencode skill (/skill huawei-template-guide)"
log_dim "• VS Code LaTeX Workshop (local + remote config)"
echo ""
echo -e "  ${C_BOLD}Prerequisites:${C_RESET}"
log_dim "• Ubuntu 22.04+ (WSL or native)     (required)"
log_dim "• apt-get, sudo                      (required)"
log_dim "• VS Code CLI (code)                 (optional — for extension install)"
echo ""

# ── Confirmation ──
if [[ "$AUTO_YES" != true ]]; then
    echo ""
    echo "This script will:"
    echo "  1. Install apt packages: texlive-xetex, texlive-latex-extra, texlive-lang-portuguese, latexmk, fonts-liberation, fonts-cascadia-code, poppler-utils, pandoc, python3-docx"
    echo "  2. Update fvextra from CTAN if version < 1.5 (backgroundcolor support)"
    echo "  3. Download and install HarmonyOS Sans font (.deb from GitHub releases)"
    echo "  4. Update font cache (fc-cache)"
    echo "  5. Copy .sty modules to system TeX directory (requires sudo)"
    echo "  6. Fix system-wide latexmk default to xelatex (/etc/LatexMk)"
    echo "  7. Configure VS Code settings (LaTeX Workshop, local + remote)"
    echo "  8. Compile sample documents to verify installation"
    echo ""
    echo -e "  ${C_BOLD}Proceed with installation?${C_RESET} [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "  ${C_DIM}Aborted.${C_RESET}"
        exit 0
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
$SUDO apt-get install -y \
    texlive-xetex \
    texlive-latex-extra \
    texlive-lang-portuguese \
    latexmk \
    fonts-liberation \
    fonts-cascadia-code \
    poppler-utils \
    pandoc \
    python3-docx \
    2>&1 | tail -3

log_done "TeX Live packages installed"

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
            latex fvextra.ins 2>/dev/null
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

if fc-list | grep -q "HarmonyOS Sans"; then
    log_ok "HarmonyOS Sans: already installed"
else
    log_desc "Downloading from GitHub releases..."
    if wget -q "$HARMONYOS_DEB_URL" -O "$HARMONYOS_DEB"; then
        if echo "$HARMONYOS_DEB_SHA256  $HARMONYOS_DEB" | sha256sum -c - 2>/dev/null; then
            $SUDO apt install -y "$HARMONYOS_DEB" 2>&1 | tail -2
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

log_step "Verifying pandoc"
if command -v pandoc &>/dev/null; then
    log_done "pandoc $(pandoc --version | head -1)"
else
    log_warn "pandoc not found — DOCX/MD/HTML output unavailable (PDF still works)"
fi

# Font checks
check_font() {
    if fc-list | grep -q "$1"; then
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

    if code --install-extension James-Yu.latex-workshop --force 2>/dev/null; then
        log_ok "Extension: LaTeX Workshop (James-Yu.latex-workshop)"
    else
        log_warn "Failed to install LaTeX Workshop extension"
    fi

    # Optional: LTeX for spell/grammar checking
    if code --install-extension valentjn.vscode-ltex --force 2>/dev/null; then
        log_ok "Extension: LTeX (valentjn.vscode-ltex)"
    else
        log_warn "Failed to install LTeX extension (optional — spell/grammar checking)"
    fi
else
    log_warn "VS Code CLI (code) not found — extensions not installed"
    log_dim "Settings were still written to the paths above"
    log_dim "To install manually: https://code.visualstudio.com/ → LaTeX Workshop"
fi

# ── Test compilation ──
log_step "Test compilation"

PT_DIR="$SCRIPT_DIR/examples/guide/pt"
EN_DIR="$SCRIPT_DIR/examples/guide/en"
SG_DIR="$SCRIPT_DIR/examples/setup-guide"

compile_sample() {
    local dir="$1" label="$2" file="${3:-main.tex}"
    if [[ -f "$dir/$file" ]]; then
        cd "$dir"
        latexmk -C "$file" 2>/dev/null
        if latexmk "$file" 2>/dev/null; then
            local pdf="${file%.tex}.pdf"
            local pages=$(pdfinfo "$pdf" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
            log_ok "$label: ${pages:-?} pages"
            latexmk -c "$file" 2>/dev/null   # clean aux files only, preserve PDF
        else
            log_warn "$label compile failed — check $dir/${file%.tex}.log"
        fi
    else
        log_warn "$label not found at $dir — skipping"
    fi
}

compile_sample "$PT_DIR" "Portuguese sample"
compile_sample "$EN_DIR" "English sample"
compile_sample "$SG_DIR" "Setup guide" "setup-guide.tex"

# ── Summary ──
echo ""
echo -e "${C_BOLD}${C_GREEN}  ✓ Setup complete${C_RESET}"
echo ""
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "Engine:"             "XeLaTeX (TeX Live)"
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "Build tool:"         "latexmk (.latexmkrc → xelatex)"
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "Body font:"          "HarmonyOS Sans → Liberation Sans"
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "Code font:"          "Cascadia Code → DejaVu Sans Mono"
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "Skill:"              "/skill huawei-template-guide"
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "VS Code:"            "LaTeX Workshop (local + remote, -cd -xelatex)"
printf "  ${C_DIM}%-24s${C_RESET} %s\n" "Timezone:"           "America/Sao_Paulo (GMT-3, overridable)"
echo ""
echo -e "  ${C_BOLD}Next steps:${C_RESET}"
log_dim "1. Open this project in opencode"
log_dim "2. Run /skill huawei-template-guide to create a new guide"
log_dim "   New documents go in documents/<name>/ (auto-created by the skill)"
log_dim "3. Or open in VS Code — save a .tex file to auto-compile"
log_dim "4. Or compile manually:"
log_dim "   cd documents/my-guide && latexmk main.tex"
echo ""
echo ""
