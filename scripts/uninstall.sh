#!/usr/bin/env bash
# ─── uninstall.sh — Remove Huawei Document Templates artifacts ──────────────
#
# Usage:
#   ./scripts/uninstall.sh                  # interactive menu
#   ./scripts/uninstall.sh --all            # remove all installed components (safe)
#   ./scripts/uninstall.sh --all --packages # also remove apt packages (breaks other TeX)
#   ./scripts/uninstall.sh --all --repo     # also delete the repo (prompts to confirm)
#   ./scripts/uninstall.sh --skills         # remove specific component only
#   ./scripts/uninstall.sh --modules --font # combine specific components
#   ./scripts/uninstall.sh --dry-run        # show what would be removed
#   ./scripts/uninstall.sh --yes            # skip confirmation (repo still prompts)
#
# Components: --skills --modules --font --latexmk --vscode --packages --repo
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Detect script location (file or pipe) ──
CLONE_DIR="/home/huawei-doc-templates"

if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    # Running from a file (./scripts/uninstall.sh)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Running from pipe (curl | bash) — find the repo
    if [[ -d .git ]] && [[ -f scripts/uninstall.sh ]]; then
        # Already inside the repo
        SCRIPT_DIR="$(pwd)"
    elif [[ -d "$CLONE_DIR/.git" ]]; then
        # Repo exists at default path
        SCRIPT_DIR="$CLONE_DIR"
    else
        echo "Error: Could not find the huawei-doc-templates repository."
        echo "Run this script from inside the repo, or use: ./scripts/uninstall.sh"
        exit 1
    fi
fi

# ── Parse arguments ──
REMOVE_SKILLS=false
REMOVE_MODULES=false
REMOVE_FONT=false
REMOVE_LATEXMK=false
REMOVE_VSCODE=false
REMOVE_PACKAGES=false
REMOVE_REPO=false
DRY_RUN=false
SKIP_CONFIRM=false

for arg in "$@"; do
    case "$arg" in
        --skills)     REMOVE_SKILLS=true ;;
        --modules)    REMOVE_MODULES=true ;;
        --font)       REMOVE_FONT=true ;;
        --latexmk)    REMOVE_LATEXMK=true ;;
        --vscode)     REMOVE_VSCODE=true ;;
        --packages)   REMOVE_PACKAGES=true ;;
        --repo)       REMOVE_REPO=true ;;
        --all)
            REMOVE_SKILLS=true
            REMOVE_MODULES=true
            REMOVE_FONT=true
            REMOVE_LATEXMK=true
            REMOVE_VSCODE=true
            ;;
        --dry-run)    DRY_RUN=true ;;
        --yes|-y)     SKIP_CONFIRM=true ;;
        --help|-h)
            sed -n '2,16p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
    esac
