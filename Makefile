# Makefile — build convenience for Huawei Document Templates
# ============================================================================
# Self-documenting: run `make` (no arguments) to list all available targets.
# Engine: XeLaTeX (via latexmk, $pdf_mode=5). pdflatex will NOT work.
# Templates are auto-discovered from templates/*/ directories.
# ============================================================================

# Bare `make` shows help instead of building everything.
.DEFAULT_GOAL := help

# ── Auto-discover templates ──────────────────────────────────────────────────
# Scans templates/*/ for directories (excluding _base) and generates
# per-template build targets automatically. Adding a new template =
# create templates/<name>/ — zero Makefile changes needed.
TEMPLATES := $(filter-out _base,$(patsubst templates/%/,%,$(wildcard templates/*/)))

# ============================================================================
##@ Help
# ============================================================================

help: ## Show this help message
	@if [ -t 1 ]; then B=$$(printf '\033[1m'); C=$$(printf '\033[36m'); R=$$(printf '\033[0m'); \
	else B=""; C=""; R=""; fi; \
	printf "Huawei Document Templates — build convenience\n"; \
	printf "Engine: XeLaTeX (latexmk). Run 'make <target>' to build.\n"; \
	printf "Templates: $(TEMPLATES)\n\n"; \
	awk -v B="$$B" -v C="$$C" -v R="$$R" 'BEGIN {FS = ":.*##"} \
	    /^##@/ { printf "\n%s%s%s\n", B, substr($$0, 5), R } \
	    /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %s%-22s%s %s\n", C, $$1, R, $$2 }' $(MAKEFILE_LIST)

# ============================================================================
##@ Build (PDF via XeLaTeX)
# ============================================================================

TEMPLATE_SAMPLES := $(foreach tmpl,$(TEMPLATES),$(tmpl)-samples)
TEMPLATE_FORMATS := $(foreach tmpl,$(TEMPLATES),$(tmpl)-formats)

all: samples examples all-formats ## Compile everything (samples + setup-guide + all formats)

samples: $(TEMPLATE_SAMPLES) ## Compile all samples (all templates, PT + EN)

examples: setup-guide ## Compile the setup-guide and copy its PDF to repo root

setup-guide: ## Compile the setup-guide and copy its PDF to repo root
	cd examples/setup-guide/src && latexmk setup-guide.tex
	cp examples/setup-guide/setup-guide.pdf setup-guide.pdf

# ── Per-template rules (auto-generated via eval) ─────────────────────────────
# Each template gets: <t>-pt, <t>-en, <t>-samples,
#   <t>-md-pt, <t>-md-en, <t>-md, <t>-docx-pt, <t>-docx-en, <t>-docx,
#   <t>-html-pt, <t>-html-en, <t>-html, <t>-formats

define TEMPLATE_RULES
$(1)-md-pt:   ; ./build.sh --md examples/$(1)/pt
$(1)-md-en:   ; ./build.sh --md examples/$(1)/en
$(1)-docx-pt: ; ./build.sh --docx examples/$(1)/pt
$(1)-docx-en: ; ./build.sh --docx examples/$(1)/en
$(1)-html-pt: ; ./build.sh --html examples/$(1)/pt
$(1)-html-en: ; ./build.sh --html examples/$(1)/en

$(1)-md:   $(1)-md-pt $(1)-md-en   ; @true
$(1)-docx: $(1)-docx-pt $(1)-docx-en ; @true
$(1)-html: $(1)-html-pt $(1)-html-en ; @true
$(1)-formats: $(1)-md $(1)-docx $(1)-html ; @true

$(1)-pt: ; cd examples/$(1)/pt/src && latexmk main.tex
$(1)-en: ; cd examples/$(1)/en/src && latexmk main.tex
$(1)-samples: $(1)-pt $(1)-en ; @true
endef

$(foreach tmpl,$(TEMPLATES),$(eval $(call TEMPLATE_RULES,$(tmpl))))

# ── Per-template clean rules (auto-generated via eval) ───────────────────────
# Each template gets: clean-<t>-pt, clean-<t>-en, clean-<t>-samples

define TEMPLATE_CLEAN_RULES
clean-$(1)-pt: ; cd examples/$(1)/pt/src && latexmk -C main.tex; rm -f examples/$(1)/pt/main.pdf
clean-$(1)-en: ; cd examples/$(1)/en/src && latexmk -C main.tex; rm -f examples/$(1)/en/main.pdf
clean-$(1)-samples: clean-$(1)-pt clean-$(1)-en ; @true
endef

$(foreach tmpl,$(TEMPLATES),$(eval $(call TEMPLATE_CLEAN_RULES,$(tmpl))))

# ============================================================================
##@ Legacy guide aliases (backward compat — guide targets have no prefix)
# ============================================================================

md-pt: guide-md-pt ; @true
md-en: guide-md-en ; @true
docx-pt: guide-docx-pt ; @true
docx-en: guide-docx-en ; @true
html-pt: guide-html-pt ; @true
html-en: guide-html-en ; @true
pt: guide-pt ; @true
en: guide-en ; @true

# ============================================================================
##@ Setup guide (uses guide template, lives at examples/setup-guide/)
# ============================================================================

md-sg:   ; ./build.sh --md examples/setup-guide
docx-sg: ; ./build.sh --docx examples/setup-guide
html-sg: ; ./build.sh --html examples/setup-guide

# ============================================================================
##@ Multi-format output (DOCX, Markdown, HTML via Pandoc)
# ============================================================================

all-formats: $(TEMPLATE_FORMATS) md-sg docx-sg html-sg ## Generate all formats (DOCX+MD+HTML) for all samples + setup-guide

md:   md-pt md-en md-sg   ## Markdown for guide samples + setup-guide (use all-formats for all templates)
docx: docx-pt docx-en docx-sg ## DOCX for guide samples + setup-guide (use all-formats for all templates)
html: html-pt html-en html-sg ## HTML for guide samples + setup-guide (use all-formats for all templates)

# ============================================================================
##@ Generic project compilation
# ============================================================================

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

TEMPLATE_CLEAN_SAMPLES := $(foreach tmpl,$(TEMPLATES),clean-$(tmpl)-samples)

clean: $(TEMPLATE_CLEAN_SAMPLES) clean-examples clean-formats ## Remove all build artifacts

clean-examples: clean-setup-guide ## Clean the setup-guide

clean-setup-guide: ## Clean the setup-guide and the repo-root PDF copy
	cd examples/setup-guide/src && latexmk -C setup-guide.tex
	rm -f examples/setup-guide/setup-guide.pdf setup-guide.pdf

clean-formats: ## Remove generated multi-format files (DOCX/MD/HTML)
	@for tmpl_dir in templates/*/; do \
		tmpl=$$(basename "$$tmpl_dir"); \
		[ "$$tmpl" = "_base" ] && continue; \
		[ ! -f "$$tmpl_dir/$$tmpl.cls" ] && continue; \
		for lang in pt en; do \
			rm -f examples/$$tmpl/$$lang/main.docx examples/$$tmpl/$$lang/main.md examples/$$tmpl/$$lang/main.html 2>/dev/null; \
		done; \
	done
	rm -f examples/setup-guide/setup-guide.docx examples/setup-guide/setup-guide.md examples/setup-guide/setup-guide.html

# Legacy clean aliases (backward compat)
clean-pt: clean-guide-pt ; @true
clean-en: clean-guide-en ; @true
clean-samples: clean-guide-samples ; @true

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

# Per-template phony targets (auto-generated)
TEMPLATE_PHONY := $(foreach tmpl,$(TEMPLATES), \
	$(tmpl)-pt $(tmpl)-en $(tmpl)-samples \
	$(tmpl)-md-pt $(tmpl)-md-en $(tmpl)-md \
	$(tmpl)-docx-pt $(tmpl)-docx-en $(tmpl)-docx \
	$(tmpl)-html-pt $(tmpl)-html-en $(tmpl)-html \
	$(tmpl)-formats)

# Per-template clean phony targets (auto-generated)
TEMPLATE_CLEAN_PHONY := $(foreach tmpl,$(TEMPLATES), \
	clean-$(tmpl)-pt clean-$(tmpl)-en clean-$(tmpl)-samples)

.PHONY: help all samples examples setup-guide project menu
.PHONY: $(TEMPLATE_PHONY)
.PHONY: technical
.PHONY: test
.PHONY: clean clean-examples clean-setup-guide clean-project clean-formats
.PHONY: $(TEMPLATE_CLEAN_PHONY)
# Legacy clean aliases
.PHONY: clean-pt clean-en clean-samples
# Legacy guide aliases
.PHONY: md-pt md-en docx-pt docx-en html-pt html-en pt en
# Setup guide format targets
.PHONY: md-sg docx-sg html-sg
# Aggregate format targets
.PHONY: md docx html all-formats
