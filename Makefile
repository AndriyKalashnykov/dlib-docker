# ---------------------------------------------------------------------------
# Tool versions
# ---------------------------------------------------------------------------
DOCKER_VERSION          := 27.5.1
DLIB_VERSION            := 20.0
BUILDER_IMAGE           := ubuntu:noble-20260217
ACT_VERSION             := 0.2.87
HADOLINT_VERSION        := 2.12.0
NVM_VERSION             := 0.40.4

# ---------------------------------------------------------------------------
# Project variables
# ---------------------------------------------------------------------------
projectname             ?= dlib-docker
IMAGE_NAME              := anriykalashnykov/dblib-docker
CURRENTTAG              := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "none")
NEWTAG                  ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - $(CURRENTTAG)): " newtag; echo $$newtag')
SEMVER_REGEX            := ^v[0-9]+\.[0-9]+\.[0-9]+$$

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

help: #help: @ List available make targets
	@grep -E '^[a-zA-Z_-]+:.*#[a-zA-Z_-]+: @ .*$$' $(MAKEFILE_LIST) | sort | awk '{split($$0, a, "#"); split(a[2], b, ": @ "); printf "\033[36m%-25s\033[0m %s\n", b[1], b[2]}'

deps: #deps: @ Verify required toolchain dependencies
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker (>= $(DOCKER_VERSION)) is required but not found. Aborting."; exit 1; }
	@echo "All dependencies satisfied."

deps-hadolint: #deps-hadolint: @ Install hadolint for Dockerfile linting
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint /usr/local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

deps-act: deps #deps-act: @ Install act for local CI execution
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

deps-renovate: #deps-renovate: @ Install nvm and npm for Renovate
	@if [ ! -d "$$HOME/.nvm" ]; then \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
		nvm use --lts; \
	else \
		echo "nvm already installed"; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
	fi

clean: #clean: @ Remove build artefacts and temporary files
	@rm -f version.txt
	@echo "Clean complete."

build: deps #build: @ Build the dlib Docker image (alias for image-build)
	@$(MAKE) --no-print-directory image-build

test: deps #test: @ Run container smoke test
	@echo "Running smoke test..."
	@docker run --rm $(IMAGE_NAME):amd64 dpkg -l | grep -q dlib && echo "PASS: dlib package found" || echo "FAIL: dlib package not found"

lint: deps-hadolint #lint: @ Lint the Dockerfile with hadolint
	@hadolint Dockerfile

run: deps #run: @ Run the dlib Docker image interactively (amd64)
	@docker run --rm -it $(IMAGE_NAME):amd64 /bin/bash

ci: deps lint build test #ci: @ Run full CI pipeline (deps, lint, build, test)
	@echo "CI pipeline complete."

ci-run: deps-act #ci-run: @ Run GitHub Actions workflow locally using act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

release: #release: @ Create and push a new semver tag
	$(eval NT=$(NEWTAG))
	@if ! echo "$(NT)" | grep -qE '$(SEMVER_REGEX)'; then \
		echo "ERROR: Tag '$(NT)' does not match semver pattern $(SEMVER_REGEX)"; \
		exit 1; \
	fi
	@echo -n "Are you sure to create and push $(NT) tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo $(NT) > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut $(NT) release"
	@git tag $(NT)
	@git push origin $(NT)
	@git push
	@echo "Done."

buildx-bootstrap: deps #buildx-bootstrap: @ Bootstrap multi-platform Docker buildx builder
	@docker buildx inspect multi-platform-builder >/dev/null 2>&1 || \
		docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder --driver docker-container --bootstrap

image-build: deps #image-build: @ Build dlib image for amd64, armv7, and arm64
	@docker buildx use multi-platform-builder
	@docker buildx build --load --platform linux/amd64 -f Dockerfile --build-arg DLIB_VERSION=$(DLIB_VERSION) -t $(IMAGE_NAME):amd64 .
	@docker buildx build --load --platform linux/arm/v7 -f Dockerfile --build-arg DLIB_VERSION=$(DLIB_VERSION) -t $(IMAGE_NAME):armv7 .
	@docker buildx build --load --platform linux/arm64 -f Dockerfile --build-arg DLIB_VERSION=$(DLIB_VERSION) -t $(IMAGE_NAME):arm64 .

image-run: deps #image-run: @ Run dlib images interactively for all platforms
	@docker run --rm -it $(IMAGE_NAME):armv7 /bin/bash
	@docker run --rm -it $(IMAGE_NAME):arm64 /bin/bash
	@docker run --rm -it $(IMAGE_NAME):amd64 /bin/bash

tag-delete: #tag-delete: @ Delete a specific tag locally and from remote
	@rm -f version.txt
	@git push --delete origin v$(DLIB_VERSION).0
	@git tag --delete v$(DLIB_VERSION).0

renovate-bootstrap: deps-renovate #renovate-bootstrap: @ Install nvm and npm for Renovate
	@echo "Renovate dependencies ready."

renovate-validate: deps-renovate #renovate-validate: @ Validate Renovate configuration
	@npx -p renovate -c 'renovate-config-validator'

.PHONY: help deps deps-hadolint deps-act deps-renovate clean build test lint run ci ci-run \
	release buildx-bootstrap image-build image-run tag-delete renovate-bootstrap renovate-validate
