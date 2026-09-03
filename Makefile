# Makefile — build convenience for Huawei Document Templates
# ============================================================================
# Self-documenting: run `make` (no arguments) to list all available targets.
# Engine: XeLaTeX (via latexmk, $pdf_mode=5). pdflatex will NOT work.
# ============================================================================

# Bare `make` shows help instead of building everything.
.DEFAULT_GOAL := help

PT_DIR = examples/guide/pt
EN_DIR = examples/guide/en
SG_DIR = examples/setup-guide
TECHNICAL_PT = examples/technical/pt
TECHNICAL_EN = examples/technical/en

# ============================================================================
##@ Help
# ============================================================================

help: ## Show this help message
	@if [ -t 1 ]; then B=$$(printf '\033[1m'); C=$$(printf '\033[36m'); R=$$(printf '\033[0m'); \
	else B=""; C=""; R=""; fi; \
	printf "Huawei Document Templates — build convenience\n"; \
	printf "Engine: XeLaTeX (latexmk). Run 'make <target>' to build.\n\n"; \
	awk -v B="$$B" -v C="$$C" -v R="$$R" 'BEGIN {FS = ":.*##"} \
	    /^##@/ { printf "\n%s%s%s\n", B, substr($$0, 5), R } \
	    /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %s%-22s%s %s\n", C, $$1, R, $$2 }' $(MAKEFILE_LIST)

# ============================================================================
##@ Build (PDF via XeLaTeX)
# ============================================================================

all: samples examples technical-samples all-formats ## Compile everything (samples + setup-guide + technical reports (PDF) + all formats)

samples: pt en ## Compile both guide samples (PT + EN)

examples: setup-guide ## Compile the setup-guide and copy its PDF to repo root

technical-samples: technical-pt technical-en ## Generate technical report samples (PT + EN, PDF)

pt: ## Compile the Portuguese sample
	cd $(PT_DIR)/src && latexmk main.tex

en: ## Compile the English sample
	cd $(EN_DIR)/src && latexmk main.tex

setup-guide: ## Compile the setup-guide and copy its PDF to repo root
	cd $(SG_DIR)/src && latexmk setup-guide.tex
	cp $(SG_DIR)/setup-guide.pdf setup-guide.pdf

# ============================================================================
##@ Technical reports (PDF via XeLaTeX)
# ============================================================================

technical-pt: ## Compile the Portuguese technical report (PDF)
	cd $(TECHNICAL_PT)/src && latexmk main.tex

technical-en: ## Compile the English technical report (PDF)
	cd $(TECHNICAL_EN)/src && latexmk main.tex

technical: ## Compile a specific technical report (make technical DIR=<path-with-src>)
	@if [ -z "$(DIR)" ]; then echo "Usage: make technical DIR=<path-with-src>"; exit 1; fi
	@cd $(DIR)/src && latexmk main.tex

project: ## Compile a specific project (make project DIR=<path> [FILE=<name>.tex])
	@if [ -z "$(DIR)" ]; then echo "Usage: make project DIR=<path> [FILE=<name>.tex]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		TEX=$$(ls $(DIR)/src/*.tex 2>/dev/null | head -1); \
		if [ -z "$$TEX" ]; then TEX=$$(ls $(DIR)/*.tex 2>/dev/null | head -1); fi; \
		if [ -z "$$TEX" ]; then echo "No .tex file found in $(DIR)/src/ or $(DIR)/"; exit 1; fi; \
		echo "Compiling $$TEX"; \
		cd $$(dirname $$TEX) && latexmk $$(basename $$TEX); \
	else \
		echo "Compiling $(DIR)/$(FILE)"; \
		cd $(DIR)/src && latexmk $(FILE); \
	fi

menu: ## Interactive format menu (delegates to build.sh)
	./build.sh

# ============================================================================
##@ Multi-format output (DOCX, Markdown, HTML via Pandoc)
# ============================================================================

all-formats: docx md html technical-formats ## Generate all formats (DOCX+MD+HTML) for all samples + setup-guide

md:   md-pt md-en md-sg   ## Markdown for both samples + setup-guide
docx: docx-pt docx-en docx-sg ## DOCX for both samples + setup-guide
html: html-pt html-en html-sg ## HTML for both samples + setup-guide

# Per-sample format targets (advanced — not shown in help summary)
md-pt:     ; ./build.sh --md examples/guide/pt
md-en:     ; ./build.sh --md examples/guide/en
md-sg:     ; ./build.sh --md $(SG_DIR)
docx-pt:   ; ./build.sh --docx examples/guide/pt
docx-en:   ; ./build.sh --docx examples/guide/en
docx-sg:   ; ./build.sh --docx $(SG_DIR)
html-pt:   ; ./build.sh --html examples/guide/pt
html-en:   ; ./build.sh --html examples/guide/en
html-sg:   ; ./build.sh --html $(SG_DIR)

