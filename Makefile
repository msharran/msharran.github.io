PORT ?= 4000
LIVERELOAD_PORT ?= 35729
JEKYLL_IMAGE ?= msharran-github-io-jekyll
JEKYLL_CONTAINER ?= msharran-github-io-jekyll
JEKYLL_FLAGS ?= --livereload --livereload-port $(LIVERELOAD_PORT) --force_polling --incremental

.PHONY: build serve serve-detached stop

build:
	docker build -t $(JEKYLL_IMAGE) .

serve: build
	docker run --rm \
		-v $(CURDIR):/srv/jekyll \
		-p $(PORT):4000 \
		-p $(LIVERELOAD_PORT):$(LIVERELOAD_PORT) \
		$(JEKYLL_IMAGE) \
		bundle exec jekyll serve --host 0.0.0.0 --port 4000 $(JEKYLL_FLAGS)

serve-detached: build
	-docker rm -f $(JEKYLL_CONTAINER)
	docker run -d \
		--name $(JEKYLL_CONTAINER) \
		-v $(CURDIR):/srv/jekyll \
		-p $(PORT):4000 \
		-p $(LIVERELOAD_PORT):$(LIVERELOAD_PORT) \
		$(JEKYLL_IMAGE) \
		bundle exec jekyll serve --host 0.0.0.0 --port 4000 $(JEKYLL_FLAGS)

stop:
	-docker rm -f $(JEKYLL_CONTAINER)
