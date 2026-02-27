# Writing Hub Mac App — Design Document

*Date: 2026-02-27*

---

## Overview

A native Mac app that turns a local folder of markdown files into a content operating system for solo creators. AI-powered writing agents run via Claude Code CLI in an embedded terminal. No server, no API keys, no account — users leverage their existing Claude subscription.

**Product model (Deepnote-style):** Open-source local Mac app as the free distribution engine. Future hosted version adds collaboration, managed agents, publishing API integrations, and analytics.

---

## Architecture

### Core Principles

- **Local-first** — the folder IS the database. No SQLite, no Core Data, just files.
- **Claude Code as AI engine** — embedded terminal runs Claude Code CLI. A `CLAUDE.md` file defines all agent behavior.
- **Git as invisible backbone** — app auto-commits on saves/agent actions. Users never see git. Version history exposed as a clean timeline UI.
- **No server, no auth** — the open-source version is fully self-contained.

### Tech Stack

- Swift + SwiftUI (native Mac app)
- FSEvents for real-time file watching
- libgit2 or shell git for silent version control
- Terminal emulation for Claude Code panel (styled to match app)

### Folder Structure

```
my-writing/
├── CLAUDE.md              # Instructions for Claude Code (agent brain)
├── voice-dna.md           # Generated writing voice profile
├── .writinghub/
│   └── config.json        # App preferences, cadence, platform prefs
├── references/            # Past writing samples for voice analysis
├── ideas/                 # Raw ideas, seed concepts
├── drafts/                # Work in progress
├── ready/                 # Ready to publish
└── published/             # Archive of published pieces
```

### File Format

Every content file uses YAML frontmatter + markdown body + platform sections:

```markdown
---
title: Why AI Will Eat Finance
created: 2026-02-27
edited: 2026-02-27
version: 3
stage: ready
platforms: [substack, x, linkedin]
---

# Why AI Will Eat Finance

The full longform piece lives here. This is the canonical version...

---

## X Thread

1/ The financial industry is about to change. Not gradually.

2/ Here's what nobody's talking about...

---

## LinkedIn

I've been thinking about AI in finance...

---

## Substack Intro Hook

You're about to lose your job to a model that doesn't sleep...
```

**Frontmatter rules:**
- `created` — set once on file creation
- `edited` — updated automatically on every save
- `version` — incremented on each agent rewrite (not manual edits)
- `stage` — current pipeline stage (ideas/drafts/ready/published)
- `platforms` — which platform sections exist in the file

---

## UI Layout

Single-window, three-panel layout:

```
┌─────────────────────────────────────────────────────────┐
│  Writing Hub                              ⚙️  Settings  │
├──────────────┬──────────────────────┬───────────────────┤
│              │                      │                   │
│  PIPELINE    │   EDITOR (WYSIWYG)  │  CLAUDE CODE      │
│  SIDEBAR     │                     │  TERMINAL         │
│              │                      │                   │
│  ▼ Ideas (3) │                      │                   │
│    idea-1.md │  [Rich markdown      │  [Styled terminal │
│    idea-2.md │   editor renders     │   running Claude  │
│    idea-3.md │   inline — headers,  │   Code CLI]       │
│              │   bold, links, etc.  │                   │
│  ▼ Drafts (2)│   No raw syntax     │                   │
│    draft-1   │   visible]           │                   │
│    draft-2   │                      │                   │
│              │                      │                   │
│  ▼ Ready (1) │                      │                   │
│    post-1    │                      │                   │
│              │                      │                   │
│  ▸ Published │                      │                   │
│    (12)      │                      │                   │
├──────────────┴──────────────────────┴───────────────────┤
│  Pipeline: 3 ideas → 2 drafts → 1 ready │ Cadence:     │
│  2x/week ✓ │ Next publish: Tue Feb 28                   │
└─────────────────────────────────────────────────────────┘
```

### Left Panel — Pipeline Sidebar

- Files grouped by stage: Ideas / Drafts / Ready / Published
- Collapsible sections with counts
- Drag and drop between stages (moves file on disk, updates frontmatter)
- Right-click context menu: promote, rename, delete, open in Finder

### Center Panel — WYSIWYG Editor

- Native SwiftUI rich text editor rendering markdown inline (Bear/Craft style)
- Headers, bold, italic, links, lists render as formatted text — no raw markdown visible
- Saves as plain `.md` on disk
- Auto-saves (debounced ~1s), auto-commits to git silently
- Updates `edited` date in frontmatter on save
- When agent runs `/edit`, shows before/after diff view for accept/reject

### Right Panel — Claude Code Terminal

- Styled embedded terminal running Claude Code CLI
- Resizable — can collapse for full-width editing or expand for focused agent work
- User types commands (`/draft`, `/critique`, etc.)
- Claude Code reads `CLAUDE.md`, follows instructions, modifies files on disk
- App detects file changes via FSEvents and updates UI in real-time

### Bottom Bar — Status Strip

- Pipeline counts at a glance
- Publishing cadence health (on track / slipping)
- Next scheduled publish date
- Streak indicator

---

## Agent Commands

All agent behavior is defined in `CLAUDE.md`, not in app code. Users type commands in the Claude Code terminal.

