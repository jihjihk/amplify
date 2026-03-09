# Contributing to Amplify

Thanks for your interest in contributing!

## Dev Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/YOUR_ORG/amplify.git
   cd amplify/WritingHub
   ```

2. Build and run:
   ```bash
   swift build
   swift run
   ```

3. Run tests:
   ```bash
   swift test
   ```

Requires Xcode 16+ and macOS 14+.

## Code Style

- Swift 6 strict concurrency
- MVVM architecture (Views, ViewModels, Models, Services)
- `@MainActor` for all UI-facing classes
- `Sendable` conformance on all models
- Prefer composition over inheritance

## PR Process

1. Fork the repo and create a feature branch from `main`
2. Make your changes with clear, focused commits
3. Ensure `swift build && swift test` passes
4. Open a PR against `main` with a description of what and why
5. One approval required to merge

## Reporting Issues

Use GitHub Issues. Include:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console output if relevant

## Architecture Notes

- **FolderManager** handles file system operations (scaffold, save, load)
- **HubViewModel** coordinates FolderManager, FileWatcher, and GitService
- **SkillPack** defines folder structure + CLAUDE.md template per persona
- **FileWatcher** uses FSEvents with debouncing and self-write tracking
- **EditorView** uses MarkupEditor for WYSIWYG editing with debounced auto-save