done

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
log_ok()    { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_warn()  { echo -e "  ${C_YELLOW}⚠${C_RESET}  $1"; }
log_error() { echo -e "  ${C_RED}✗${C_RESET} $1"; }
log_done()  { echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}$1${C_RESET}"; }
log_dim()   { echo -e "    ${C_DIM}$1${C_RESET}"; }

# ── Sudo detection ──
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Helper: check if any removal flag is set
any_selected() {
    [ "$REMOVE_SKILLS" = true ] || [ "$REMOVE_MODULES" = true ] \
    || [ "$REMOVE_FONT" = true ] || [ "$REMOVE_LATEXMK" = true ] \
    || [ "$REMOVE_VSCODE" = true ] || [ "$REMOVE_PACKAGES" = true ] \
    || [ "$REMOVE_REPO" = true ]
}

# Helper: set all installed components
set_all() {
    REMOVE_SKILLS=true
    REMOVE_MODULES=true
    REMOVE_FONT=true
    REMOVE_LATEXMK=true
    REMOVE_VSCODE=true
}

# ── Banner ──
echo ""
echo -e "  ${C_BOLD}${C_YELLOW}Huawei Document Templates — uninstall.sh${C_RESET}"
echo ""

# ── Interactive menu (no flags) ──
if ! any_selected; then
    echo -e "  Select what to uninstall:"
    echo ""
    echo -e "  ${C_BOLD}1${C_RESET}  All installed components (skills, modules, font, VS Code)  ${C_DIM}[safe]${C_RESET}"
    echo -e "  ${C_BOLD}2${C_RESET}  Everything + apt packages  ${C_DIM}(WARNING: breaks other TeX)${C_RESET}"
    echo -e "  ${C_BOLD}3${C_RESET}  Delete repository directory  ${C_DIM}(all files, guides, documents)${C_RESET}"
    echo -e "  ${C_BOLD}4${C_RESET}  Remove 100% — everything + apt + repo  ${C_DIM}(nuclear option)${C_RESET}"
    echo -e "  ${C_BOLD}5${C_RESET}  Choose specific components individually"
    echo ""
    echo -n "  Choice: "
    read -r choice || choice=""
    echo ""
    case "$choice" in
        1) set_all ;;
        2) set_all; REMOVE_PACKAGES=true ;;
        3) REMOVE_REPO=true ;;
        4) set_all; REMOVE_PACKAGES=true; REMOVE_REPO=true ;;
        5)
            echo -e "  Select components (comma-separated):"
            echo ""
            echo -e "  ${C_BOLD}1${C_RESET}  opencode skills"
            echo -e "  ${C_BOLD}2${C_RESET}  LaTeX modules (.sty from TDS)"
            echo -e "  ${C_BOLD}3${C_RESET}  HarmonyOS Sans font"
            echo -e "  ${C_BOLD}4${C_RESET}  latexmk system config (/etc/LatexMk)"
            echo -e "  ${C_BOLD}5${C_RESET}  VS Code settings + extensions"
            echo -e "  ${C_BOLD}6${C_RESET}  apt packages  ${C_DIM}(WARNING: breaks other TeX)${C_RESET}"
            echo -e "  ${C_BOLD}7${C_RESET}  repository directory  ${C_DIM}(all files, guides, documents)${C_RESET}"
            echo ""
            echo -n "  Choice: "
            read -r sub_choice || sub_choice=""
            echo ""
            IFS=',' read -ra items <<< "$sub_choice"
            for item in "${items[@]}"; do
                case "$item" in
                    1) REMOVE_SKILLS=true ;;
                    2) REMOVE_MODULES=true ;;
                    3) REMOVE_FONT=true ;;
                    4) REMOVE_LATEXMK=true ;;
                    5) REMOVE_VSCODE=true ;;
                    6) REMOVE_PACKAGES=true ;;
                    7) REMOVE_REPO=true ;;
                    *) log_warn "Unknown choice: $item" ;;
                esac
            done
            ;;
        *) echo -e "  ${C_DIM}Invalid choice. Aborting.${C_RESET}"; exit 0 ;;
    esac
fi

# ── Check if anything selected ──
if ! any_selected; then
    echo -e "  ${C_DIM}Nothing selected. Aborting.${C_RESET}"
    exit 0
fi

# ── Confirmation ──
if [ "$SKIP_CONFIRM" != true ] && [ "$DRY_RUN" != true ]; then
    echo -e "  ${C_BOLD}Will remove:${C_RESET}"
    [ "$REMOVE_SKILLS" = true ]   && log_dim "• opencode skills"
    [ "$REMOVE_MODULES" = true ]  && log_dim "• .sty modules from TDS"
    [ "$REMOVE_FONT" = true ]     && log_dim "• HarmonyOS Sans font"
    [ "$REMOVE_LATEXMK" = true ]  && log_dim "• /etc/LatexMk xelatex fix"
    [ "$REMOVE_VSCODE" = true ]   && log_dim "• VS Code settings + extensions"
    [ "$REMOVE_PACKAGES" = true ] && log_dim "• apt packages (texlive, latexmk, fonts, pandoc)"
    [ "$REMOVE_REPO" = true ]     && log_dim "• repository directory (all files, guides, documents)"
    echo ""
    echo -ne "  ${C_BOLD}Proceed?${C_RESET} [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "  ${C_DIM}Aborted.${C_RESET}"
        exit 0
    fi
