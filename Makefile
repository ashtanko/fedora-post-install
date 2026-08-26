# fedora-post-install — developer convenience targets.
# Run `make help` for the list. UBUNTU and SCRIPT are optional overrides.

SHELL  := /bin/bash
UBUNTU ?= 24.04
SCRIPT ?=
VERSION ?=
export VERSION

.DEFAULT_GOAL := help
.PHONY: help lint manifest config-regression pkg-regression essentials-regression system-regression apps-regression dev-regression tools-regression ide-regression mobile-regression identity-regression runtime-regression installer-regression \
        contract-regression regressions check smoke smoke-all \
        idempotency idempotency-all setup version tui-test tui-build tag dist release-artifact \
        release-dry-run clean clean-markers

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	     /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables:"
	@echo "  UBUNTU=<version>     22.04 | 24.04 | 26.04 (default: $(UBUNTU))"
	@echo "  SCRIPT=<path.sh>     scope smoke/idempotency to one script"
	@echo "  VERSION=<x.y.z>      required by 'make tag'"

# ── Static checks ────────────────────────────────────────────────────────────

lint: ## Run shellcheck on every .sh and .bash file
	bash tests/lint.sh

manifest: ## Verify every .sh is registered in tests/manifest.sh
	bash tests/check-manifest-coverage.sh

config-regression: ## Verify config precedence and secret export isolation
	bash tests/config-regression.sh

pkg-regression: ## Verify Fedora package helper behavior and repository trust checks
	bash tests/pkg-regression.sh

essentials-regression: ## Verify Fedora-native essentials behavior and policy
	bash tests/essentials-regression.sh

system-regression: ## Verify Fedora-native system setup behavior and policy
	bash tests/system-regression.sh

apps-regression: ## Verify Fedora-native application installers and updater ownership
	bash tests/apps-regression.sh

dev-regression: ## Verify Fedora-native development installers and updater ownership
	bash tests/dev-regression.sh

tools-regression: ## Verify Fedora-native tools installers and updater ownership
	bash tests/tools-regression.sh

ide-regression: ## Verify Fedora-native IDE installers and updater ownership
	bash tests/ide-regression.sh

mobile-regression: ## Verify the Fedora-native Flutter plugin archive utility
	bash tests/mobile-regression.sh

identity-regression: ## Verify the Fedora project identity is used consistently
	bash tests/identity-regression.sh

runtime-regression: ## Verify runtime safety and transactional install behavior
	bash tests/runtime-core-regression.sh

installer-regression: ## Verify installer edge cases and failure reporting
	bash tests/installer-regression.sh

contract-regression: ## Verify script contracts, incl. scripts Docker never runs
	bash tests/script-contract-regression.sh

regressions: ## Run all fast local regression checks
	bash tests/regression.sh

check: lint manifest regressions tui-test ## Run all static and regression checks

tui-test: ## Format-check, test, vet, and compile the terminal UI
	@test -z "$$(gofmt -l cmd/fedora-post-install-tui)" \
		|| { echo "Go files need formatting:"; gofmt -l cmd/fedora-post-install-tui; exit 1; }
	go test ./cmd/fedora-post-install-tui
	go vet ./cmd/fedora-post-install-tui
	go build -o /tmp/fedora-post-install-tui-check ./cmd/fedora-post-install-tui
	/tmp/fedora-post-install-tui-check --root . --catalog config/catalog.txt --check

tui-build: ## Build release TUI binaries for Linux amd64 and arm64
	@mkdir -p bin
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' \
		-o bin/fedora-post-install-tui-amd64 ./cmd/fedora-post-install-tui
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags='-s -w' \
		-o bin/fedora-post-install-tui-arm64 ./cmd/fedora-post-install-tui

# ── Docker tests ─────────────────────────────────────────────────────────────

smoke: ## Smoke stage (UBUNTU=… SCRIPT=… to scope)
	bash tests/run-in-docker.sh $(UBUNTU) smoke $(SCRIPT)

