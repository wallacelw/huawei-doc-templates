#!/usr/bin/env bash
# ─── uninstall.sh — Remove Huawei Document Templates artifacts ──────────────
#
# Usage:
#   ./uninstall.sh                  # interactive menu
#   ./uninstall.sh --skills         # remove opencode skills only
#   ./uninstall.sh --modules        # remove .sty modules from TDS
#   ./uninstall.sh --font           # remove HarmonyOS Sans font
#   ./uninstall.sh --latexmk        # remove /etc/LatexMk fix
#   ./uninstall.sh --vscode         # remove VS Code settings + extensions
#   ./uninstall.sh --packages       # remove apt packages (WARNING: breaks other TeX)
#   ./uninstall.sh --repo           # remove the cloned repo (all files, guides, docs)
#   ./uninstall.sh --all            # everything except apt packages + repo
#   ./uninstall.sh --all --packages # everything including apt packages
#   ./uninstall.sh --all --repo     # everything including the repo (prompts to confirm)
#   ./uninstall.sh --dry-run        # show what would be removed
#   ./uninstall.sh --yes            # skip confirmation
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
log_info()  { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_ok()    { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_warn()  { echo -e "  ${C_YELLOW}⚠${C_RESET}  $1"; }
log_error() { echo -e "  ${C_RED}✗${C_RESET} $1"; }
log_done()  { echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}$1${C_RESET}"; }
log_dim()   { echo -e "    ${C_DIM}$1${C_RESET}"; }

# Dry-run wrapper: echo command instead of executing
run() {
    if [ "$DRY_RUN" = true ]; then
        log_dim "would run: $*"
    else
        eval "$@"
    fi
}

# ── Banner ──
echo ""
echo -e "  ${C_BOLD}${C_YELLOW}Huawei Document Templates — uninstall.sh${C_RESET}"
echo ""

# ── Interactive menu (no flags) ──
if [ "$REMOVE_SKILLS" = false ] && [ "$REMOVE_MODULES" = false ] \
   && [ "$REMOVE_FONT" = false ] && [ "$REMOVE_LATEXMK" = false ] \
   && [ "$REMOVE_VSCODE" = false ] && [ "$REMOVE_PACKAGES" = false ] \
   && [ "$REMOVE_REPO" = false ]; then
    echo -e "  Select what to uninstall:"
    echo ""
    echo -e "  ${C_BOLD}1${C_RESET}  opencode skills"
    echo -e "  ${C_BOLD}2${C_RESET}  LaTeX modules (.sty from TDS)"
    echo -e "  ${C_BOLD}3${C_RESET}  HarmonyOS Sans font"
    echo -e "  ${C_BOLD}4${C_RESET}  latexmk system config (/etc/LatexMk)"
    echo -e "  ${C_BOLD}5${C_RESET}  VS Code settings + extensions"
    echo -e "  ${C_BOLD}6${C_RESET}  All of the above (safe — does not remove apt packages)"
    echo -e "  ${C_BOLD}7${C_RESET}  Everything including apt packages (WARNING: breaks other TeX)"
    echo -e "  ${C_BOLD}8${C_RESET}  Delete the repo directory (all files, guides, documents)"
    echo -e "  ${C_DIM}Or combine: 1,2,3 (skills + modules + font)${C_RESET}"
    echo ""
    echo -n "  Choice: "
    read -r choice || choice=""
    echo ""
    case "$choice" in
        1) REMOVE_SKILLS=true ;;
        2) REMOVE_MODULES=true ;;
        3) REMOVE_FONT=true ;;
        4) REMOVE_LATEXMK=true ;;
        5) REMOVE_VSCODE=true ;;
        6) REMOVE_SKILLS=true; REMOVE_MODULES=true; REMOVE_FONT=true
           REMOVE_LATEXMK=true; REMOVE_VSCODE=true ;;
        7) REMOVE_SKILLS=true; REMOVE_MODULES=true; REMOVE_FONT=true
           REMOVE_LATEXMK=true; REMOVE_VSCODE=true; REMOVE_PACKAGES=true ;;
        8) REMOVE_REPO=true ;;
        *)
            IFS=',' read -ra items <<< "$choice"
            for item in "${items[@]}"; do
                case "$item" in
                    1) REMOVE_SKILLS=true ;;
                    2) REMOVE_MODULES=true ;;
                    3) REMOVE_FONT=true ;;
                    4) REMOVE_LATEXMK=true ;;
                    5) REMOVE_VSCODE=true ;;
                    6) REMOVE_SKILLS=true; REMOVE_MODULES=true; REMOVE_FONT=true
                       REMOVE_LATEXMK=true; REMOVE_VSCODE=true ;;
                    7) REMOVE_SKILLS=true; REMOVE_MODULES=true; REMOVE_FONT=true
                       REMOVE_LATEXMK=true; REMOVE_VSCODE=true; REMOVE_PACKAGES=true ;;
                    8) REMOVE_REPO=true ;;
                    *) log_warn "Unknown choice: $item" ;;
                esac
            done
            ;;
    esac
