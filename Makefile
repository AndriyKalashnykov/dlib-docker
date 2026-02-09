projectname?=dlib-docker

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

release: ## create and push a new tag
	$(eval NT=$(NEWTAG))
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

bootstrap: ## bootstrap build dblib image
	docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder --driver docker-container --bootstrap

bdid: ## build debian dblib image
	docker buildx use multi-platform-builder
	docker buildx build --load --platform linux/amd64 -f Dockerfile --build-arg DLIB_VERSION=20.0 -t anriykalashnykov/dblib-docker:amd64 .
	docker buildx build --load --platform linux/arm/v7 -f Dockerfile --build-arg DLIB_VERSION=20.0 -t anriykalashnykov/dblib-docker:armv7 .
	docker buildx build --load --platform linux/arm64 -f Dockerfile --build-arg DLIB_VERSION=20.0 -t anriykalashnykov/dblib-docker:arm64 .



rdid: ## run debian dlib image -v $PWD:/app -w /app
	docker run --rm -it anriykalashnykov/dblib-docker:armv7 /bin/bash
	docker run --rm -it anriykalashnykov/dblib-docker:arm64 /bin/bash
	docker run --rm -it anriykalashnykov/dblib-docker:amd64 /bin/bash

dt: ## delete tag
	rm -f version.txt
	git push --delete origin v20.0.0
	git tag --delete v20.0.0

bootstrap-renovate: ## install nvm and npm for renovate
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

validate-renovate: bootstrap-renovate
	npx -p renovate -c 'renovate-config-validator'
