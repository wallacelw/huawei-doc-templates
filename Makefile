# Makefile — build convenience for Huawei Document Templates
# ============================================================================
# Self-documenting: run `make` (no arguments) to list all available targets.
# Source: AsciiDoc (.adoc) → LaTeX (.tex) via huawei-latex converter → PDF via XeLaTeX
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

all: samples setup-guide all-formats ## Compile everything (samples + setup-guide + all formats)

samples: $(TEMPLATE_SAMPLES) ## Compile all samples (all templates, PT + EN)

setup-guide: ## Compile the setup-guide (PDF only; use all-formats for DOCX/MD/HTML)
	./scripts/build-adoc.sh documents/setup-guide/src/setup-guide.adoc
	cd documents/setup-guide/src && latexmk setup-guide.tex

# ── Per-template rules (auto-generated via eval) ─────────────────────────────
# Each template gets: <t>-pt, <t>-en, <t>-samples,
#   <t>-md-pt, <t>-md-en, <t>-md, <t>-docx-pt, <t>-docx-en, <t>-docx,
#   <t>-html-pt, <t>-html-en, <t>-html, <t>-formats

define TEMPLATE_RULES
$(1)-md-pt:   ; ./scripts/build.sh --md documents/$(1)-pt
$(1)-md-en:   ; ./scripts/build.sh --md documents/$(1)-en
$(1)-docx-pt: ; ./scripts/build.sh --docx documents/$(1)-pt
$(1)-docx-en: ; ./scripts/build.sh --docx documents/$(1)-en
$(1)-html-pt: ; ./scripts/build.sh --html documents/$(1)-pt
$(1)-html-en: ; ./scripts/build.sh --html documents/$(1)-en

$(1)-md:   $(1)-md-pt $(1)-md-en   ; @true
$(1)-docx: $(1)-docx-pt $(1)-docx-en ; @true
$(1)-html: $(1)-html-pt $(1)-html-en ; @true
$(1)-formats: $(1)-md $(1)-docx $(1)-html ; @true

$(1)-pt: ; ./scripts/build-adoc.sh documents/$(1)-pt/src/main.adoc && cd documents/$(1)-pt/src && latexmk main.tex
$(1)-en: ; ./scripts/build-adoc.sh documents/$(1)-en/src/main.adoc && cd documents/$(1)-en/src && latexmk main.tex
$(1)-samples: $(1)-pt $(1)-en ; @true
endef

$(foreach tmpl,$(TEMPLATES),$(eval $(call TEMPLATE_RULES,$(tmpl))))

# ── Per-template clean rules (auto-generated via eval) ───────────────────────
# Each template gets: clean-<t>-pt, clean-<t>-en, clean-<t>-samples

define TEMPLATE_CLEAN_RULES
clean-$(1)-pt: ; cd documents/$(1)-pt/src && latexmk -C main.tex; rm -f documents/$(1)-pt/src/main.tex documents/$(1)-pt/main.pdf
clean-$(1)-en: ; cd documents/$(1)-en/src && latexmk -C main.tex; rm -f documents/$(1)-en/src/main.tex documents/$(1)-en/main.pdf
clean-$(1)-samples: clean-$(1)-pt clean-$(1)-en ; @true
endef

$(foreach tmpl,$(TEMPLATES),$(eval $(call TEMPLATE_CLEAN_RULES,$(tmpl))))

# ============================================================================
##@ Setup guide (uses guide template, lives at documents/setup-guide/)
# ============================================================================

md-sg:   ; ./scripts/build.sh --md documents/setup-guide
docx-sg: ; ./scripts/build.sh --docx documents/setup-guide
html-sg: ; ./scripts/build.sh --html documents/setup-guide

# ============================================================================
##@ Multi-format output (DOCX, Markdown, HTML via Pandoc)
# ============================================================================

all-formats: $(TEMPLATE_FORMATS) md-sg docx-sg html-sg ## Generate all formats (DOCX+MD+HTML) for all samples + setup-guide

md:   $(foreach tmpl,$(TEMPLATES),$(tmpl)-md) md-sg   ## Markdown for all samples + setup-guide
docx: $(foreach tmpl,$(TEMPLATES),$(tmpl)-docx) docx-sg ## DOCX for all samples + setup-guide
html: $(foreach tmpl,$(TEMPLATES),$(tmpl)-html) html-sg ## HTML for all samples + setup-guide

# ============================================================================
##@ Generic project compilation
# ============================================================================

technical: ## Compile a specific technical report (make technical DIR=<path-with-src>)
	@if [ -z "$(DIR)" ]; then echo "Usage: make technical DIR=<path-with-src>"; exit 1; fi
	@./scripts/build-adoc.sh $(DIR)/src/main.adoc
	@cd $(DIR)/src && latexmk main.tex

project: ## Compile a specific project (make project DIR=<path> [FILE=<name>.adoc])
	@if [ -z "$(DIR)" ]; then echo "Usage: make project DIR=<path> [FILE=<name>.adoc]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		ADOC=$$(ls $(DIR)/src/*.adoc 2>/dev/null | head -1); \
		if [ -z "$$ADOC" ]; then ADOC=$$(ls $(DIR)/*.adoc 2>/dev/null | head -1); fi; \
		if [ -z "$$ADOC" ]; then echo "No .adoc file found in $(DIR)/src/ or $(DIR)/"; exit 1; fi; \
		echo "Compiling $$ADOC"; \
		./scripts/build-adoc.sh "$$ADOC"; \
		cd $$(dirname "$$ADOC") && latexmk $$(basename "$${ADOC%.adoc}.tex"); \
	else \
		echo "Compiling $(DIR)/$(FILE)"; \
		./scripts/build-adoc.sh $(DIR)/src/$(FILE); \
		cd $(DIR)/src && latexmk $$(basename $${FILE%.adoc}.tex); \
	fi