fi

if [ "$DRY_RUN" = true ]; then
    log_step "Dry run — no changes will be made"
fi

# ── Remove opencode skills ──
if [ "$REMOVE_SKILLS" = true ]; then
    log_step "Removing opencode skills"
    GLOBAL_SKILLS_DIR="$HOME/.config/opencode/skills"
    SKILL_COUNT=0

    for skill_dir in "$GLOBAL_SKILLS_DIR"/huawei-template-*; do
        if [[ -d "$skill_dir" ]]; then
            skill_name=$(basename "$skill_dir")
            if [ "$DRY_RUN" = true ]; then
                log_dim "would remove: $skill_name"
            else
                rm -rf "$skill_dir"
                log_ok "Removed: $skill_name"
            fi
            SKILL_COUNT=$((SKILL_COUNT + 1))
        fi
    done

    if [ $SKILL_COUNT -eq 0 ]; then
        log_dim "No huawei-template-* skills found"
    fi
fi

# ── Remove .sty modules from TDS ──
if [ "$REMOVE_MODULES" = true ]; then
    log_step "Removing Huawei shared modules (TDS)"
    TEXMF_LOCAL=$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null)
    HUAWEI_STY_DIR="$TEXMF_LOCAL/tex/latex/huawei"

    if [[ -n "$TEXMF_LOCAL" ]] && [[ -d "$HUAWEI_STY_DIR" ]]; then
        MODULE_COUNT=$(find "$HUAWEI_STY_DIR" -name "huawei-*.sty" | wc -l)
        if [ "$DRY_RUN" = true ]; then
            log_dim "would remove: $HUAWEI_STY_DIR ($MODULE_COUNT modules)"
        else
            rm -rf "$HUAWEI_STY_DIR"
            $SUDO texhash >/dev/null 2>&1
            log_ok "Removed $MODULE_COUNT modules from TDS"
        fi
    else
        log_dim "No Huawei modules found in TDS"
    fi
fi

# ── Remove HarmonyOS Sans font ──
if [ "$REMOVE_FONT" = true ]; then
    log_step "Removing HarmonyOS Sans font"

    if fc-list : family | grep -qi "HarmonyOS Sans"; then
        if dpkg -l | grep -q "harmonyos"; then
            if [ "$DRY_RUN" = true ]; then
                log_dim "would run: apt remove harmonyos-sans-cn"
            else
                $SUDO apt remove -y harmonyos-sans-cn >/dev/null 2>&1 || \
                $SUDO apt remove -y 'harmonyos*' >/dev/null 2>&1 || true
                fc-cache -f
                log_ok "HarmonyOS Sans font removed"
            fi
        else
            log_warn "HarmonyOS Sans found but not as a .deb — remove manually"
        fi
    else
        log_dim "HarmonyOS Sans not installed"
    fi
fi

# ── Remove /etc/LatexMk fix ──
if [ "$REMOVE_LATEXMK" = true ]; then
    log_step "Removing latexmk system config"

    if [[ -f /etc/LatexMk ]] && grep -q 'pdf_mode.*=.*5.*xelatex' /etc/LatexMk; then
        if [ "$DRY_RUN" = true ]; then
            log_dim "would remove xelatex fix from /etc/LatexMk"
        else
            $SUDO sed -i '/pdf_mode.*=.*5.*xelatex/d' /etc/LatexMk
            if ! grep -q '^[^#]' /etc/LatexMk 2>/dev/null; then
                $SUDO rm -f /etc/LatexMk
                log_ok "Removed /etc/LatexMk (was only xelatex fix)"
            else
                log_ok "Removed xelatex fix from /etc/LatexMk (other settings preserved)"
            fi
        fi
    else
        log_dim "/etc/LatexMk not found or no xelatex fix"
    fi
