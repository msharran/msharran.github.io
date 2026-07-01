PORT ?= 4000
JEKYLL_IMAGE ?= msharran-github-io-jekyll
JEKYLL_CONTAINER ?= msharran-github-io-jekyll

.PHONY: build serve serve-detached stop

build:
	docker build -t $(JEKYLL_IMAGE) .

serve: build
	docker run \
		-p $(PORT):4000 \
		$(JEKYLL_IMAGE)

serve-detached: build
	-docker rm -f $(JEKYLL_CONTAINER)
	docker run -d \
		--name $(JEKYLL_CONTAINER) \
		-p $(PORT):4000 \
		$(JEKYLL_IMAGE)

stop:
	-docker rm -f $(JEKYLL_CONTAINER)
