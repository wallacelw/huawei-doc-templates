#!/usr/bin/env bash
set -euo pipefail

# test-pdf-compile.sh — scan sample LaTeX build logs for compile problems
# Fast check (no recompilation): reads the latexmk .log files that
# `make samples` leaves in each sample's src/ and fails on build-breaking
# issues. Run after `make samples` (the standard gate) so the logs exist.
# Checks per sample log:
#   1. Lines starting with "! " (LaTeX errors)
#   2. "LaTeX Warning: Reference/Citation ... undefined" (broken cross-refs)
#   3. "Package <name> Error:" lines
# Overfull \hbox counts are reported per sample as info only (not failure).
# Missing logs are SKIPs, not failures — this test runs after make samples.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

# Safe grep -cE: returns "0" even when no matches (grep exits 1 on no match).
count() { local n; n=$(grep -cE "$1" "$2" 2>/dev/null || true); echo "${n:-0}"; }

# Scan one build log: print OK/FAIL/SKIP, return 0 (pass), 1 (fail), 2 (skip).
scan_log() {
  local label="$1" log_file="$2"

  if [ ! -f "$log_file" ]; then
    echo "SKIP: $label (no log — run make samples first)"
    return 2
  fi

  local latex_errors undefined_refs package_errors overfull problems
  latex_errors=$(count '^! ' "$log_file")
  undefined_refs=$(count '^LaTeX Warning: (Reference|Citation).*undefined' "$log_file")
  package_errors=$(count '^Package [^ ]+ Error:' "$log_file")
  overfull=$(count 'Overfull \\hbox' "$log_file")

  problems=$((latex_errors + undefined_refs + package_errors))
  if [ "$problems" -gt 0 ]; then
    echo "FAIL: $label ($log_file)"
    [ "$latex_errors" -gt 0 ] && echo "  - $latex_errors LaTeX error(s) (lines starting with '! ')"
    [ "$undefined_refs" -gt 0 ] && echo "  - $undefined_refs undefined reference/citation warning(s)"
    [ "$package_errors" -gt 0 ] && echo "  - $package_errors package error(s)"
    return 1
  fi

  echo "OK: $label (Overfull \\hbox: $overfull)"
  return 0
}

# Run scan_log and tally the result (skip = neither passed nor failed).
check_sample() {
  local label="$1" log_file="$2" status=0
  scan_log "$label" "$log_file" || status=$?
  case "$status" in
    0) PASS=$((PASS + 1)) ;;
    1) FAIL=$((FAIL + 1)) ;;
  esac
}

# --- Scan all template sample logs (auto-discover templates) ---
for tmpl_dir in "$REPO_ROOT"/templates/*/; do
  tmpl=$(basename "$tmpl_dir")
  [ "$tmpl" = "_base" ] && continue
  [ ! -f "$tmpl_dir/${tmpl}.cls" ] && continue
  for lang in pt en; do
    check_sample "${tmpl}-${lang}" "$REPO_ROOT/documents/${tmpl}-${lang}/src/main.log"
  done
done

# --- Setup guide (uses the guide template; different file name) ---
check_sample "setup-guide" "$REPO_ROOT/documents/setup-guide/src/setup-guide.log"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