menu: ## Interactive format menu (delegates to build.sh)
	./scripts/build.sh

# ============================================================================
##@ Live editing
# ============================================================================

# ── Preview (HTML in browser) ──
preview: ## Preview document as HTML in browser (make preview DIR=documents/guide-en)
	@dir="$(DIR)"; \
	adoc=""; \
	if [ -f "$$dir/src/main.adoc" ]; then adoc="$$dir/src/main.adoc"; \
	elif [ -f "$$dir/src/setup-guide.adoc" ]; then adoc="$$dir/src/setup-guide.adoc"; \
	elif [ -f "$$dir/main.adoc" ]; then adoc="$$dir/main.adoc"; fi; \
	if [ -z "$$adoc" ]; then echo "Error: No .adoc file found in $$dir/src/"; exit 1; fi; \
	out="/tmp/huawei-preview.html"; \
	echo "Generating HTML preview from $$adoc..."; \
	asciidoctor -b html5 \
	  -a stylesheet=$(CURDIR)/templates/_base/huawei.css \
	  -a docinfodir=$(CURDIR)/templates/_base \
	  -a docinfo1 \
	  -r asciidoctor-diagram \
	  "$$adoc" -o "$$out" 2>&1; \
	echo "Opening $$out..."; \
	xdg-open "$$out" 2>/dev/null || open "$$out" 2>/dev/null || echo "Open manually: $$out"

# ── Watch (recompile on save) ──
watch: ## Watch .adoc and recompile PDF on save (make watch DIR=documents/guide-en)
	@./scripts/watch.sh "$(DIR)"

# ============================================================================
##@ Testing
# ============================================================================

test: ## Run all tests (filter units, round-trip, DOCX fix, version sync, converter)
	./tests/test-filter.sh
	./tests/test-preprocessor.sh
	./tests/round-trip.sh
	./tests/test-docx-fix.sh
	./tests/test-sync.sh
	./tests/test-converter.sh

test-converter: ## Run converter unit tests only
	./tests/test-converter.sh

# ============================================================================
##@ Cleanup
# ============================================================================

TEMPLATE_CLEAN_SAMPLES := $(foreach tmpl,$(TEMPLATES),clean-$(tmpl)-samples)

clean: $(TEMPLATE_CLEAN_SAMPLES) clean-setup-guide clean-formats ## Remove all build artifacts

clean-setup-guide: ## Clean the setup-guide
	cd documents/setup-guide/src && latexmk -C setup-guide.tex
	rm -f documents/setup-guide/src/setup-guide.tex documents/setup-guide/setup-guide.pdf

clean-formats: ## Remove generated multi-format files (DOCX/MD/HTML)
	@for tmpl_dir in templates/*/; do \
		tmpl=$$(basename "$$tmpl_dir"); \
		[ "$$tmpl" = "_base" ] && continue; \
		[ ! -f "$$tmpl_dir/$$tmpl.cls" ] && continue; \
		for lang in pt en; do \
			rm -f documents/$$tmpl-$$lang/main.docx documents/$$tmpl-$$lang/main.md documents/$$tmpl-$$lang/main.html 2>/dev/null; \
		done; \
	done
	rm -f documents/setup-guide/setup-guide.docx documents/setup-guide/setup-guide.md documents/setup-guide/setup-guide.html

clean-project: ## Clean a specific project (make clean-project DIR=<path> [FILE=<name>.adoc])
	@if [ -z "$(DIR)" ]; then echo "Usage: make clean-project DIR=<path> [FILE=<name>.adoc]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		ADOC=$$(ls $(DIR)/src/*.adoc 2>/dev/null | head -1); \
		if [ -z "$$ADOC" ]; then ADOC=$$(ls $(DIR)/*.adoc 2>/dev/null | head -1); fi; \
		if [ -z "$$ADOC" ]; then echo "No .adoc file found in $(DIR)/src/ or $(DIR)/"; exit 1; fi; \
		TEXFILE="$${ADOC%.adoc}.tex"; \
		cd $$(dirname "$$ADOC") && latexmk -C $$(basename "$$TEXFILE"); \
		rm -f "$$TEXFILE"; \
	else \
		TEXFILE="$$(basename ${FILE%.adoc}.tex)"; \
		cd $(DIR)/src && latexmk -C "$$TEXFILE"; \
		rm -f "$$TEXFILE"; \
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

.PHONY: help all samples setup-guide project menu preview watch
.PHONY: $(TEMPLATE_PHONY)
.PHONY: technical
.PHONY: test test-converter
.PHONY: clean clean-setup-guide clean-project clean-formats
.PHONY: $(TEMPLATE_CLEAN_PHONY)
# Setup guide format targets
.PHONY: md-sg docx-sg html-sg
# Aggregate format targets
.PHONY: md docx html all-formats
