# AGENTS.md

## Cursor Cloud specific instructions

This repo is a Jekyll static site (see `README.md`). The canonical local workflow documented in the `Makefile` and the `verification` / `generate-profile-pdf` skills is **Docker-based** (`make build`, `make serve-detached`). Docker is **not available** in the Cursor Cloud VM, so run Jekyll natively with Ruby/bundler instead. The commands below run exactly what the Docker container would run internally.

### Environment
- Ruby 3.2 and the `bundle` executable (`/usr/local/bin/bundle`) are installed at the system level (persisted in the VM snapshot). The update script runs `bundle install`.
- Gems install to `vendor/bundle` (git-ignored). The `bundle config` path is set by the update script.
- The committed `Gemfile.lock` lists only the `aarch64-linux` platform (generated on the maintainer's ARM machine). The Cloud VM is `x86_64`, so `bundle install` re-resolves and adds the `x86_64-linux` platform, leaving `Gemfile.lock` modified locally. **Do not commit that `Gemfile.lock` change.**

### Run the dev server (native equivalent of `make serve-detached`)
```
bundle exec jekyll serve --host 0.0.0.0 --port 4000 --livereload --livereload-port 35729 --force_polling --incremental
```
Then open `http://localhost:4000/`. `--force_polling` is required for live reload to detect file changes reliably in this environment.

### Build (also acts as the lint/validation step)
```
bundle exec jekyll build
```
There is no separate linter or automated test suite; a successful `jekyll build` is the correctness check. Sass `@import` / `lighten()` deprecation warnings from the `minima` theme are **non-fatal** — only treat a non-zero exit code as failure.

### Skills
- Content/authoring conventions live in `.agents/skills/new-devlog/SKILL.md`.
- The `verification`, `deploy`, and `generate-profile-pdf` skills assume Docker + macOS Chrome paths; adapt their commands to the native `bundle exec jekyll ...` server when running in the Cloud VM.
