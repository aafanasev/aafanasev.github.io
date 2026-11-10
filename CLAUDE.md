# CLAUDE.md

Instructions for Claude Code working in this repository.

## Repo structure

The root directory contains the **generated site output** committed for GitHub Pages. Do not edit root-level files like `index.html`, `feed.xml`, `sitemap.xml`, or the category folders (`kotlin/`, `android/`, etc.) — they are overwritten on every CI build.

All source work happens in `_hugo/`:

| Path | Purpose |
|------|---------|
| `_hugo/content/posts/` | Blog posts (drafts: `draft: true` in front matter) |
| `_hugo/content/*.md` | Standalone pages (About, Projects) |
| `_hugo/hugo.toml` | Site configuration |
| `_hugo/layouts/` | Overrides of PaperMod templates (Disqus comments, external-link hook) |
| `_hugo/static/` | Files copied verbatim (`assets/img/`, `robots.txt`) |
| `_hugo/themes/PaperMod/` | Theme — git submodule, don't edit; override in `_hugo/layouts/` instead |
| `.github/workflows/deploy.yaml` | CI/CD build and deploy workflow |

## Adding a post

Create `_hugo/content/posts/YYYY-MM-DD-slug.md` with this frontmatter:

```yaml
---
title: Post Title
date: YYYY-MM-DD HH:MM:SS +0700
categories: [kotlin, android]
---
```

Existing categories: `kotlin`, `kotlin-library`, `android`, `data-class`, `jacoco`, `crashlytics`

Posts migrated from Jekyll have a `url:` field pinning their legacy URL — never change or remove it. Link between posts with `{{< relref "YYYY-MM-DD-slug" >}}`. Don't use kramdown attribute syntax (`{:...}`); Hugo uses Goldmark.

## Deployment flow

```
push to master (changes in _hugo/**)
  → GitHub Actions: hugo --minify (theme fetched as submodule)
  → copies _hugo/public/* to repo root
  → opens PR with auto-deploy label
  → merge PR to publish
```

Never commit generated output (root HTML/XML/assets) manually — CI owns those files.

## Hugo version

0.169.0 extended — pinned in `.github/workflows/deploy.yaml`. PaperMod requires ≥ 0.158.

## Site config

- **URL**: https://afanasev.net
- **Theme**: PaperMod (submodule pinned to a commit)
- **Feed**: RSS at `/feed.xml` (renamed from Hugo's default `index.xml` to keep the old URL)
- **Sitemap**: built-in, `/sitemap.xml`
- **Comments**: Disqus (`afanasev-net`)
- **Analytics**: none (the old Universal Analytics ID was retired by Google)
