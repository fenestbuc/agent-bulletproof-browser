SHELL := /bin/bash
BATS := $(shell command -v bats 2>/dev/null || echo bats)
SHELLCHECK := $(shell command -v shellcheck 2>/dev/null || echo shellcheck)
SHFMT := $(shell command -v shfmt 2>/dev/null || echo shfmt)

SCRIPTS := scripts/run-agent-headless.sh scripts/start-agent-browser.sh scripts/agent-cookie-sync.sh install.sh tests/run-tests.sh
LIBS := $(wildcard lib/*.sh)
ALL_SHELL := $(SCRIPTS) $(LIBS)

.PHONY: all test lint fmt ci

all: lint fmt test

test: test-unit test-integration test-existing

test-unit:
	@echo "=== Running lib unit tests ==="
	$(BATS) tests/lib/

test-integration:
	@echo "=== Running integration tests ==="
	$(BATS) tests/test-core.bats

test-existing:
	@echo "=== Running existing manual test suite ==="
	bash tests/run-tests.sh

lint:
	@echo "=== Running shellcheck ==="
	$(SHELLCHECK) $(ALL_SHELL)

fmt:
	@echo "=== Running shfmt ==="
	$(SHFMT) -d -i 4 -ci $(ALL_SHELL)

fmt-fix:
	@echo "=== Fixing shell formatting ==="
	$(SHFMT) -w -i 4 -ci $(ALL_SHELL)

ci: lint test
