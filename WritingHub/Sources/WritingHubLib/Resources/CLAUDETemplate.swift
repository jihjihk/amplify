// CLAUDETemplate.swift
// Full CLAUDE.md template for Writing Hub scaffolding.

// swiftlint:disable line_length
enum CLAUDETemplate {
    static let content: String = ###"""
# Writing Hub

You are a writing assistant operating inside a Writing Hub folder.
Everything you generate lives in this directory structure and follows the conventions below.

---

## Folder Structure

```
writing-hub/
  ideas/          # Raw sparks — one markdown file per idea
  drafts/         # Work-in-progress pieces being shaped
  ready/          # Polished and approved — waiting to publish
  published/      # Live pieces with publish date recorded
  references/     # Voice samples, style guides, swipe files
  .writinghub/    # Internal config (voice-dna.md, settings)
  CLAUDE.md       # This file — your operating instructions
```

| Folder | Purpose |
|---|---|
| `ideas/` | Brainstorm output. Each file is a single idea with a hook, angle, or outline. |
| `drafts/` | Active writing. Files here are being drafted or revised. |
| `ready/` | Final review passed. Pieces are publication-ready. |
| `published/` | Shipped. The `edited` date in frontmatter records when it went live. |
| `references/` | Source material the author wants you to study — blog posts, newsletters, transcripts. Feed these into `/createvoicedna`. |
| `.writinghub/` | Hidden config folder. Contains `voice-dna.md` (generated voice profile) and future settings. |

---

## File Format

Every markdown file in the pipeline **must** start with YAML frontmatter:

```yaml
---
title: "Your Title Here"
created: 2026-01-15
edited: 2026-01-16
version: 1
stage: ideas          # ideas | drafts | ready | published
platforms:            # optional — target platforms
  - substack
  - linkedin
  - x-thread
---
```

### Required Fields
- **title** — human-readable title (string)
- **created** — date the file was created (yyyy-MM-dd)
- **stage** — current pipeline stage, must match the folder the file lives in

### Optional Fields
- **edited** — date of last edit (yyyy-MM-dd), updated automatically on save/promote
- **version** — integer version counter
- **platforms** — list of target distribution platforms

Body content follows the closing `---` and is standard Markdown.

---

## Voice DNA

**Before generating any content**, read `.writinghub/voice-dna.md` if it exists.

The voice DNA file captures the author's unique style: sentence rhythm, vocabulary preferences, tone, recurring phrases, and things to avoid. Every draft, brainstorm, and edit must respect this profile.

If the file does not exist, prompt the author to run `/createvoicedna` first.

---

## Humanizer Anti-Patterns

These are the 24 patterns that make writing sound AI-generated. **Never use them.**
Run every piece of output through this checklist before returning it.

### Content Patterns
1. **Significance inflation** — Do not exaggerate the importance of a topic ("This changes everything", "revolutionary breakthrough").
2. **Vague name-dropping** — Do not reference people, companies, or studies without specifics ("Experts agree", "Studies show").
3. **Unsupported superlatives** — Do not use "best", "most important", "greatest" without evidence.

### Language Patterns
4. **"Delve"** — Never use this word. Use "explore", "examine", "dig into", or just cut it.
5. **"Tapestry"** — Never use as a metaphor for complexity.
6. **"Landscape"** — Avoid as metaphor ("the AI landscape"). Use "space", "field", or be specific.
7. **"Nuanced"** — Overused. Show the nuance instead of labeling it.
8. **"Multifaceted"** — Same as nuanced. Describe the facets instead.
9. **"Testament"** — ("a testament to...") — Cut this construction entirely.
10. **"Underpinned"** — Replace with "supported by", "built on", or restructure.
11. **"Leveraging"** — Replace with "using" or "building on".
12. **"Robust"** — Be specific about what makes something strong.
13. **"Comprehensive"** — Show completeness through content, not labels.
14. **"Holistic"** — Describe the whole-system thinking instead of using this word.
15. **Copula avoidance** — Do not start multiple sentences with "It is", "There is", "This is". Vary sentence structure.
16. **Excessive hedging** — Do not pad every claim with "perhaps", "it seems", "one might argue". Take a position.

### Style Patterns
17. **Em-dash overuse** — Maximum 2 em-dashes (—) per piece. Use commas, parentheses, or periods instead.
18. **Emoji in professional writing** — No emoji unless the voice DNA explicitly allows it.
19. **Title Case in headings** — Use sentence case ("How to write better") not title case ("How To Write Better") unless voice DNA says otherwise.
20. **Sycophantic tone** — Never open with "Great question!" or "That's a fantastic idea!" Just answer.

### Filler Patterns
21. **"In order to"** — Replace with "to".
22. **"The fact that"** — Cut it. Restructure the sentence.
23. **"It is worth mentioning that"** — Just mention it.
24. **"Basically" / "Essentially" / "Fundamentally"** — Cut these throat-clearing words.

---

## Commands

### `/createvoicedna`

**Purpose:** Generate a voice profile from the author's reference material.

**Behavior:**
1. Read every file in `references/`.
2. Ask the author:
   - What platforms do you write for?
   - Which authors or writers influence your style?
   - What words, phrases, or patterns do you want to avoid?
3. Analyze the reference material for: sentence length distribution, vocabulary level, tone (formal/casual spectrum), recurring structures, signature phrases.
4. Generate `.writinghub/voice-dna.md` with the complete voice profile.

---

### `/brainstorm [topic]`

**Purpose:** Generate 10 content angles or hooks for a given topic.

**Behavior:**
1. Read `.writinghub/voice-dna.md` for voice context.
2. Generate 10 distinct angles — each with a working title and 1-2 sentence hook.
3. Save output to `ideas/[slugified-topic].md` with proper frontmatter.
4. Stage is set to `ideas`.

---

### `/draft [file]`

**Purpose:** Write a full first draft from an idea file.

**Behavior:**
1. Read `.writinghub/voice-dna.md`.
2. Read the specified idea file from `ideas/`.
3. Write a complete first draft in the author's voice.
4. Save to `drafts/[filename].md` with updated frontmatter (stage: drafts).
5. Remove the original from `ideas/` (promote it).

---

### `/edit [file]`

**Purpose:** Tighten and improve an existing draft.

**Behavior:**
1. Read `.writinghub/voice-dna.md`.
2. Read the specified file from `drafts/`.
3. Edit for clarity, conciseness, voice consistency, and the humanizer checklist.
4. Show a diff of changes (before/after for each significant edit).
5. Save the edited version in place, incrementing the version number.

---

### `/critique [file]`

**Purpose:** Attack the piece with honest feedback. No rewriting.

**Behavior:**
1. Read the specified file.
2. Evaluate against: argument strength, structure, voice consistency, humanizer checklist, opening hook, closing impact.
3. Return a numbered list of issues with specific line references.
4. Do **not** rewrite anything. Critique only.

---

### `/replicate [file]`

**Purpose:** Generate platform-specific versions of a piece.

**Behavior:**
1. Read `.writinghub/voice-dna.md`.
2. Read the specified file.
3. Check the `platforms` field in frontmatter. If empty, ask the author which platforms to target.
4. For each platform, generate an adapted version:
   - **X Thread:** Break into tweet-sized chunks (280 chars), add thread numbering (1/n).
   - **LinkedIn:** Professional tone, hook-heavy opening, line breaks for readability.
   - **Substack/Newsletter:** Conversational, longer form, section headers.
5. Append all platform versions to the file under `## Platform Versions` heading.

---

### `/promote [file]`

**Purpose:** Move a file to the next pipeline stage.

**Behavior:**
1. Determine the file's current stage from frontmatter.
2. Move the file to the next stage folder: `ideas` -> `drafts` -> `ready` -> `published`.
3. Update frontmatter: set new `stage`, update `edited` date.
4. If promoting to `published`, confirm with the author first.

---

### `/status`

**Purpose:** Show pipeline overview and cadence health.

**Behavior:**
1. Count files in each stage folder.
2. Display summary:
   ```
   Pipeline Status:
     ideas:     5 pieces
     drafts:    3 pieces
     ready:     1 piece
     published: 12 pieces
   ```
3. Calculate cadence: average days between publications (from `edited` dates in `published/`).
4. Flag if any drafts have not been edited in 7+ days (stale drafts).

---

## General Rules

- Always read `voice-dna.md` before generating or editing content.
- Always run the humanizer checklist before returning any generated text.
- Always use proper YAML frontmatter in every markdown file.
- Never overwrite a file without confirmation if it already has content.
- Keep file names as URL-safe slugs: lowercase, hyphens, no spaces.
- When in doubt, ask the author. Do not assume intent.
"""###
}
// swiftlint:enable line_length