smoke-all: ## Smoke stage across every supported Ubuntu version
	@for v in 22.04 24.04 26.04; do \
		echo "==> smoke / ubuntu-$$v"; \
		bash tests/run-in-docker.sh $$v smoke || exit 1; \
	done

idempotency: ## Idempotency stage (UBUNTU=… SCRIPT=… to scope)
	bash tests/run-in-docker.sh $(UBUNTU) idempotency $(SCRIPT)

idempotency-all: ## Idempotency stage across every supported Ubuntu version
	@for v in 22.04 24.04 26.04; do \
		echo "==> idempotency / ubuntu-$$v"; \
		bash tests/run-in-docker.sh $$v idempotency || exit 1; \
	done

# ── Local runtime ────────────────────────────────────────────────────────────

setup: ## Launch the interactive installer locally
	bash setup.sh

version: ## Print the version embedded in setup.sh
	@bash setup.sh --version

clean-markers: ## Reset ~/.cache/fedora-setup/ markers (force re-run on next setup)
	rm -rf $(HOME)/.cache/fedora-setup
	@echo "  ✅ marker cache cleared"

# ── Release ──────────────────────────────────────────────────────────────────

tag: ## Cut and push a release tag (make tag VERSION=1.0.0)
	@test -n "$$VERSION" || { echo "VERSION required: make tag VERSION=1.0.0"; exit 1; }
	@source lib/release.bash; is_semver "$$VERSION" \
		|| { echo "VERSION must be SemVer (e.g. 1.0.0 or 1.0.0-rc1)"; exit 1; }
	@test -z "$$(git status --porcelain)" \
		|| { echo "working tree must be clean before tagging"; exit 1; }
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	git push origin "v$(VERSION)"
	@echo "  ✅ pushed v$(VERSION) — watch the workflow at:"
	@echo "  https://github.com/ashtanko/fedora-post-install/actions/workflows/release.yml"

dist: clean ## Build the release tarball locally (mirrors release.yml; no upload)
	@$(MAKE) tui-build
	@set -euo pipefail; \
	VERSION_LOCAL=$$(git describe --tags --exact-match 2>/dev/null \
		|| git describe --tags --abbrev=0 2>/dev/null \
		|| echo "v0.0.0-local"); \
	SEMVER=$${VERSION_LOCAL#v}; \
	STAGE="dist/fedora-post-install-$$SEMVER"; \
	echo "==> staging $$STAGE"; \
	mkdir -p "$$STAGE"; \
	rsync -a --exclude='.git/' --exclude='.github/' --exclude='.idea/' \
	         --exclude='.omx/' --exclude='dist/' --exclude='.env' ./ "$$STAGE/"; \
	sed -i "s/^VERSION=.*/VERSION=\"$$SEMVER\"/" "$$STAGE/setup.sh"; \
	echo "$$SEMVER" > "$$STAGE/VERSION"; \
	cd dist && tar -czf "fedora-post-install-$$SEMVER.tar.gz" "fedora-post-install-$$SEMVER"; \
	rm -rf "fedora-post-install-$$SEMVER"; \
	cp ../install.sh ./install.sh; \
	sha256sum "fedora-post-install-$$SEMVER.tar.gz" install.sh > SHA256SUMS; \
	echo "==> dist/"; ls -la

release-artifact: dist ## Build and verify the local release artifact set
	@VERSION_LOCAL=$$(git describe --tags --exact-match 2>/dev/null \
		|| git describe --tags --abbrev=0 2>/dev/null \
		|| echo "v0.0.0-local"); \
	bash tests/release-artifact.sh "$${VERSION_LOCAL#v}"

release-dry-run: check release-artifact ## Run checks and verify a tarball — no publish

clean: ## Remove build artifacts
	rm -rf dist/
	rm -f bin/fedora-post-install-tui-amd64 bin/fedora-post-install-tui-arm64
