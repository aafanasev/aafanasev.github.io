# CLAUDE.md

Instructions for Claude Code working in this repository.

## Repo structure

The root directory contains the **generated site output** committed for GitHub Pages. Do not edit root-level files like `index.html`, `feed.xml`, `sitemap.xml`, or the category folders (`kotlin/`, `android/`, etc.) — they are overwritten on every CI build.

All source work happens in `_jekyll/`:

| Path | Purpose |
|------|---------|
| `_jekyll/_posts/` | Published blog posts |
| `_jekyll/_drafts/` | Unpublished drafts |
| `_jekyll/_config.yml` | Site configuration |
| `_jekyll/_includes/` | Liquid template partials |
| `_jekyll/_plugins/` | Custom Ruby plugins |
| `_jekyll/assets/img/` | Images referenced by posts |
| `.github/workflows/deploy.yaml` | CI/CD build and deploy workflow |

## Adding a post

Create `_jekyll/_posts/YYYY-MM-DD-slug.md` with this frontmatter:

```yaml
---
layout: post
title:  Post Title
date:   YYYY-MM-DD HH:MM:SS +0700
categories: kotlin android
---
```

Existing categories: `kotlin`, `kotlin-library`, `android`, `data-class`

## Deployment flow

```
push to master (changes in _jekyll/**)
  → GitHub Actions: bundle exec jekyll build
  → copies _jekyll/_site/* to repo root
  → opens PR with auto-deploy label
  → merge PR to publish
```

Never commit generated output (root HTML/XML/assets) manually — CI owns those files.

## Ruby version

3.4.2 — set in `.github/workflows/deploy.yaml` and used by Bundler.

## Site config

- **URL**: https://afanasev.net
- **Theme**: minima 2.5
- **Plugins**: jekyll-feed, jekyll-tidy, jekyll-sitemap
- **Comments**: Disqus (`afanasev-net`)
- **Analytics**: Google Analytics UA-60387111-7