# Technical report multi-format targets (use technical-pandoc.lua + technical-template.html)
TECH_FILTER = templates/technical/technical-pandoc.lua
TECH_REFDOCX = templates/technical/technical-reference.docx
TECH_HTML = templates/technical/technical-template.html

technical-formats: technical-docx technical-md technical-html ## Generate all formats (DOCX+MD+HTML) for technical samples

technical-md: technical-md-pt technical-md-en ## Markdown for both technical samples
technical-docx: technical-docx-pt technical-docx-en ## DOCX for both technical samples
technical-html: technical-html-pt technical-html-en ## HTML for both technical samples

technical-md-pt:    ; pandoc --lua-filter=$(TECH_FILTER) -f latex+raw_tex -t markdown examples/technical/pt/src/main.tex -o examples/technical/pt/main.md
technical-md-en:    ; pandoc --lua-filter=$(TECH_FILTER) -f latex+raw_tex -t markdown examples/technical/en/src/main.tex -o examples/technical/en/main.md
technical-docx-pt:  ; pandoc --lua-filter=$(TECH_FILTER) --reference-doc=$(TECH_REFDOCX) -f latex+raw_tex -t docx examples/technical/pt/src/main.tex -o examples/technical/pt/main.docx
technical-docx-en:  ; pandoc --lua-filter=$(TECH_FILTER) --reference-doc=$(TECH_REFDOCX) -f latex+raw_tex -t docx examples/technical/en/src/main.tex -o examples/technical/en/main.docx
technical-html-pt:  ; pandoc --lua-filter=$(TECH_FILTER) --template=$(TECH_HTML) -f latex+raw_tex -t html5 --standalone examples/technical/pt/src/main.tex -o examples/technical/pt/main.html
technical-html-en:  ; pandoc --lua-filter=$(TECH_FILTER) --template=$(TECH_HTML) -f latex+raw_tex -t html5 --standalone examples/technical/en/src/main.tex -o examples/technical/en/main.html

# ============================================================================
##@ Testing
# ============================================================================

test: ## Run all tests (filter units, round-trip, DOCX fix, version sync)
	./tests/test-filter.sh
	./tests/round-trip.sh
	./tests/test-docx-fix.sh
	./tests/test-sync.sh

# ============================================================================
##@ Cleanup
# ============================================================================

clean: clean-samples clean-examples clean-formats ## Remove all build artifacts

clean-samples: clean-pt clean-en ## Clean both guide samples

clean-examples: clean-setup-guide ## Clean the setup-guide

clean-pt: ## Clean the Portuguese sample
	cd $(PT_DIR)/src && latexmk -C main.tex
	rm -f $(PT_DIR)/main.pdf

clean-en: ## Clean the English sample
	cd $(EN_DIR)/src && latexmk -C main.tex
	rm -f $(EN_DIR)/main.pdf

clean-setup-guide: ## Clean the setup-guide and the repo-root PDF copy
	cd $(SG_DIR)/src && latexmk -C setup-guide.tex
	rm -f $(SG_DIR)/setup-guide.pdf setup-guide.pdf

clean-formats: ## Remove generated multi-format files (DOCX/MD/HTML)
	rm -f examples/guide/pt/main.docx examples/guide/pt/main.md examples/guide/pt/main.html
	rm -f examples/guide/en/main.docx examples/guide/en/main.md examples/guide/en/main.html
	rm -f $(SG_DIR)/setup-guide.docx $(SG_DIR)/setup-guide.md $(SG_DIR)/setup-guide.html
	rm -f examples/technical/pt/main.docx examples/technical/pt/main.md examples/technical/pt/main.html
	rm -f examples/technical/en/main.docx examples/technical/en/main.md examples/technical/en/main.html

clean-project: ## Clean a specific project (make clean-project DIR=<path> [FILE=<name>.tex])
	@if [ -z "$(DIR)" ]; then echo "Usage: make clean-project DIR=<path> [FILE=<name>.tex]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		TEX=$$(ls $(DIR)/src/*.tex 2>/dev/null | head -1); \
		if [ -z "$$TEX" ]; then TEX=$$(ls $(DIR)/*.tex 2>/dev/null | head -1); fi; \
		if [ -z "$$TEX" ]; then echo "No .tex file found in $(DIR)/src/ or $(DIR)/"; exit 1; fi; \
		cd $$(dirname $$TEX) && latexmk -C $$(basename $$TEX); \
	else \
		cd $(DIR)/src && latexmk -C $(FILE); \
	fi

# ============================================================================
# Phony declarations
# ============================================================================

.PHONY: help all samples examples pt en setup-guide project menu
.PHONY: technical-samples technical-pt technical-en technical
.PHONY: technical-formats technical-docx technical-md technical-html
.PHONY: technical-docx-pt technical-docx-en technical-md-pt technical-md-en technical-html-pt technical-html-en
.PHONY: docx docx-pt docx-en docx-sg md md-pt md-en md-sg html html-pt html-en html-sg all-formats
.PHONY: test
.PHONY: clean clean-samples clean-examples clean-pt clean-en clean-setup-guide clean-project clean-formats
