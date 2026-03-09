# Amplify

**The writing app for AI native writers.**

Amplify is a free, open-source macOS writing app built around Claude Code. File tree, rich Markdown editor, and an embedded Claude Code terminal — all in one window. Open a folder, run `create voice dna`, and start writing.

[Download for Mac](https://github.com/jihjihk/amplify/releases/latest) · [Landing page](https://jihjihk.github.io/amplify)

---

## What it does

- **IDE for writers** — File tree, WYSIWYG Markdown editor, and Claude Code terminal side by side. No switching apps.
- **Voice DNA** — One command builds a voice profile from your past writing. Every draft, edit, and brainstorm runs through it.
- **Bring your own subscription** — Uses Claude Code, which you already have. No separate API key, no extra billing.
- **100% local** — Every file is plain Markdown on your Mac. Nothing touches a server.
- **Humanizer checklist** — 24 anti-patterns baked into the CLAUDE.md so AI output doesn't sound like AI.
- **Auto-save + git** — Edits are debounced, saved, and auto-committed. Your writing history is preserved.

## Getting started

1. [Download Amplify.dmg](https://github.com/jihjihk/amplify/releases/latest), open it, drag to Applications
2. Right-click Amplify → Open (first launch only, app is ad-hoc signed)
3. Choose a folder as your workspace
4. In the terminal, run `create voice dna`
5. Start writing

**Requires:** macOS 14 Sonoma or later · [Claude Code](https://claude.ai/code) installed

## Commands

| Command | What it does |
|---------|-------------|
| `create voice dna` | Analyzes your reference writing, builds a voice profile |
| `create content strategy` | Generates a strategy doc: positioning, lanes, cadence |
| `brainstorm [topic]` | 10 angles and hooks, saved to `ideas/` |
| `draft [file]` | Full first draft in your voice |
| `edit [file]` | Tighten a draft, shows before/after |
| `critique [file]` | Honest feedback on argument and structure |
| `replicate [file]` | Adapts a piece for X, LinkedIn, and Substack |

## Build from source

Requires macOS 14+ and Swift 6+.

```bash
git clone https://github.com/jihjihk/amplify.git
cd amplify/WritingHub
swift build
swift run
```

## Architecture

```
WritingHub/
  Sources/
    WritingHub/          # App entry point, AppDelegate
    WritingHubLib/       # Core library
      Models/            # WritingPiece, FrontMatter, SkillPack, HubConfig, WorkspaceItem
      Views/             # Sidebar, EditorView, TabBar, TerminalPanelView, StatusBar
      ViewModels/        # HubViewModel
      Services/          # FolderManager, FileWatcher, GitService
      Resources/         # CLAUDETemplate, Fonts
  Tests/
    WritingHubTests/
landing/                 # Landing page (GitHub Pages)
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
