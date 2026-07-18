# 📓 Obsidian Note-Taking Agent

## Vault Structure
My vault follows a PARA/Zettelkasten hybrid:
- `00 - Inbox/` → Quick capture, unprocessed notes
- `01 - MOCs/` → Content maps (thematic indexes)
- `02 - Areas/` → Ongoing responsibilities
- `03 - Projects/` → Active projects with defined goals
- `04 - Resources/` → Snippets, references, documentation
- `05 - Archives/` → Completed or inactive material
- `99 - Meta/` → Templates, conventions

## Note Frontmatter (always include)
---
title: <title>
description: <one line>
date_created: <YYYY-MM-DD>
tags: [<tag1>, <tag2>]
category: <devops|fivem|homelab|web|general>
status: active
---

## When to Create Notes

### Explicit
If I say "guarda una nota", "anota esto", "crea una nota de X" → create it immediately.

### Proactive (do this automatically, without me asking)
During any session, if you detect:
- A repeatable process we followed (SSH key import, cert renewal, docker setup, etc.)
- A non-obvious config or fix that took effort to figure out
- A command sequence worth reusing
- A decision or architecture choice worth preserving

→ Create the note silently, then notify me: `📓 Guardé una nota: "<title>" en <path>`

## Note Format
Notes are quick references, NOT documentation.

✅ DO:
- Numbered steps and bullet points only
- Commands inline (`ssh-keygen -t ed25519 -C "label"`)
- One-line context per step only when strictly necessary
- WikiLinks to related notes ([[Related Note]])

❌ DON'T:
- Paragraphs of explanation
- "This is important because..." intros
- Redundant context already obvious from the title

## Where to Save

| Content type | Destination |
|---|---|
| Unclassified / quick capture | `00 - Inbox/` |
| Repeatable process / snippet | `04 - Resources/<topic>/` |
| Tied to an active project | `03 - Projects/<project>/` |
| Ongoing responsibility | `02 - Areas/<area>/` |

If unsure → `00 - Inbox/` and notify me so I can process it later.

## MOC Auto-Linking (always do this after creating a note)
After saving any note:
1. Identify the relevant MOC in `01 - MOCs/` (Sysadmin y DevOps, FiveM Development, Web Development, Discord Bots)
2. If a matching MOC exists → append a WikiLink to the note under the appropriate section
3. If no MOC matches → save to `00 - Inbox/` and skip MOC linking
4. Never create a new MOC unless I explicitly ask for it

## WikiLinks
- Always use [[Note Title]] when referencing other notes inline
- When linking in a MOC, use format: `- [[Note Title]] — <one line description>`

<!-- markitdown-mcp -->
# MarkItDown MCP — Tool Usage Protocol

Use `mcp__markitdown__convert_to_markdown` as the FIRST choice for:
- URLs (http/https) — documentation, GitHub repos, articles, pages
- Local files — convert to `file:///home/...` before calling
- PDFs, Word (.docx), Excel (.xlsx/.xls), PowerPoint (.pptx)
- YouTube URLs — extracts transcription automatically
- EPUB, CSV, JSON, XML

## How to call it

The tool accepts a single `uri` parameter. Always use a proper URI scheme:
- Web: `https://example.com/page`
- Local file: `file:///home/TU_USER/Documents/file.pdf`
- Data URI: `data:text/plain;base64,...`

## Priority over other tools

| Situation | Use this, NOT that |
|---|---|
| User shares a URL to read | `mcp__markitdown__convert_to_markdown` NOT `FetchURL` |
| User shares a PDF or Word doc path | `mcp__markitdown__convert_to_markdown` NOT `Read` |
| Need to read a GitHub repo or docs page | `mcp__markitdown__convert_to_markdown` NOT `FetchURL` |
| User pastes a YouTube link | `mcp__markitdown__convert_to_markdown` NOT `FetchURL` |

## Why this matters

MarkItDown preserves document structure (headings, tables, lists, links) in a format optimized for LLM consumption. `FetchURL` returns raw HTML noise. `Read` can't handle binary formats. Always prefer `mcp__markitdown__convert_to_markdown` for any external or binary content.
<!-- /markitdown-mcp -->