fi

# ── Check if anything selected ──
if [ "$REMOVE_SKILLS" = false ] && [ "$REMOVE_MODULES" = false ] \
   && [ "$REMOVE_FONT" = false ] && [ "$REMOVE_LATEXMK" = false ] \
   && [ "$REMOVE_VSCODE" = false ] && [ "$REMOVE_PACKAGES" = false ] \
   && [ "$REMOVE_REPO" = false ]; then
    echo -e "  ${C_DIM}Nothing selected. Aborting.${C_RESET}"
    exit 0
fi

# ── Sudo detection ──
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ── Confirmation ──
if [ "$SKIP_CONFIRM" != true ] && [ "$DRY_RUN" != true ]; then
    echo -e "  ${C_BOLD}Will remove:${C_RESET}"
    [ "$REMOVE_SKILLS" = true ]   && log_dim "• opencode skills (~/.config/opencode/skills/huawei-template-*)"
    [ "$REMOVE_MODULES" = true ]  && log_dim "• .sty modules from TDS (/usr/local/share/texmf/tex/latex/huawei/)"
    [ "$REMOVE_FONT" = true ]     && log_dim "• HarmonyOS Sans font (.deb package)"
    [ "$REMOVE_LATEXMK" = true ]  && log_dim "• /etc/LatexMk xelatex fix"
    [ "$REMOVE_VSCODE" = true ]   && log_dim "• VS Code LaTeX Workshop settings + extensions"
    [ "$REMOVE_PACKAGES" = true ] && log_dim "• apt packages (texlive-xetex, latexmk, fonts, pandoc, ...)"
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
            run "rm -rf \"$skill_dir\""
            if [ "$DRY_RUN" != true ]; then
                log_ok "Removed: $skill_name"
            else
                log_dim "would remove: $skill_name"
            fi
            SKILL_COUNT=$((SKILL_COUNT + 1))
        fi
    done

    if [ $SKILL_COUNT -eq 0 ]; then
        log_dim "No huawei-template-* skills found"
    else
        log_dim "$SKILL_COUNT skill(s) removed"
    fi
fi

# ── Remove .sty modules from TDS ──
if [ "$REMOVE_MODULES" = true ]; then
    log_step "Removing Huawei shared modules (TDS)"
    TEXMF_LOCAL=$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null)
    HUAWEI_STY_DIR="$TEXMF_LOCAL/tex/latex/huawei"

    if [[ -n "$TEXMF_LOCAL" ]] && [[ -d "$HUAWEI_STY_DIR" ]]; then
        MODULE_COUNT=$(find "$HUAWEI_STY_DIR" -name "huawei-*.sty" | wc -l)
        run "rm -rf \"$HUAWEI_STY_DIR\""
        run "$SUDO texhash >/dev/null 2>&1"
        log_ok "Removed $MODULE_COUNT modules from $HUAWEI_STY_DIR"
    else
        log_dim "No Huawei modules found in TDS"
    fi
fi

# ── Remove HarmonyOS Sans font ──
if [ "$REMOVE_FONT" = true ]; then
    log_step "Removing HarmonyOS Sans font"

    if fc-list : family | grep -qi "HarmonyOS Sans"; then
        if dpkg -l | grep -q "harmonyos"; then
            run "$SUDO apt remove -y harmonyos-sans-cn 2>/dev/null || $SUDO apt remove -y 'harmonyos*' 2>/dev/null"
            run "fc-cache -f"
            log_ok "HarmonyOS Sans font removed"
        else
            log_warn "HarmonyOS Sans found but not as a .deb package — remove manually"
            log_dim "Check: fc-list | grep -i harmonyos"
        fi
    else
        log_dim "HarmonyOS Sans not installed"
    fi
fi

