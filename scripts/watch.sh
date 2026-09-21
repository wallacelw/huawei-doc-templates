#!/usr/bin/env bash
# watch.sh — Watch .adoc files and recompile PDF on save
#
# Usage:
#   ./scripts/watch.sh documents/guide-en
#   ./scripts/watch.sh documents/setup-guide
#
# Uses entr if available, falls back to inotifywait, then polling.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"

# Internal --once <dir> mode: recompile one document and exit. Used by the
# entr watcher below — entr runs its command in a fresh process that cannot
# import this shell's exported functions or variables (and `entr -s` goes
# through /bin/sh, which on dash systems rejects exported bash functions),
# so the watcher re-invokes this script under bash instead of `export -f`.
once=0
if [ "${1:-}" = "--once" ]; then
  once=1
  dir="${2:-.}"
else
  dir="${1:-.}"
fi
srcdir="$dir/src"

# Detect .adoc file
adoc=""
if [ -f "$srcdir/main.adoc" ]; then adoc="main.adoc"
elif [ -f "$srcdir/setup-guide.adoc" ]; then adoc="setup-guide.adoc"; fi
if [ -z "$adoc" ]; then
  echo "Error: No .adoc file found in $srcdir/" >&2
  exit 1
fi

# Compile once. Failures are non-fatal by design: print a message and return
# 0 so the watch loops below (and the entr one-shot mode) keep watching.
recompile() {
  echo "Recompiling..."
  local tex="${adoc%.adoc}.tex"
  if "$REPO_ROOT/scripts/build-adoc.sh" "$srcdir/$adoc" -o "$srcdir/$tex" &&
     (cd "$srcdir" && latexmk -xelatex "$tex" 2>&1 | tail -3); then
    echo "✓ PDF updated"
  else
    echo "✗ compile failed — still watching" >&2
  fi
}

if [ "$once" -eq 1 ]; then
  recompile
  exit 0
fi

echo "Watching $srcdir/$adoc for changes..."
echo "Press Ctrl+C to stop."

if command -v entr >/dev/null 2>&1; then
  # entr execs the command and args directly (no shell involved), so pass
  # the script path and flags explicitly. Do not use `entr -s` here: it runs
  # via /bin/sh (dash), which cannot import exported bash functions.
  find "$srcdir" -name "*.adoc" | entr bash "$REPO_ROOT/scripts/watch.sh" --once "$dir"
elif command -v inotifywait >/dev/null 2>&1; then
  while true; do
    inotifywait -q -e modify "$srcdir/$adoc" >/dev/null 2>&1
    recompile
  done
else
  echo "Warning: Neither 'entr' nor 'inotifywait' found. Using polling fallback."
  last_mtime=0
  while true; do
    current_mtime=$(stat -c %Y "$srcdir/$adoc" 2>/dev/null || stat -f %m "$srcdir/$adoc")
    if [ "$current_mtime" != "$last_mtime" ]; then
      last_mtime=$current_mtime
      recompile
    fi
    sleep 1
  done
fi
