---
name: verification
description: Verify this Jekyll GitHub Pages project builds and serves correctly via Docker Makefile targets. Use after changes to site content, styling, Dockerfile, Gemfile, or Makefile, or when asked to verify/fix build or serve errors.
---

# Verification

Use this skill to verify the project can build and serve locally through Docker.

## Project context

This repository is a Jekyll site served by Docker. The canonical workflow is the `Makefile` in the repository root.

Important targets:

```bash
make build
make serve-detached
make stop
```

The default local URL is:

```text
http://localhost:4000/
```

## Verification workflow

From the repository root:

1. Check working tree and relevant files before changing anything:

   ```bash
   git status --short
   ```

2. Build the Docker image:

   ```bash
   make build
   ```

3. Start the site detached:

   ```bash
   make serve-detached
   ```

4. Confirm the named container is running:

   ```bash
   docker ps --filter name=msharran-github-io-jekyll --format 'table {{.ID}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}'
   ```

5. Verify HTTP response:

   ```bash
   curl -fsS http://localhost:4000/ >/tmp/msharran-site.html
   wc -c /tmp/msharran-site.html
   ```

6. If verification fails, inspect recent logs:

   ```bash
   docker logs --tail 80 msharran-github-io-jekyll
   ```

## Expected result

Verification passes when:

- `make build` exits successfully.
- `make serve-detached` exits successfully.
- The container named `msharran-github-io-jekyll` is `Up`.
- `curl -fsS http://localhost:4000/` exits successfully and returns non-empty HTML.

## Notes

- Sass deprecation warnings from the `minima` theme are currently non-fatal. Do not treat them as a failed verification unless the command exits non-zero.
- Prefer `make stop` to clean up the project container when needed.
- Do not remove arbitrary Docker containers. Only stop/remove the named project container unless the user explicitly asks for broader cleanup.
- If port `4000` is already allocated by an unrelated process, report the conflict and either use `PORT=<free-port> make serve-detached` or ask the user before stopping unrelated services.
