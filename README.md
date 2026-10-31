# msharran.github.io

Personal devlog built with Jekyll and GitHub Pages.

## Design

Nothing-inspired monochrome typography with Space Grotesk (Google Fonts) and
Hack (cdnjs). The site starts in dark mode; the header switch saves a light or
dark preference locally. The intro, archives, articles, notes, and profile share
one responsive shell. The profile has a separate print treatment.

[Visual review: desktop, mobile, dark, light, and before/after screenshots](docs/redesign/README.md).

## Local development

Run `make serve-detached` with Docker, then open http://localhost:4000/.
`make build` validates the Jekyll build. Run `make stop` to stop the preview.
