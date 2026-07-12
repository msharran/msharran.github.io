---
name: deploy
description: Deploy the site to GitHub Pages. This skill is used after local verification of changes and will trigger a GitHub Action to deploy the site. 
---

## Deploy

- verify the local changes using "verification" skill in this project
- run global skill /skill:gflush 
- A github action for deploying github pages will be auto triggered, monitor it.
- stop if it succeeds.
- fix if it failed and redeploy.
- if the issue is complex, do an RCA and stop for the user to review
