# ---------------------------------------------------------------------------
# Tool versions (pinned; Renovate-tracked via inline comments)
# ---------------------------------------------------------------------------
# dlib is built from source in the Dockerfile at this exact upstream tag.
# The git tag cut for a release should match DLIB_VERSION (project convention:
# the project version == the dlib version it ships).
# renovate: datasource=github-tags depName=davisking/dlib
DLIB_VERSION            := 19.24.9
# renovate: datasource=github-releases depName=nektos/act
ACT_VERSION             := 0.2.87
# renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION        := 2.14.0
# renovate: datasource=github-releases depName=aquasecurity/trivy
TRIVY_VERSION           := 0.69.3
# renovate: datasource=github-releases depName=nvm-sh/nvm
NVM_VERSION             := 0.40.4
NODE_VERSION            := $(shell cat .nvmrc 2>/dev/null || echo 22)

# ---------------------------------------------------------------------------
# Project variables
# ---------------------------------------------------------------------------
APP_NAME                := dlib-docker
IMAGE_NAME              := andriykalashnykov/dlib-docker
CURRENTTAG              := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "none")
NEWTAG                  ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - $(CURRENTTAG)): " newtag; echo $$newtag')
SEMVER_REGEX            := ^v[0-9]+\.[0-9]+\.[0-9]+$$

# Ensure tools installed to ~/.local/bin (hadolint, act) are on PATH for
# every recipe — needed inside act containers where this path is not
# preconfigured. Exported so every sub-shell the recipes spawn inherits it.
export PATH := $(HOME)/.local/bin:$(PATH)

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

help: #help: @ List available tasks
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z0-9\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-22s\033[0m - %s\n", $$1, $$2}'

deps: #deps: @ Verify required toolchain dependencies
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required but not found. Aborting."; exit 1; }
	@echo "All dependencies satisfied."

deps-hadolint: #deps-hadolint: @ Install hadolint for Dockerfile linting
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		ARCH=$$(uname -m); \
		case "$$ARCH" in \
			x86_64) HADOLINT_ARCH=x86_64 ;; \
			aarch64|arm64) HADOLINT_ARCH=arm64 ;; \
			*) echo "ERROR: Unsupported architecture $$ARCH"; exit 1 ;; \
		esac; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-$$HADOLINT_ARCH && \
		install -m 755 /tmp/hadolint $$HOME/.local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

deps-act: deps #deps-act: @ Install act for local CI execution
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b $$HOME/.local/bin v$(ACT_VERSION); \
	}

deps-trivy: #deps-trivy: @ Install Trivy for filesystem security scanning
	@command -v trivy >/dev/null 2>&1 || { echo "Installing trivy $(TRIVY_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $$HOME/.local/bin v$(TRIVY_VERSION); \
	}

renovate-bootstrap: #renovate-bootstrap: @ Install nvm and Node for Renovate
	@if [ ! -d "$$HOME/.nvm" ]; then \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
	fi
	@export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install $(NODE_VERSION); \
		nvm use $(NODE_VERSION)

clean: #clean: @ Remove build artefacts and temporary files
	@echo "Clean complete."

build: deps buildx-bootstrap #build: @ Build the dlib Docker image for all platforms
	@docker buildx use multi-platform-builder
	@docker buildx build --load --platform linux/amd64 -f Dockerfile --build-arg DLIB_VERSION=$(DLIB_VERSION) -t $(IMAGE_NAME):amd64 .
	@docker buildx build --load --platform linux/arm/v7 -f Dockerfile --build-arg DLIB_VERSION=$(DLIB_VERSION) -t $(IMAGE_NAME):armv7 .
	@docker buildx build --load --platform linux/arm64 -f Dockerfile --build-arg DLIB_VERSION=$(DLIB_VERSION) -t $(IMAGE_NAME):arm64 .

test: build #test: @ Run container smoke test
	@echo "Running smoke test..."
	@docker run --rm $(IMAGE_NAME):amd64 bash -c 'test -f /usr/local/include/dlib/matrix.h && ls /usr/local/lib/libdlib*.so* >/dev/null 2>&1' && echo "PASS: dlib headers + shared lib present" || { echo "FAIL: dlib not installed correctly"; exit 1; }

lint: deps-hadolint #lint: @ Lint the Dockerfile with hadolint
	@hadolint Dockerfile

trivy-fs: deps-trivy #trivy-fs: @ Scan filesystem for vulnerabilities, secrets, and misconfigurations
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed .

static-check: lint trivy-fs #static-check: @ Composite quality gate (lint + trivy-fs)
	@echo "Static check passed."

run: deps #run: @ Run the dlib Docker image interactively (amd64)
	@docker run --rm -it $(IMAGE_NAME):amd64 /bin/bash

ci: deps static-check build test #ci: @ Run full CI pipeline (deps, static-check, build, test)
	@echo "CI pipeline complete."

ci-run: deps-act #ci-run: @ Run GitHub Actions workflow locally using act
	@docker container prune -f 2>/dev/null || true
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

release: #release: @ Create and push a semver tag + GitHub Release
	$(eval NT=$(NEWTAG))
	@if ! echo "$(NT)" | grep -qE '$(SEMVER_REGEX)'; then \
		echo "ERROR: Tag '$(NT)' does not match semver pattern $(SEMVER_REGEX)"; \
		exit 1; \
	fi
	@command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required for release creation"; exit 1; }
	@echo -n "Are you sure to create and push $(NT) tag + GitHub Release? [y/N] " && read ans && [ $${ans:-N} = y ]
	@git tag $(NT)
	@git push origin $(NT)
	@gh release create $(NT) --generate-notes --verify-tag --title "$(NT)"
	@echo "Done."

buildx-bootstrap: deps #buildx-bootstrap: @ Bootstrap multi-platform Docker buildx builder
	@docker buildx inspect multi-platform-builder >/dev/null 2>&1 || \
		docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder --driver docker-container --bootstrap

image-run-amd64: deps #image-run-amd64: @ Run dlib image interactively (amd64)
	@docker run --rm -it $(IMAGE_NAME):amd64 /bin/bash

image-run-arm64: deps #image-run-arm64: @ Run dlib image interactively (arm64)
	@docker run --rm -it $(IMAGE_NAME):arm64 /bin/bash

image-run-armv7: deps #image-run-armv7: @ Run dlib image interactively (arm/v7)
	@docker run --rm -it $(IMAGE_NAME):armv7 /bin/bash

tag-delete: #tag-delete: @ Delete a tag locally and from remote (TAG=vX.Y.Z)
	@if [ -z "$(TAG)" ]; then echo "ERROR: TAG is required (e.g., make tag-delete TAG=v20.0.0)"; exit 1; fi
	@git push --delete origin $(TAG)
	@git tag --delete $(TAG)

renovate-validate: renovate-bootstrap #renovate-validate: @ Validate Renovate configuration
	@export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		if [ -n "$$GH_ACCESS_TOKEN" ]; then \
			GITHUB_COM_TOKEN=$$GH_ACCESS_TOKEN npx -p renovate -c 'renovate-config-validator'; \
		else \
			npx -p renovate -c 'renovate-config-validator'; \
		fi

.PHONY: help deps deps-hadolint deps-act deps-trivy renovate-bootstrap clean build test lint trivy-fs static-check run ci ci-run \
	release buildx-bootstrap image-run-amd64 image-run-arm64 image-run-armv7 tag-delete renovate-validate
