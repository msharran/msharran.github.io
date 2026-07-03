---
description: Create a new devlog draft and link it from the homepage
argument-hint: "<title>"
---
Create a new devlog page for this title:

```text
$ARGUMENTS
```

Use the existing devlog convention:

1. Create a Markdown file under `devlog/` named with today's date and a slugified title:
   - `devlog/YYYYMMDD-title-slug.md`
2. Use front matter like:

   ```yaml
   ---
   layout: default
   title: "<title>"
   date: YYYY-MM-DD
   permalink: /devlog/YYYYMMDD-title-slug/
   description: "<subtitle if provided>"
   ---
   ```

3. Add only a starter draft body:
   - `# <title>`
   - subtitle in italics if provided
   - source/project link if provided
   - `<!-- Draft goes here. -->`
4. Update `index.md` by adding the new devlog entry at the top of the devlog list.
5. Do not write the article content unless explicitly asked.
6. Run `make build` to verify the site still builds.
