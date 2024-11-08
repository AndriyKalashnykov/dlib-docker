projectname?=dlib-docker

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'


.PHONY: release
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

.PHONY: bootstrap
bootstrap: ## bootstrap build dblib image
	docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder

.PHONY: bdid
bdid: ## build debian dblib image
	docker build --platform linux/amd64 -f Dockerfile.debian.amd64 -t anriykalashnykov/dblib-docker:amd64 .
#	docker build --platform linux/arm64 -f Dockerfile.debian.arm64 -t anriykalashnykov/dblib-docker:arm64 .

.PHONY: rdid
rdid: ## run debian dlib image
	docker run --rm -v $PWD:/app -w /app -it anriykalashnykov/dblib-docker:amd64 /bin/bash
#	docker run --rm -v $PWD:/app -w /app -it anriykalashnykov/dblib-docker:arm64 /bin/bash

.PHONY: bdia
bdia: ## build alpine dblib image
	docker build --platform linux/amd64 -f Dockerfile.alpine -t anriykalashnykov/dblib-docker:latest-alpine .

.PHONY: rdia
rdia: ## run alpine dlib image
	docker run --rm -v $PWD:/app -w /app -it anriykalashnykov/dblib-docker:latest-alpine /bin/sh

.PHONY: dt
dt: ## delete tag
	rm -f version.txt
	git push --delete origin v19.24.0
	git tag --delete v19.24.0
