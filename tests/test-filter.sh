#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# v6.0.0: Lua filters may be removed in favor of AsciiDoc pipeline.
# Skip gracefully if the shared filter is gone.
if [ ! -f "$REPO_ROOT/templates/_base/pandoc-common.lua" ]; then
    echo "SKIP: Lua filters removed in v6.0.0"
    exit 0
fi

PASS=0; FAIL=0

# Auto-discover templates
for tmpl_dir in "$REPO_ROOT"/templates/*/; do
    tmpl_name=$(basename "$tmpl_dir")
    [ "$tmpl_name" = "_base" ] && continue
    [ ! -f "$tmpl_dir/${tmpl_name}.cls" ] && continue

    FILTER="$REPO_ROOT/templates/${tmpl_name}/${tmpl_name}-pandoc.lua"
    echo "=== ${tmpl_name} filter (${tmpl_name}-pandoc.lua) ==="
    TMPL_PASS=0; TMPL_FAIL=0

    for tex_file in "$REPO_ROOT"/tests/cases/*.tex; do
        name=$(basename "$tex_file" .tex)
        expected="$REPO_ROOT/tests/expected/$name.md.expected"
        if [ ! -f "$expected" ]; then
            echo "SKIP: $name (no expected output)"
            continue
        fi
        # Skip template-specific test cases for wrong filter
        first_line=$(head -1 "$tex_file" 2>/dev/null)
        if echo "$first_line" | grep -qE '% (guide|technical|tech|testbook)-only'; then
            test_marker=$(echo "$first_line" | grep -oE '(guide|technical|tech|testbook)-only' | sed 's/-only//')
            # Normalize "tech" to "technical" for comparison
            [ "$test_marker" = "tech" ] && test_marker="technical"
            if [ "$test_marker" != "$tmpl_name" ]; then
                echo "SKIP: $name ($test_marker-only)"
                continue
            fi
        fi
        actual=$(pandoc -f latex+raw_tex --lua-filter="$FILTER" -t markdown --wrap=none "$tex_file" 2>/dev/null)
        if [ "$actual" = "$(cat "$expected")" ]; then
            echo "PASS: $name"
            TMPL_PASS=$((TMPL_PASS + 1))
        else
            echo "FAIL: $name"
            diff <(cat "$expected") <(echo "$actual") | head -10
            TMPL_FAIL=$((TMPL_FAIL + 1))
        fi
    done

    echo ""
    echo "${tmpl_name} filter results: $TMPL_PASS passed, $TMPL_FAIL failed"
    PASS=$((PASS + TMPL_PASS))
    FAIL=$((FAIL + TMPL_FAIL))
done

echo ""
echo "Total results: $PASS passed, $FAIL failed"
exit $FAIL
