#!/usr/bin/env bash
set -euo pipefail

# test-sync.sh — verify version synchronization across the project
# Checks:
#   1. guide.cls version == setup-guide \setdocversion
#   2. guide.cls version == latest git tag (if tags exist)
#   3. Makefile has exactly 9 individual format targets

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLS_FILE="$REPO_ROOT/templates/guide/guide.cls"
TEX_FILE="$REPO_ROOT/examples/setup-guide/src/setup-guide.tex"
MAKEFILE="$REPO_ROOT/Makefile"

# --- Extract cls version from \ProvidesClass line ---
cls_version=$(grep -oP '\\ProvidesClass\{guide\}\[.*?v\K[0-9]+\.[0-9]+\.[0-9]+' "$CLS_FILE")
if [ -z "$cls_version" ]; then
  echo "FAIL: could not extract version from $CLS_FILE"
  exit 1
fi

# --- Extract setup-guide version from \setdocversion{X.Y.Z} ---
sg_version=$(grep -oP '\\setdocversion\{\K[0-9]+\.[0-9]+\.[0-9]+' "$TEX_FILE")
if [ -z "$sg_version" ]; then
  echo "FAIL: could not extract version from $TEX_FILE"
  exit 1
fi

# --- Extract latest git tag (strip leading 'v') ---
tag_version=""
if git_tag=$(git describe --tags --abbrev=0 2>/dev/null); then
  tag_version="${git_tag#v}"
fi

# --- Assert cls version == setup-guide version ---
if [ "$cls_version" != "$sg_version" ]; then
  echo "FAIL: cls version ($cls_version) != setup-guide version ($sg_version)"
  exit 1
fi

# --- Check cls version vs git tag version (warning only — tag may lag during development) ---
tag_status="v$tag_version"
if [ -z "$tag_version" ]; then
  echo "WARN: no git tags found — skipping tag check"
  tag_status="none"
elif [ "$cls_version" != "$tag_version" ]; then
  echo "WARN: cls version ($cls_version) != git tag version ($tag_version) — tag may not be created yet"
  tag_status="v$tag_version (stale)"
fi

# --- Count individual format targets in Makefile ---
format_count=$(grep -cE '^(md-pt|md-en|md-sg|docx-pt|docx-en|docx-sg|html-pt|html-en|html-sg):' "$MAKEFILE")
if [ "$format_count" -ne 9 ]; then
  echo "FAIL: expected 9 format targets, found $format_count"
  exit 1
fi

# --- Success ---
echo "OK: versions synchronized (cls=$cls_version, setup-guide=$sg_version, tag=$tag_status, format targets=9)"
