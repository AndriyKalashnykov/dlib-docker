# ---------------------------------------------------------------------------
# Tool versions
# ---------------------------------------------------------------------------
DOCKER_VERSION          := 27.5.1
DLIB_VERSION            := 20.0
BUILDER_IMAGE           := ubuntu:noble-20260113

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

.PHONY: help deps clean build test lint run ci release bootstrap image-build image-run tag-delete bootstrap-renovate validate-renovate

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

help: #help: @ List available make targets
	@grep -E '^[a-zA-Z_-]+:.*#[a-zA-Z_-]+: @ .*$$' $(MAKEFILE_LIST) | sort | awk '{split($$0, a, "#"); split(a[2], b, ": @ "); printf "\033[36m%-25s\033[0m %s\n", b[1], b[2]}'

deps: #deps: @ Verify required toolchain dependencies
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker (>= $(DOCKER_VERSION)) is required but not found. Aborting."; exit 1; }
	@echo "All dependencies satisfied."

clean: #clean: @ Remove build artefacts and temporary files
	@rm -f version.txt
	@echo "Clean complete."

build: deps #build: @ Build the dlib Docker image (alias for image-build)
	@$(MAKE) --no-print-directory image-build

test: deps #test: @ Run container smoke test
	@echo "Running smoke test..."
	@docker run --rm $(IMAGE_NAME):amd64 dpkg -l | grep -q dlib && echo "PASS: dlib package found" || echo "FAIL: dlib package not found"

lint: #lint: @ Lint the Dockerfile with hadolint
	@command -v hadolint >/dev/null 2>&1 || { echo "ERROR: hadolint is required but not found. Aborting."; exit 1; }
	@hadolint Dockerfile

run: deps #run: @ Run the dlib Docker image interactively (amd64)
	@docker run --rm -it $(IMAGE_NAME):amd64 /bin/bash

ci: deps lint build test #ci: @ Run full CI pipeline (deps, lint, build, test)
	@echo "CI pipeline complete."

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

bootstrap: #bootstrap: @ Bootstrap multi-platform Docker buildx builder
	@docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder --driver docker-container --bootstrap

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

bootstrap-renovate: #bootstrap-renovate: @ Install nvm and npm for renovate
	@if [ ! -d "$$HOME/.nvm" ]; then \
		echo "Installing nvm..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
		nvm use --lts; \
	else \
		echo "nvm already installed"; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
	fi

validate-renovate: bootstrap-renovate #validate-renovate: @ Validate renovate configuration
	@npx -p renovate -c 'renovate-config-validator'
