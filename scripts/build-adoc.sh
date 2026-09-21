#!/usr/bin/env bash
# build-adoc.sh — Convert AsciiDoc (.adoc) to LaTeX (.tex) via huawei-latex converter
#
# Usage:
#   ./scripts/build-adoc.sh src/main.adoc              # outputs src/main.tex
#   ./scripts/build-adoc.sh src/main.adoc -o build.tex # custom output
#
# This script wraps the asciidoctor call with the huawei-latex backend.
# After conversion, run `latexmk main.tex` in the same directory to compile to PDF.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
CONVERTER="$REPO_ROOT/templates/_base/huawei-latex-converter.rb"

if [ ! -f "$CONVERTER" ]; then
  echo "Error: Converter not found at $CONVERTER" >&2
  exit 1
fi

command -v asciidoctor >/dev/null 2>&1 || {
  echo "Error: asciidoctor not installed. Run: gem install asciidoctor" >&2
  exit 1
}

INPUT=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT="$2"; shift 2
      ;;
    *)
      if [ -n "$INPUT" ]; then
        echo "Error: multiple input files specified. Use -o for output." >&2
        exit 1
      fi
      INPUT="$1"; shift
      ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <input.adoc> [-o output.tex]" >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "Error: Input file not found: $INPUT" >&2
  exit 1
fi

# Default output: same basename, .tex extension, in same directory
if [ -z "$OUTPUT" ]; then
  OUTPUT="${INPUT%.adoc}.tex"
fi

# PlantUML: use plantuml-native if available, otherwise set classpath
# (Don't set DIAGRAM_PLANTUML_CLASSPATH if plantuml-native exists — the system
# JAR may be incompatible with asciidoctor-diagram's internal preprocessor)
if ! command -v plantuml-native >/dev/null 2>&1; then
  if [ -f "/usr/share/plantuml/plantuml.jar" ]; then
    export DIAGRAM_PLANTUML_CLASSPATH="/usr/share/plantuml/plantuml.jar"
  fi
fi

# Run asciidoctor with the huawei-latex backend
# asciidoctor-diagram is optional (only needed for [plantuml]/[graphviz]/[mermaid] blocks)
DIAGRAM_OPTS=""
if gem list asciidoctor-diagram --installed >/dev/null 2>&1; then
  DIAGRAM_OPTS="-r asciidoctor-diagram"
fi

# Mermaid: mmdc should include --no-sandbox if running as root
# (configure via puppeteer-config.json or mmdc-safe wrapper)

# --failure-level WARN: fail the build on asciidoctor warnings (unresolved
# includes, malformed tables, dropped content) instead of silently omitting
# them from the PDF.
asciidoctor --failure-level WARN -b huawei-latex -r "$CONVERTER" $DIAGRAM_OPTS "$INPUT" -o "$OUTPUT"

echo "Generated: $OUTPUT"
