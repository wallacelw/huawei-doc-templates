#!/usr/bin/env bash
set -euo pipefail

# test-sync.sh — verify version synchronization across the project
# Checks:
#   1. guide.cls version == setup-guide \setdocversion
#   2. guide.cls version == latest git tag (if tags exist)
#   3. All template .cls versions match guide.cls version
#   4. Makefile has format targets for each template

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLS_FILE="$REPO_ROOT/templates/guide/guide.cls"
TEX_FILE="$REPO_ROOT/examples/setup-guide/src/setup-guide.tex"
ADOC_FILE="$REPO_ROOT/examples/setup-guide/src/setup-guide.adoc"
MAKEFILE="$REPO_ROOT/Makefile"

# --- Extract cls version from \ProvidesClass line ---
cls_version=$(grep -oP '\\ProvidesClass\{guide\}\[.*?v\K[0-9]+\.[0-9]+\.[0-9]+' "$CLS_FILE")
if [ -z "$cls_version" ]; then
  echo "FAIL: could not extract version from $CLS_FILE"
  exit 1
fi

# --- Extract setup-guide version ---
# v6.0.0: prefer .adoc header attribute (:version: X.Y.Z), fall back to .tex
if [ -f "$ADOC_FILE" ]; then
  sg_version=$(grep '^:version:' "$ADOC_FILE" | head -1 | sed 's/:version: *//')
  sg_source="$ADOC_FILE"
elif [ -f "$TEX_FILE" ]; then
  sg_version=$(grep -oP '\\setdocversion\{\K[0-9]+\.[0-9]+\.[0-9]+' "$TEX_FILE")
  sg_source="$TEX_FILE"
else
  echo "FAIL: neither $ADOC_FILE nor $TEX_FILE found"
  exit 1
fi
if [ -z "$sg_version" ]; then
  echo "FAIL: could not extract version from $sg_source"
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

# --- Check cls version vs git tag version (FAIL — tag must match cls) ---
tag_status="v$tag_version"
if [ -z "$tag_version" ]; then
  echo "WARN: no git tags found — skipping tag check"
  tag_status="none"
elif [ "$cls_version" != "$tag_version" ]; then
  echo "FAIL: cls version ($cls_version) != git tag version ($tag_version)"
  exit 1
fi

# --- Validate format targets exist for each template's samples ---
# Auto-discover templates from templates/*/ directories
# Use make -n to check targets (eval-generated rules aren't visible via grep)
format_target_count=0
for tmpl_dir in "$REPO_ROOT"/templates/*/; do
    tmpl=$(basename "$tmpl_dir")
    [ "$tmpl" = "_base" ] && continue
    [ ! -f "$tmpl_dir/${tmpl}.cls" ] && continue

    for fmt in md docx html; do
        for lang in pt en; do
            target="${tmpl}-${fmt}-${lang}"
            if ! make -C "$REPO_ROOT" -n "$target" >/dev/null 2>&1; then
                echo "FAIL: missing format target '$target' in Makefile"
                exit 1
            fi
            format_target_count=$((format_target_count + 1))
        done
    done
done

# Setup-guide targets (no prefix, -sg suffix)
for fmt in md docx html; do
    target="${fmt}-sg"
    if ! make -C "$REPO_ROOT" -n "$target" >/dev/null 2>&1; then
        echo "FAIL: missing setup-guide format target '$target' in Makefile"
        exit 1
    fi
    format_target_count=$((format_target_count + 1))
done

# --- Check all template .cls versions match ---
for tmpl_dir in "$REPO_ROOT"/templates/*/; do
    tmpl_name=$(basename "$tmpl_dir")
    [ "$tmpl_name" = "_base" ] && continue
    [ ! -f "$tmpl_dir/${tmpl_name}.cls" ] && continue

    tmpl_cls_version=$(grep -oP '\\ProvidesClass\{'"${tmpl_name}"'\}\[.*?v\K[0-9]+\.[0-9]+\.[0-9]+' "$tmpl_dir/${tmpl_name}.cls")
    if [ -z "$tmpl_cls_version" ]; then
        echo "FAIL: could not extract version from $tmpl_dir/${tmpl_name}.cls"
        exit 1
    fi
    if [ "$tmpl_cls_version" != "$cls_version" ]; then
        echo "FAIL: ${tmpl_name}.cls version ($tmpl_cls_version) != guide.cls version ($cls_version)"
        exit 1
    fi
done

# --- Success ---
echo "OK: versions synchronized (cls=$cls_version, setup-guide=$sg_version, tag=$tag_status, format targets=$format_target_count)"
