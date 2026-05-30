PYTHON ?= python3

.PHONY: check clean help install-dev test-links test-markdown-lint test-reachability

check: test-markdown-lint test-links test-reachability  ## Run full quality gate (default)

.DEFAULT_GOAL := check

help:  ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-32s\033[0m %s\n", $$1, $$2}'

clean:  ## Remove build artifacts and review/analysis output
	rm -rf .tmp-*/
	rm -f ANALYSIS.md Findings-*.md Findings-*.json Report-*.json

install-dev:  ## Install development dependencies
	$(PYTHON) -m pip install --quiet 'pymarkdownlnt>=0.9.37,<1.0'

test-markdown-lint: install-dev  ## Lint markdown files
	@echo "Linting markdown files..."
	$(PYTHON) -m pymarkdown --set 'plugins.md010.code_blocks=$$!False' --disable-rules MD013,MD024,MD031,MD036 scan --recurse --respect-gitignore .

test-links:  ## Validate local markdown links and anchors
	@echo "Validating local links..."
	$(PYTHON) scripts/check-links.py

test-reachability:  ## Verify all files are reachable from README.md and CLAUDE.md
	@echo "Checking document reachability..."
	$(PYTHON) scripts/reachability.py --check
