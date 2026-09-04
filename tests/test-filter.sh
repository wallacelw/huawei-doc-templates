#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

# ── Guide filter tests ──────────────────────────────────────────────────────
echo "=== Guide filter (guide-pandoc.lua) ==="
GUIDE_FILTER="$REPO_ROOT/templates/guide/guide-pandoc.lua"
TESTS_DIR="$REPO_ROOT/tests"
GUIDE_PASS=0; GUIDE_FAIL=0

for tex_file in "$TESTS_DIR/cases/"*.tex; do
  name=$(basename "$tex_file" .tex)
  expected="$TESTS_DIR/expected/$name.md.expected"
  if [ ! -f "$expected" ]; then
    echo "SKIP: $name (no expected output)"
    continue
  fi
  actual=$(pandoc -f latex+raw_tex --lua-filter="$GUIDE_FILTER" -t markdown --wrap=none "$tex_file" 2>/dev/null)
  if [ "$actual" = "$(cat "$expected")" ]; then
    echo "PASS: $name"
    GUIDE_PASS=$((GUIDE_PASS + 1))
  else
    echo "FAIL: $name"
    diff <(cat "$expected") <(echo "$actual") | head -10
    GUIDE_FAIL=$((GUIDE_FAIL + 1))
  fi
done

echo ""
echo "Guide filter results: $GUIDE_PASS passed, $GUIDE_FAIL failed"
PASS=$((PASS + GUIDE_PASS))
FAIL=$((FAIL + GUIDE_FAIL))

# ── Technical filter tests ──────────────────────────────────────────────────
echo ""
echo "=== Technical filter (technical-pandoc.lua) ==="
TECH_FILTER="$REPO_ROOT/templates/technical/technical-pandoc.lua"
TECH_PASS=0; TECH_FAIL=0

for tex_file in "$TESTS_DIR/cases/"*.tex; do
  name=$(basename "$tex_file" .tex)
  expected="$TESTS_DIR/expected/$name.md.expected"
  if [ ! -f "$expected" ]; then
    echo "SKIP: $name (no expected output)"
    continue
  fi
  actual=$(pandoc -f latex+raw_tex --lua-filter="$TECH_FILTER" -t markdown --wrap=none "$tex_file" 2>/dev/null)
  if [ "$actual" = "$(cat "$expected")" ]; then
    echo "PASS: $name"
    TECH_PASS=$((TECH_PASS + 1))
  else
    echo "FAIL: $name"
    diff <(cat "$expected") <(echo "$actual") | head -10
    TECH_FAIL=$((TECH_FAIL + 1))
  fi
done

echo ""
echo "Technical filter results: $TECH_PASS passed, $TECH_FAIL failed"
PASS=$((PASS + TECH_PASS))
FAIL=$((FAIL + TECH_FAIL))

echo ""
echo "Total results: $PASS passed, $FAIL failed"
exit $FAIL
