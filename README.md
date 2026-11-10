# afanasev.net

Personal tech blog at [afanasev.net](https://afanasev.net), built with [Hugo](https://gohugo.io) and the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme, hosted on GitHub Pages.

## Repo layout

This repo has an unconventional structure required by GitHub Pages:

```
/                       ← generated site output (do not edit directly)
├── _hugo/              ← all source files live here
│   ├── content/posts/  ← blog posts (drafts use `draft: true`)
│   ├── content/*.md    ← standalone pages (About, Projects)
│   ├── layouts/        ← overrides of theme templates
│   ├── static/         ← files copied as-is (images, robots.txt)
│   ├── themes/PaperMod ← theme (git submodule)
│   └── hugo.toml       ← site configuration
└── .github/
    └── workflows/
        └── deploy.yaml
```

The root-level HTML, XML, and asset files are the compiled output of the Hugo build — managed automatically by CI. **All content and configuration changes go in `_hugo/`.**

## Local development

Requires Hugo **extended** ≥ 0.158 (CI uses 0.169.0).

```bash
git submodule update --init   # fetch the theme after cloning
cd _hugo
hugo server -D                # -D also renders drafts
```

The site will be available at `http://localhost:1313`.

## Writing a post

Create a new file in `_hugo/content/posts/` named `YYYY-MM-DD-slug.md`:

```markdown
---
title: Your Post Title
date: 2026-01-01 12:00:00 +0700
categories: [kotlin, android]
---

Post content here.
```

New posts are published at `/YYYY/MM/DD/<slug>/`. Posts migrated from Jekyll keep their old URLs via a `url:` front matter field — don't change those.

Link to other posts with `{{< relref "2019-08-13-sekret" >}}`. External links open in a new tab automatically.

**Existing categories:** `kotlin`, `kotlin-library`, `android`, `data-class`, `jacoco`, `crashlytics`

## Deployment

Pushing to `master` with any changes under `_hugo/` triggers the GitHub Actions workflow:

1. Builds the site with `hugo --minify`
2. Copies the output from `_hugo/public/` to the repo root
3. Opens a pull request with the generated changes

Merge the PR to publish.
