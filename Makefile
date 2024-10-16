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


.PHONY: bdi
bdi: ## build dblib image
	docker buildx build --load --platform linux/amd64 -f Dockerfile -t anriykalashnykov/dblib-docker:latest .

.PHONY: rdi
rdi: ## run dlib image
	docker run --rm -v $PWD:/app -w /app -it anriykalashnykov/dblib-docker:latest /bin/bash
