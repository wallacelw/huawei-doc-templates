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

all: samples examples all-formats ## Compile everything (samples + setup-guide + all formats)

samples: $(TEMPLATE_SAMPLES) ## Compile all samples (all templates, PT + EN)

examples: setup-guide ## Compile the setup-guide and copy all formats to setup-guide/

setup-guide: ## Compile the setup-guide and copy all formats to setup-guide/
	./scripts/build-adoc.sh examples/setup-guide/src/setup-guide.adoc
	cd examples/setup-guide/src && latexmk setup-guide.tex
	./scripts/build.sh --all examples/setup-guide
	cp examples/setup-guide/setup-guide.pdf  setup-guide/setup-guide.pdf
	cp examples/setup-guide/setup-guide.md   setup-guide/setup-guide.md
	cp examples/setup-guide/setup-guide.docx setup-guide/setup-guide.docx
	cp examples/setup-guide/setup-guide.html setup-guide/setup-guide.html

# ── Per-template rules (auto-generated via eval) ─────────────────────────────
# Each template gets: <t>-pt, <t>-en, <t>-samples,
#   <t>-md-pt, <t>-md-en, <t>-md, <t>-docx-pt, <t>-docx-en, <t>-docx,
#   <t>-html-pt, <t>-html-en, <t>-html, <t>-formats

define TEMPLATE_RULES
$(1)-md-pt:   ; ./scripts/build.sh --md examples/$(1)/pt
$(1)-md-en:   ; ./scripts/build.sh --md examples/$(1)/en
$(1)-docx-pt: ; ./scripts/build.sh --docx examples/$(1)/pt
$(1)-docx-en: ; ./scripts/build.sh --docx examples/$(1)/en
$(1)-html-pt: ; ./scripts/build.sh --html examples/$(1)/pt
$(1)-html-en: ; ./scripts/build.sh --html examples/$(1)/en

$(1)-md:   $(1)-md-pt $(1)-md-en   ; @true
$(1)-docx: $(1)-docx-pt $(1)-docx-en ; @true
$(1)-html: $(1)-html-pt $(1)-html-en ; @true
$(1)-formats: $(1)-md $(1)-docx $(1)-html ; @true

$(1)-pt: ; ./scripts/build-adoc.sh examples/$(1)/pt/src/main.adoc && cd examples/$(1)/pt/src && latexmk main.tex
$(1)-en: ; ./scripts/build-adoc.sh examples/$(1)/en/src/main.adoc && cd examples/$(1)/en/src && latexmk main.tex
$(1)-samples: $(1)-pt $(1)-en ; @true
endef

$(foreach tmpl,$(TEMPLATES),$(eval $(call TEMPLATE_RULES,$(tmpl))))

# ── Per-template clean rules (auto-generated via eval) ───────────────────────
# Each template gets: clean-<t>-pt, clean-<t>-en, clean-<t>-samples

define TEMPLATE_CLEAN_RULES
clean-$(1)-pt: ; cd examples/$(1)/pt/src && latexmk -C main.tex; rm -f examples/$(1)/pt/src/main.tex examples/$(1)/pt/main.pdf
clean-$(1)-en: ; cd examples/$(1)/en/src && latexmk -C main.tex; rm -f examples/$(1)/en/src/main.tex examples/$(1)/en/main.pdf
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

md-sg:   ; ./scripts/build.sh --md examples/setup-guide
docx-sg: ; ./scripts/build.sh --docx examples/setup-guide
html-sg: ; ./scripts/build.sh --html examples/setup-guide

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
preview: ## Preview document as HTML in browser (make preview DIR=examples/guide/en)
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
watch: ## Watch .adoc and recompile PDF on save (make watch DIR=examples/guide/en)
	@dir="$(DIR)"; \
	srcdir="$$dir/src"; \
	adoc=""; \
	if [ -f "$$srcdir/main.adoc" ]; then adoc="main.adoc"; \
	elif [ -f "$$srcdir/setup-guide.adoc" ]; then adoc="setup-guide.adoc"; fi; \
	if [ -z "$$adoc" ]; then echo "Error: No .adoc file found in $$srcdir/"; exit 1; fi; \
	echo "Watching $$srcdir/$$adoc for changes..."; \
	echo "Press Ctrl+C to stop."; \
	if command -v entr >/dev/null 2>&1; then \
	  find "$$srcdir" -name "*.adoc" | entr -s \
	    "echo 'Recompiling...'; \
	     $(CURDIR)/scripts/build-adoc.sh $$srcdir/$$adoc $$srcdir/main.tex && \
	     (cd $$srcdir && latexmk -xelatex main.tex 2>&1 | tail -3)"; \
	elif command -v inotifywait >/dev/null 2>&1; then \
	  while true; do \
	    inotifywait -q -e modify "$$srcdir/$$adoc" >/dev/null 2>&1; \
	    echo "Recompiling..."; \
	    $(CURDIR)/scripts/build-adoc.sh "$$srcdir/$$adoc" "$$srcdir/main.tex" && \
	    (cd "$$srcdir" && latexmk -xelatex main.tex 2>&1 | tail -3); \
	  done; \
	else \
	  echo "Warning: Neither 'entr' nor 'inotifywait' found. Using polling fallback."; \
	  last_mtime=0; \
	  while true; do \
	    current_mtime=$$(stat -c %Y "$$srcdir/$$adoc" 2>/dev/null || stat -f %m "$$srcdir/$$adoc"); \
	    if [ "$$current_mtime" != "$$last_mtime" ]; then \
	      last_mtime=$$current_mtime; \
	      echo "Recompiling..."; \
	      $(CURDIR)/scripts/build-adoc.sh "$$srcdir/$$adoc" "$$srcdir/main.tex" && \
	      (cd "$$srcdir" && latexmk -xelatex main.tex 2>&1 | tail -3); \
	    fi; \
	    sleep 1; \
	  done; \
	fi

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

clean-setup-guide: ## Clean the setup-guide and the root format copies
	cd examples/setup-guide/src && latexmk -C setup-guide.tex
	rm -f examples/setup-guide/src/setup-guide.tex examples/setup-guide/setup-guide.pdf
	rm -f setup-guide/setup-guide.pdf setup-guide/setup-guide.md setup-guide/setup-guide.docx setup-guide/setup-guide.html

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

.PHONY: help all samples examples setup-guide project menu preview watch
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