# ── Remove /etc/LatexMk fix ──
if [ "$REMOVE_LATEXMK" = true ]; then
    log_step "Removing latexmk system config"

    if [[ -f /etc/LatexMk ]]; then
        if grep -q 'pdf_mode.*=.*5.*xelatex' /etc/LatexMk; then
            if [ "$DRY_RUN" = true ]; then
                log_dim "would run: sed -i to remove xelatex fix from /etc/LatexMk"
            else
                $SUDO sed -i '/pdf_mode.*=.*5.*xelatex/d' /etc/LatexMk
                # If file is now empty or only has comments, remove it
                if ! grep -q '^[^#]' /etc/LatexMk 2>/dev/null; then
                    $SUDO rm -f /etc/LatexMk
                    log_ok "Removed /etc/LatexMk (was only xelatex fix)"
                else
                    log_ok "Removed xelatex fix from /etc/LatexMk (other settings preserved)"
                fi
            fi
        else
            log_dim "/etc/LatexMk exists but no xelatex fix found"
        fi
    else
        log_dim "/etc/LatexMk not found"
    fi
fi

# ── Remove VS Code settings + extensions ──
if [ "$REMOVE_VSCODE" = true ]; then
    log_step "Removing VS Code settings"

    # Remove LaTeX Workshop settings from local and remote configs
    for settings_path in \
        "$HOME/.config/Code/User/settings.json" \
        "$HOME/.vscode-server/data/Machine/settings.json"; do

        if [[ -f "$settings_path" ]]; then
            if grep -q "latex-workshop" "$settings_path" 2>/dev/null; then
                if [ "$DRY_RUN" = true ]; then
                    log_dim "would remove latex-workshop keys from $settings_path"
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
                    log_ok "Removed LaTeX Workshop settings from $(echo "$settings_path" | sed "s|$HOME|~|")"
                fi
            else
                log_dim "No latex-workshop settings in $(echo "$settings_path" | sed "s|$HOME|~|")"
            fi
        else
            log_dim "Not found: $(echo "$settings_path" | sed "s|$HOME|~|")"
        fi
    done

    # Uninstall extensions
    if command -v code &>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_dim "would uninstall: James-Yu.latex-workshop, valentjn.vscode-ltex"
        else
            if code --uninstall-extension James-Yu.latex-workshop 2>/dev/null; then
                log_ok "Uninstalled: LaTeX Workshop extension"
            else
                log_dim "LaTeX Workshop extension not installed or already removed"
            fi
            code --uninstall-extension valentjn.vscode-ltex 2>/dev/null || true
        fi
    else
        log_dim "VS Code CLI not found — extensions not removed"
    fi
fi

# ── Remove apt packages ──
if [ "$REMOVE_PACKAGES" = true ]; then
    log_step "Removing apt packages"

    log_warn "This will remove TeX Live, latexmk, fonts, and pandoc."
    log_warn "Other LaTeX documents on this system may break."

    PACKAGES="texlive-xetex texlive-latex-extra texlive-lang-portuguese latexmk \
              fonts-liberation fonts-cascadia-code poppler-utils pandoc python3-docx"

    if [ "$DRY_RUN" = true ]; then
        log_dim "would run: apt-get remove -y $PACKAGES"
    else
        $SUDO apt-get remove -y $PACKAGES 2>&1 | grep -v "^$\|Reading\|Building\|Need to get\|After this\|Fetched\|Selecting\|Setting up\|Unpacking\|Preparing\|Processing\|update-alternatives\|man-db\|trigger\|qemu\|VM guests\|systemd" || true
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
    log_dim "• Sample documents (examples/)"
    log_dim "• User documents (documents/)"
    log_dim "• Assets (images, logos)"
    log_dim "• Git history"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        log_dim "would run: rm -rf \"$SCRIPT_DIR\""
    elif [ "$SKIP_CONFIRM" = true ]; then
        # Even with --yes, require explicit confirmation for repo deletion
        echo -ne "  ${C_BOLD}${C_RED}Type 'yes' to confirm deletion:${C_RESET} "
        read -r response
        if [[ "$response" == "yes" ]]; then
            rm -rf "$SCRIPT_DIR"
            log_ok "Repository directory removed"
        else
            log_warn "Repository deletion cancelled (must type 'yes' exactly)"
        fi
    else
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
if [ "$REMOVE_REPO" = true ] && [ -d "$SCRIPT_DIR" ]; then
    echo -e "  ${C_DIM}Repository was not removed (cancelled or dry run).${C_RESET}"
elif [ -d "$SCRIPT_DIR" ]; then
    echo -e "  ${C_DIM}The repository itself is not removed. To delete it:${C_RESET}"
    echo -e "  ${C_DIM}  rm -rf $SCRIPT_DIR${C_RESET}"
fi
echo ""
