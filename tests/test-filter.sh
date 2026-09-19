#!/bin/bash
set -euo pipefail

# v6.0.0: Lua filters are legacy — superseded by huawei-latex-converter.rb.
# This script is a SKIP stub; the active pipeline is asciidoctor -b docbook → pandoc -f docbook.
echo "SKIP: Lua filter tests are legacy (superseded by huawei-latex-converter.rb in v6.0.0)"
exit 0
