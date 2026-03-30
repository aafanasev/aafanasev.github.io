# afanasev.net

Personal tech blog at [afanasev.net](https://afanasev.net), built with [Jekyll](https://jekyllrb.com) and hosted on GitHub Pages.

## Repo layout

This repo has an unconventional structure required by GitHub Pages:

```
/                   ← generated site output (do not edit directly)
├── _jekyll/        ← all source files live here
│   ├── _posts/     ← blog posts
│   ├── _drafts/    ← unpublished drafts
│   ├── _config.yml ← site configuration
│   └── ...
└── .github/
    └── workflows/
        └── deploy.yaml
```

The root-level HTML, XML, and asset files are the compiled output of the Jekyll build — managed automatically by CI. **All content and configuration changes go in `_jekyll/`.**

## Local development

```bash
cd _jekyll
bundle install
bundle exec jekyll serve
```

The site will be available at `http://localhost:4000`.

## Writing a post

Create a new file in `_jekyll/_posts/` following the naming convention `YYYY-MM-DD-slug.md`:

```markdown
---
layout: post
title:  Your Post Title
date:   2025-01-01 12:00:00 +0700
categories: kotlin android
---

Post content here.
```

**Existing categories:** `kotlin`, `kotlin-library`, `android`, `data-class`

Drafts go in `_jekyll/_drafts/` and are excluded from the build until moved to `_posts/`.

## Deployment

Pushing to `master` with any changes under `_jekyll/` triggers the GitHub Actions workflow:

1. Builds the site with `bundle exec jekyll build`
2. Copies the output from `_jekyll/_site/` to the repo root
3. Opens a pull request with the generated changes

Merge the PR to publish.
