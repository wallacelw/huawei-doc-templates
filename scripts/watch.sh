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
dir="${1:-.}"
srcdir="$dir/src"

# Detect .adoc file
adoc=""
if [ -f "$srcdir/main.adoc" ]; then adoc="main.adoc"
elif [ -f "$srcdir/setup-guide.adoc" ]; then adoc="setup-guide.adoc"; fi
if [ -z "$adoc" ]; then
    echo "Error: No .adoc file found in $srcdir/" >&2
    exit 1
fi

echo "Watching $srcdir/$adoc for changes..."
echo "Press Ctrl+C to stop."

recompile() {
    echo "Recompiling..."
    local tex="${adoc%.adoc}.tex"
    "$REPO_ROOT/scripts/build-adoc.sh" "$srcdir/$adoc" -o "$srcdir/$tex" &&
    (cd "$srcdir" && latexmk -xelatex "$tex" 2>&1 | tail -3)
}

if command -v entr >/dev/null 2>&1; then
    find "$srcdir" -name "*.adoc" | entr -s "recompile"
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
