---
name: generate-profile-pdf
description: Generate the public profile/resume page as a PDF from the local Jekyll site using Chrome headless. Use when asked to export, refresh, or verify the website-hosted resume/profile PDF.
---

# Generate Profile PDF

This site owns resume/profile PDF generation. The source page is the website route:

```text
/profile/
```

The generated PDF must be saved under a git-ignored path:

```text
.generated/resume/sse-resume.pdf
```

## Workflow

From the repository root (`/Users/msharran/root/play/msharran.github.io`):

1. Ensure the local Jekyll site is running:

   ```bash
   make serve-detached
   ```

2. Export the profile page with Chrome headless, A4 paper, print backgrounds, and no browser headers/footers:

   ```bash
   mkdir -p .generated/resume
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
     --headless \
     --disable-gpu \
     --no-pdf-header-footer \
     --print-to-pdf=.generated/resume/sse-resume.pdf \
     --print-to-pdf-no-header \
     http://localhost:4000/profile/
   ```

3. Verify the file exists and is non-empty:

   ```bash
   ls -lh .generated/resume/sse-resume.pdf
   ```

4. Stop the local Jekyll container if it was only started for export:

   ```bash
   make stop
   ```

## Notes

- `.generated/` is intentionally git ignored; do not commit exported PDFs from this path.
- The profile page hides site navigation under `@media print`, so the exported PDF is the resume only.
- If Chrome's CLI flag support changes, keep the invariant: A4 output, background graphics enabled, no headers/footers, route source is `/profile/`.