| Command | Stage | Action |
|---------|-------|--------|
| `/createvoicedna` | Setup | Read `references/`, ask platform prefs + author influences + things to avoid, generate `voice-dna.md` |
| `/brainstorm [topic]` | Ideation | Generate 10 angles/hooks from a seed concept, save as new file in `ideas/` |
| `/draft [file]` | Ideas → Drafts | Write full first draft in user's voice, move to `drafts/`, update frontmatter |
| `/edit [file]` | Drafts | Tighten prose, apply Humanizer patterns + voice DNA, show inline diffs |
| `/critique [file]` | Drafts | Find weak arguments, gaps, unsupported claims. Append critique as comments — no rewriting |
| `/replicate [file]` | Ready | Generate platform sections based on configured platforms, append to file |
| `/promote [file]` | Any → Next | Move file to next pipeline stage, update `stage` in frontmatter |
| `/status` | Any | Pipeline counts, cadence health, stale drafts, what needs attention |

**Every command:**
- References `voice-dna.md` for voice fidelity
- Runs Humanizer anti-AI-patterns as a final pass (based on [blader/humanizer](https://github.com/blader/humanizer))
- Updates frontmatter (`edited`, `version` on rewrites)

---

## Voice DNA System

### Generation (`/createvoicedna`)

1. Reads all files in `references/`
2. Asks: "What platforms do you publish on?" → saves to `.writinghub/config.json`
3. Asks: "Any writers or authors whose style you admire?"
4. Asks: "Anything you want to avoid in your writing?"
5. Analyzes samples for patterns: sentence length, vocabulary, tone, structure, hooks
6. Applies Humanizer 24-pattern framework as anti-AI baseline
7. Generates `voice-dna.md`
8. Shows summary and asks for adjustments

### `voice-dna.md` Structure

```markdown
# Voice DNA — [User Name]

## Core Voice
- [Tone, perspective, general style]

## Vocabulary
- Preferred: [words/phrases the user naturally uses]
- Avoid: [words/phrases to never use]

## Sentence Patterns
- [Structural habits: sentence length, transitions, punctuation]

## Influences
- [Authors/writers and what to borrow from each]

## Anti-Patterns (Humanizer Baseline)
- No significance inflation ("groundbreaking", "revolutionary")
- No hedging ("it's worth noting that...")
- No AI vocabulary ("testament", "tapestry", "nuanced", "delve")
- No sycophantic tone
- No em-dash overuse
- [Full 24-pattern list from Humanizer]

## Examples of Good Writing
[Excerpts from references/ that exemplify the voice]

## Examples of Bad Writing
[Counter-examples showing what to avoid]
```

Can be re-run anytime as the user's voice evolves.

---

## Real-time File Sync

### File changes on disk (from Claude Code)

- Pipeline sidebar updates immediately
- Open file in editor refreshes content
- Frontmatter metadata updates in sidebar

### User edits in editor

- Saves to disk on pause (debounced ~1s)
- Auto-commits to git silently
- Updates `edited` date in frontmatter

### Conflict handling

- If Claude Code writes to a file the user is editing → non-intrusive banner: "This file was updated by Claude. Show changes?"
- User can accept new version or keep theirs

---

## Publishing

### Configuration

- Preferred platforms set during `/createvoicedna`, stored in `.writinghub/config.json`
- `/replicate` generates sections only for configured platforms

### Publish Flow

1. Right-click a `ready/` file → "Publish to..." → pick platform
2. App extracts that platform's section from the file
3. Copies to clipboard + opens platform's compose page in browser
4. User confirms publish → app updates `stage: published`, moves to `published/`

### Cadence Tracking

- Desired cadence stored in `.writinghub/config.json` (e.g., "2x/week")
- Bottom status bar: on track / behind / streak count
- `/status` gives detailed breakdown

---

## Onboarding (First Launch)

1. **Pick a folder** — native file picker: "Choose or create a folder for your writing hub"
2. **Scaffold** — app creates folder structure, `CLAUDE.md`, initializes git
3. **Drop writing samples** — prompt user to add past writing to `references/`
4. **Run `/createvoicedna`** — terminal opens, user runs the command, Claude Code generates voice DNA interactively

---

## Future (Hosted Version)

Not in scope for MVP, but the open-source → hosted path includes:

- Managed agents (no Claude Code needed, runs on your infra)
- Real-time collaboration (multiple writers on a team)
- Direct publishing via platform APIs (Substack, X, LinkedIn OAuth)
- Publishing analytics (what resonates, optimal posting times)
- Version history timeline UI (visual git history)
- Voice DNA marketplace (buy/sell writing style profiles)

---

## Open Questions

- **Terminal emulation in SwiftUI** — need to evaluate libraries (SwiftTerm, or shell out to a PTY). This is the most technically uncertain component.
- **WYSIWYG markdown editor** — evaluate existing Swift libraries (Ink, Down, swift-markdown) vs. building on NSTextView/TextKit 2.
- **App Store distribution** — embedded terminal + Claude Code dependency may conflict with App Store sandboxing. May need to distribute outside App Store (DMG/Homebrew).
- **Claude Code updates** — app depends on Claude Code CLI being installed. Need graceful handling if it's missing or outdated.