fi

# ── Remove VS Code settings + extensions ──
if [ "$REMOVE_VSCODE" = true ]; then
    log_step "Removing VS Code settings"

    for settings_path in \
        "$HOME/.config/Code/User/settings.json" \
        "$HOME/.vscode-server/data/Machine/settings.json"; do

        display_path=$(echo "$settings_path" | sed "s|$HOME|~|")

        if [[ -f "$settings_path" ]] && grep -q "latex-workshop" "$settings_path" 2>/dev/null; then
            if [ "$DRY_RUN" = true ]; then
                log_dim "would remove latex-workshop keys from $display_path"
            else
                python3 - "$settings_path" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    try:
        s = json.load(f)
    except json.JSONDecodeError:
        sys.exit(0)
removed = False
for key in list(s.keys()):
    if key.startswith("latex-workshop"):
        del s[key]
        removed = True
if removed:
    with open(path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
PYEOF
                log_ok "Removed LaTeX Workshop settings from $display_path"
            fi
        else
            log_dim "Not found or no latex-workshop: $display_path"
        fi
    done

    # Uninstall extensions
    if command -v code &>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_dim "would uninstall: LaTeX Workshop extension"
        else
            code --uninstall-extension James-Yu.latex-workshop >/dev/null 2>&1 && \
                log_ok "Uninstalled: LaTeX Workshop extension" || \
                log_dim "LaTeX Workshop extension not installed"
        fi
    else
        log_dim "VS Code CLI not found — extensions not removed"
    fi
fi

# ── Remove apt packages ──
if [ "$REMOVE_PACKAGES" = true ]; then
    log_step "Removing apt packages"

    PACKAGES="texlive-xetex texlive-latex-extra texlive-lang-portuguese latexmk \
              fonts-liberation fonts-cascadia-code poppler-utils pandoc python3-docx"

    if [ "$DRY_RUN" = true ]; then
        log_dim "would run: apt-get remove -y $PACKAGES"
    else
        $SUDO apt-get remove -y $PACKAGES >/dev/null 2>&1
        log_ok "apt packages removed"
    fi
fi

# ── Remove repo directory ──
if [ "$REMOVE_REPO" = true ]; then
    log_step "Removing repository directory"

    echo ""
    echo -e "  ${C_BOLD}${C_RED}WARNING: This will permanently delete:${C_RESET}"
    echo -e "  ${C_RED}  $SCRIPT_DIR${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}All files will be lost:${C_RESET}"
    log_dim "• Source templates (.cls, .sty, .lua, .py)"
    log_dim "• Sample documents (documents/)"
    log_dim "• User documents (documents/)"
    log_dim "• Assets (images, logos)"
    log_dim "• Git history"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        log_dim "would run: rm -rf \"$SCRIPT_DIR\""
    else
        # Always require typing 'yes' for repo deletion, even with --yes
        echo -ne "  ${C_BOLD}${C_RED}Type 'yes' to confirm deletion:${C_RESET} "
        read -r response
        if [[ "$response" == "yes" ]]; then
            rm -rf "$SCRIPT_DIR"
            log_ok "Repository directory removed"
        else
            log_warn "Repository deletion cancelled (must type 'yes' exactly)"
        fi
    fi
fi

# ── Summary ──
echo ""
if [ "$DRY_RUN" = true ]; then
    echo -e "  ${C_BOLD}${C_YELLOW}Dry run complete${C_RESET} — no changes were made"
else
    echo -e "  ${C_BOLD}${C_GREEN}✓ Uninstall complete${C_RESET}"
fi
echo ""
if [ "$REMOVE_REPO" != true ] && [ -d "$SCRIPT_DIR" ]; then
    echo -e "  ${C_DIM}Repository not removed. To delete it: rm -rf $SCRIPT_DIR${C_RESET}"
fi
echo ""
