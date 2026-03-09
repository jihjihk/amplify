# Amplify Feature Pack Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add file tabs, find-in-file, drag/cut/copy/paste file ops, panel toggles, fix toolbar background, and fix CLAUDE.md name/use case persistence.

**Architecture:** Tabs live in HubViewModel (openTabs array + activeTabIndex). Find uses WKWebView native find API via weak ref in EditorInputDelegate. File ops use SwiftUI draggable/dropDestination + clipboard state in HubViewModel. Panel toggles are Bool state in ContentView driving conditional HSplitView children.

**Tech Stack:** SwiftUI, MarkupEditor (WKWebView), FileManager, Swift Testing framework

---

## Task 1: Fix — CLAUDE.md not saving name/use case

**Root cause:** `HubViewModel.openFolder(_:skill:)` calls `manager.scaffold(skill:)` with default `name:"you"` and `useCase:""` on every open, overwriting the correct CLAUDE.md that onboarding wrote.

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/ViewModels/HubViewModel.swift`
- Modify: `WritingHub/Sources/WritingHubLib/Views/ContentView.swift`
- Modify: `WritingHub/Tests/WritingHubTests/FolderManagerTests.swift`

**Step 1: Update `HubViewModel.openFolder` signature**

In `HubViewModel.swift`, change the signature and scaffold call:

```swift
// BEFORE
public func openFolder(_ url: URL, skill: SkillPack = .founder) throws {
    let manager = FolderManager(root: url)
    try manager.scaffold(skill: skill)

// AFTER
public func openFolder(_ url: URL, skill: SkillPack = .founder, name: String = "you", useCase: String = "") throws {
    let manager = FolderManager(root: url)
    try manager.scaffold(skill: skill, name: name, useCase: useCase)
```

**Step 2: Update `ContentView.openFolder` to pass name + useCase**

In `ContentView.swift`, `openFolder(_:skill:name:)`:

```swift
private func openFolder(_ url: URL, skill: SkillPack, name: String) {
    let existing = HubConfig.load(from: url)
    let useCase = existing?.useCase ?? ""
    let resolvedName = existing?.name ?? name
    try? viewModel.openFolder(url, skill: skill, name: resolvedName, useCase: useCase)
    let config = HubConfig(name: resolvedName, skillPack: skill, useCase: useCase)
    config.save(to: url)
    viewModel.config = config
    viewModel.skillPack = skill
}
```

**Step 3: Add test for name/useCase in CLAUDE.md**

In `FolderManagerTests.swift`, add:

```swift
@Test("scaffold embeds name and useCase in CLAUDE.md")
func testScaffoldEmbedsMeta() throws {
    defer { cleanup() }
    let manager = FolderManager(root: tempDir)
    try manager.scaffold(skill: .founder, name: "Ji", useCase: "Founder building audience")
    let content = try String(contentsOf: tempDir.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
    #expect(content.contains("Ji"))
    #expect(content.contains("Founder building audience"))
}
```

**Step 4: Run tests**
```
swift test --filter FolderManagerTests
```
Expected: all pass.

**Step 5: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/ViewModels/HubViewModel.swift \
        WritingHub/Sources/WritingHubLib/Views/ContentView.swift \
        WritingHub/Tests/WritingHubTests/FolderManagerTests.swift
git commit -m "fix: pass name+useCase through openFolder so CLAUDE.md is personalized"
```

---

## Task 2: Fix — Toolbar background transparency

**Root cause:** The MarkupEditor toolbar renders inside the shadow DOM with `position: sticky; top: 0` but `background` may be `transparent` or `inherit`. The CSS we inject has `background: var(--toolbar-bg)` but needs `z-index` and an explicit `position` to create a stacking context so the editor content scrolls behind it.

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/Views/EditorView.swift` (the CSS block in `editorStyleScript`)

**Step 1: Strengthen toolbar CSS**

Find the `.Markup-toolbar` block in `EditorView.swift` and replace with:

```css
.Markup-toolbar {
    position: sticky !important;
    top: 0 !important;
    z-index: 100 !important;
    background: var(--toolbar-bg) !important;
    backdrop-filter: none !important;
    -webkit-backdrop-filter: none !important;
    border-bottom: 1px solid var(--sep) !important;
    padding: 4px 8px !important;
    gap: 4px !important;
    align-items: center !important;
    color: var(--ink-4) !important;
    fill: var(--ink-4) !important;
    box-shadow: 0 1px 0 var(--sep) !important;
}
```

Also ensure the shadow root host and editor wrapper don't create transparent backgrounds that bleed through:

```css
:host {
    display: flex !important;
    flex-direction: column !important;
    background: var(--bg) !important;
}
```

**Step 2: Build and visually verify**
```
swift build
```
Launch app, open a file, scroll editor content — toolbar should remain opaque with parchment background.

**Step 3: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/Views/EditorView.swift
git commit -m "fix: make editor toolbar background opaque with sticky positioning"
```

---

## Task 3: File Tabs — HubViewModel

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/ViewModels/HubViewModel.swift`

**Step 1: Add tab state**

Add these published properties to `HubViewModel`:

```swift
@Published public var openTabs: [WritingPiece] = []
@Published public var activeTabIndex: Int = 0
@Published public var dirtyTabPaths: Set<URL> = []
```

Make `selectedFile` a computed proxy (keep the existing `@Published var selectedFile` for now but sync it):

Actually replace `selectedFile` entirely with a computed property backed by `openTabs`:

```swift
// Remove: @Published public var selectedFile: WritingPiece?

public var selectedFile: WritingPiece? {
    get { openTabs.indices.contains(activeTabIndex) ? openTabs[activeTabIndex] : nil }
    set {
        if let newValue {
            openTab(newValue)
        }
    }
}
```

**Note:** Because `selectedFile` is no longer `@Published`, views that observe it via `$selectedFile` must switch to observing `openTabs` + `activeTabIndex`. But since `HubViewModel` is `ObservableObject` and we call `objectWillChange.send()` when tabs change, views that use `viewModel.selectedFile` will still update correctly.

**Step 2: Add tab management methods**

```swift
// MARK: - Tab Management

public func openTab(_ piece: WritingPiece) {
    if let idx = openTabs.firstIndex(where: { $0.filePath == piece.filePath }) {
        activeTabIndex = idx
    } else {
        openTabs.append(piece)
        activeTabIndex = openTabs.count - 1
    }
    objectWillChange.send()
}

public func closeTab(at index: Int) {
    guard openTabs.indices.contains(index) else { return }
    openTabs.remove(at: index)
    if openTabs.isEmpty {
        activeTabIndex = 0
    } else {
        activeTabIndex = min(activeTabIndex, openTabs.count - 1)
    }
    objectWillChange.send()
}

public func closeActiveTab() {
    closeTab(at: activeTabIndex)
}
```

**Step 3: Update `reload()` to sync open tabs**

In `reload()`, after refreshing `selectedFile`, also refresh stale tab content:

```swift
public func reload() {
    guard let folderManager else { return }

    // Refresh each open tab from disk
    openTabs = openTabs.compactMap { tab in
        guard let path = tab.filePath else { return tab }
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        if let content = try? String(contentsOf: path, encoding: .utf8),
           var fresh = try? WritingPiece.parse(from: content) {
            fresh.filePath = path
            return fresh
        }
        return tab
    }
    // Clamp activeTabIndex
    if !openTabs.isEmpty {
        activeTabIndex = min(activeTabIndex, openTabs.count - 1)
    }

    workspaceFiles = folderManager.loadWorkspaceFiles()
    objectWillChange.send()
}
```

**Step 4: Mark tab dirty on save**

In `savePiece`, after save update `dirtyTabPaths`:
```swift
dirtyTabPaths.remove(piece.filePath ?? URL(fileURLWithPath: ""))
```

And in `EditorView`, when the user edits, call:
```swift
if let path = viewModel.selectedFile?.filePath {
    viewModel.dirtyTabPaths.insert(path)
}
```

**Step 5: Build**
```
swift build
```

**Step 6: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/ViewModels/HubViewModel.swift
git commit -m "feat: add tab state (openTabs, activeTabIndex, dirtyTabPaths) to HubViewModel"
```

---

## Task 4: File Tabs — TabBar view

**Files:**
- Create: `WritingHub/Sources/WritingHubLib/Views/TabBar.swift`
- Modify: `WritingHub/Sources/WritingHubLib/Views/ContentView.swift`

**Step 1: Create TabBar.swift**

```swift
import SwiftUI

struct TabBar: View {
    @ObservedObject var viewModel: HubViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.openTabs.enumerated()), id: \.offset) { idx, tab in
                    TabPill(
                        tab: tab,
                        isActive: idx == viewModel.activeTabIndex,
                        isDirty: viewModel.dirtyTabPaths.contains(tab.filePath ?? URL(fileURLWithPath: "")),
                        onSelect: { viewModel.activeTabIndex = idx; viewModel.objectWillChange.send() },
                        onClose: { viewModel.closeTab(at: idx) }
                    )
                }
            }
        }
        .frame(height: 36)
        .background(AmplifyColors.barBg)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct TabPill: View {
    let tab: WritingPiece
    let isActive: Bool
    let isDirty: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    private var label: String {
        tab.filePath?.deletingPathExtension().lastPathComponent
            ?? tab.frontMatter.title
            ?? "Untitled"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)

            Text(label)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? AmplifyColors.inkPrimary : AmplifyColors.inkSecondary)
                .lineLimit(1)

            // Dirty indicator or close button
            ZStack {
                if isDirty && !isHovered {
                    Circle()
                        .fill(AmplifyColors.accent)
                        .frame(width: 6, height: 6)
                } else {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered || isActive ? 1 : 0)
                }
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isActive
                ? AmplifyColors.surface
                : Color.clear
        )
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(AmplifyColors.accent)
                    .frame(height: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}
```

**Step 2: Insert TabBar above EditorView in ContentView**

In `ContentView.swift`, inside the `HSplitView`, wrap `EditorView` in a `VStack`:

```swift
VStack(spacing: 0) {
    if !viewModel.openTabs.isEmpty {
        TabBar(viewModel: viewModel)
    }
    EditorView(viewModel: viewModel)
        .frame(minWidth: 400)
}
```

**Step 3: Update Sidebar's `selectFile` to use `openTab`**

In `Sidebar.swift`, change `selectFile`:

```swift
private func selectFile(at url: URL) {
    guard url.pathExtension == "md",
          let content = try? String(contentsOf: url, encoding: .utf8),
          var piece = try? WritingPiece.parse(from: content)
    else { return }
    piece.filePath = url
    viewModel.openTab(piece)
}
```

**Step 4: Add Cmd+W keyboard shortcut**

In `ContentView.swift` body or the editor VStack:

```swift
.keyboardShortcut("w", modifiers: .command)
// On trigger:
viewModel.closeActiveTab()
```

Use `.commands` block in `WritingHubApp.swift` or add a hidden button.

**Step 5: Build and verify**
```
swift build
```
Open 2-3 files — tabs appear. Click × — tab closes. Cmd+W closes active.

**Step 6: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/Views/TabBar.swift \
        WritingHub/Sources/WritingHubLib/Views/ContentView.swift \
        WritingHub/Sources/WritingHubLib/Views/Sidebar.swift
git commit -m "feat: add file tab bar with dirty indicator and Cmd+W close"
```

---

## Task 5: Panel Toggles (Sidebar + Terminal)

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/Views/ContentView.swift`

**Step 1: Add toggle state**

In `ContentView`, add:

```swift
@State private var showSidebar: Bool = true
@State private var showTerminal: Bool = true
```

**Step 2: Wrap HSplitView children with conditionals**

```swift
HSplitView {
    if showSidebar {
        Sidebar(viewModel: viewModel)
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
            .transition(.move(edge: .leading))
    }

    VStack(spacing: 0) {
        if !viewModel.openTabs.isEmpty {
            TabBar(viewModel: viewModel)
        }
        EditorView(viewModel: viewModel)
    }
    .frame(minWidth: 400)

    if showTerminal {
        VStack(spacing: 0) {
            // terminal header bar...
            if let root = viewModel.folderManager?.root {
                TerminalPanelView(folderPath: root)
            }
        }
        .frame(minWidth: 300, idealWidth: 380, maxWidth: 500)
        .transition(.move(edge: .trailing))
    }
}
```

**Step 3: Add toggle buttons to BrandingHeader or StatusBar**

In `BrandingHeader`, add at the trailing edge:

```swift
HStack(spacing: 8) {
    Button {
        withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() }
    } label: {
        Image(systemName: "sidebar.left")
            .font(.system(size: 13))
            .foregroundStyle(showSidebar ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)
    }
    .buttonStyle(.plain)
    .help("Toggle Sidebar (⌘\\)")
    .keyboardShortcut("\\", modifiers: .command)

    Button {
        withAnimation(.easeInOut(duration: 0.2)) { showTerminal.toggle() }
    } label: {
        Image(systemName: "terminal")
            .font(.system(size: 13))
            .foregroundStyle(showTerminal ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)
    }
    .buttonStyle(.plain)
    .help("Toggle Terminal (⌘⌥T)")
    .keyboardShortcut("t", modifiers: [.command, .option])
}
```

Note: `BrandingHeader` needs `showSidebar` and `showTerminal` bindings passed in, or move toggles to ContentView's toolbar overlay.

**Step 4: Build**
```
swift build
```

**Step 5: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/Views/ContentView.swift
git commit -m "feat: add sidebar and terminal panel toggle buttons with keyboard shortcuts"
```

---

## Task 6: Find in File (Cmd+F)

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/Views/EditorView.swift`

**Step 1: Capture WKWebView reference in EditorInputDelegate**

Add to `EditorInputDelegate`:

```swift
weak var webView: MarkupWKWebView?

func markupDidLoad(_ view: MarkupWKWebView, handler: (() -> Void)?) {
    webView = view
    handler?()
}

func findText(_ query: String, forward: Bool = true) {
    guard !query.isEmpty, let webView else { return }
    let config = WKFindConfiguration()
    config.backwards = !forward
    config.wraps = true
    config.caseSensitive = false
    webView.find(query, configuration: config) { _ in }
}

func clearFind() {
    guard let webView else { return }
    // Clear highlights by finding empty string
    let config = WKFindConfiguration()
    webView.find("", configuration: config) { _ in }
}
```

**Step 2: Add FindBar view inside EditorView**

Add state to `EditorView`:

```swift
@State private var showFind = false
@State private var findQuery = ""
@FocusState private var findFieldFocused: Bool
```

Add `FindBar` as an overlay at the top of the editor ZStack:

```swift
ZStack(alignment: .topLeading) {
    VStack(spacing: 0) {
        if let piece = viewModel.selectedFile { titleBar(for: piece) }
        Divider()...
        MarkupEditorView(...)
    }

    if showFind {
        FindBar(
            query: $findQuery,
            isFocused: $findFieldFocused,
            onNext: { editorDelegate.findText(findQuery, forward: true) },
            onPrev: { editorDelegate.findText(findQuery, forward: false) },
            onDismiss: {
                showFind = false
                findQuery = ""
                editorDelegate.clearFind()
            }
        )
        .padding(.top, 44) // below title bar
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
.keyboardShortcut("f", modifiers: .command)  // attached to the ZStack via a hidden button
```

**FindBar struct:**

```swift
struct FindBar: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let onNext: () -> Void
    let onPrev: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            TextField("Find", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .frame(width: 180)
                .onSubmit { onNext() }
                .onChange(of: query) { _, _ in onNext() }

            Button(action: onPrev) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(AmplifyColors.inkSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AmplifyColors.barBg)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        )
        .onExitCommand { onDismiss() }
    }
}
```

**Step 3: Wire Cmd+F**

Add a hidden button or `.onKeyPress` to toggle find:

```swift
// In EditorView body, add a background key handler:
.background(
    Button("") { withAnimation { showFind.toggle(); if showFind { findFieldFocused = true } } }
        .keyboardShortcut("f", modifiers: .command)
        .hidden()
)
```

**Step 4: Build**
```
swift build
```

**Step 5: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/Views/EditorView.swift
git commit -m "feat: add find-in-file with Cmd+F using WKWebView native find API"
```

---

## Task 7: File Ops — Drag to Move

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/Views/Sidebar.swift`

**Step 1: Add drag source on file rows**

In `WorkspaceItemRow.fileRow`, add:

```swift
.draggable(item.path)
```

`URL` conforms to `Transferable` natively in macOS 13+.

**Step 2: Add drop target on folder rows**

In the `DisclosureGroup` label of `folderRow`, add:

```swift
.dropDestination(for: URL.self) { droppedURLs, _ in
    guard let source = droppedURLs.first else { return false }
    let dest = item.path.appendingPathComponent(source.lastPathComponent)
    guard source != dest else { return false }
    do {
        try FileManager.default.moveItem(at: source, to: dest)
        onReload()
        return true
    } catch {
        return false
    }
} isTargeted: { isTargeted in
    // Optional: highlight folder on hover
}
```

**Step 3: Build and verify**
```
swift build
```
Drag a file from one folder to another in the sidebar.

**Step 4: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/Views/Sidebar.swift
git commit -m "feat: drag-to-move files between folders in sidebar"
```

---

## Task 8: File Ops — Cut / Copy / Paste

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/ViewModels/HubViewModel.swift`
- Modify: `WritingHub/Sources/WritingHubLib/Views/Sidebar.swift`

**Step 1: Add clipboard state to HubViewModel**

```swift
public struct FileClipboard {
    public let url: URL
    public let isCut: Bool
}

// In HubViewModel:
@Published public var fileClipboard: FileClipboard? = nil

public func copyFile(_ url: URL) {
    fileClipboard = FileClipboard(url: url, isCut: false)
}

public func cutFile(_ url: URL) {
    fileClipboard = FileClipboard(url: url, isCut: true)
}

public func pasteFile(into folderURL: URL) {
    guard let clip = fileClipboard else { return }
    let dest = folderURL.appendingPathComponent(clip.url.lastPathComponent)
    do {
        if clip.isCut {
            try FileManager.default.moveItem(at: clip.url, to: dest)
            fileClipboard = nil
        } else {
            try FileManager.default.copyItem(at: clip.url, to: dest)
        }
        reload()
    } catch {}
}
```

**Step 2: Wire cut/copy/paste into file context menus**

Pass `viewModel` (or just the clipboard methods as closures) down to `WorkspaceItemRow`. Simplest: pass the viewModel reference.

In `Sidebar`:
```swift
WorkspaceItemRow(
    item: item,
    selectedPath: viewModel.selectedFile?.filePath,
    viewModel: viewModel,
    onSelect: selectFile,
    onReload: { viewModel.reload() }
)
```

In `WorkspaceItemRow`, add `let viewModel: HubViewModel` and update `fileRow.contextMenu`:

```swift
.contextMenu {
    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.path]) }
    Divider()
    Button("Copy") { viewModel.copyFile(item.path) }
    Button("Cut") { viewModel.cutFile(item.path) }
    Divider()
    Button("Delete", role: .destructive) {
        try? FileManager.default.removeItem(at: item.path)
        onReload()
    }
}
```

And folder context menu gets Paste:
```swift
if viewModel.fileClipboard != nil {
    Button("Paste") { viewModel.pasteFile(into: item.path) }
    Divider()
}
```

**Step 3: Dim cut files in the tree**

In `fileRow`, apply opacity:
```swift
.opacity(viewModel.fileClipboard?.isCut == true && viewModel.fileClipboard?.url == item.path ? 0.4 : 1.0)
```

**Step 4: Add Rename to context menus**

In `WorkspaceItemRow`, add rename state and wire to context menu:

```swift
@State private var isRenaming = false
@State private var renameText = ""
@FocusState private var renameFocused: Bool
```

For file rows — show an inline TextField when `isRenaming`:

```swift
// In fileRow body:
if isRenaming {
    TextField("", text: $renameText)
        .textFieldStyle(.plain)
        .font(.callout)
        .focused($renameFocused)
        .onSubmit { commitRename() }
        .onExitCommand { isRenaming = false }
} else {
    // existing Label button
}
```

`commitRename()`:
```swift
private func commitRename() {
    let newName = renameText.trimmingCharacters(in: .whitespaces)
    guard !newName.isEmpty else { isRenaming = false; return }
    let dest = item.path.deletingLastPathComponent().appendingPathComponent(newName)
    try? FileManager.default.moveItem(at: item.path, to: dest)
    isRenaming = false
    onReload()
}
```

Add to context menus:
```swift
Button("Rename") {
    renameText = item.name
    isRenaming = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocused = true }
}
```

**Step 5: Build**
```
swift build
```

**Step 6: Commit**
```bash
git add WritingHub/Sources/WritingHubLib/ViewModels/HubViewModel.swift \
        WritingHub/Sources/WritingHubLib/Views/Sidebar.swift
git commit -m "feat: cut/copy/paste and rename files from sidebar context menu"
```

---

## Task 9: Duplicate file

**Files:**
- Modify: `WritingHub/Sources/WritingHubLib/Views/Sidebar.swift`

Add to file context menu (no new state needed):

```swift
Button("Duplicate") {
    let ext = item.path.pathExtension
    let base = item.path.deletingPathExtension().lastPathComponent
    let dir = item.path.deletingLastPathComponent()
    var dest = dir.appendingPathComponent("\(base)-copy.\(ext)")
    var i = 2
    while FileManager.default.fileExists(atPath: dest.path) {
        dest = dir.appendingPathComponent("\(base)-copy-\(i).\(ext)")
        i += 1
    }
    try? FileManager.default.copyItem(at: item.path, to: dest)
    onReload()
}
```

**Commit:**
```bash
git add WritingHub/Sources/WritingHubLib/Views/Sidebar.swift
git commit -m "feat: duplicate file from context menu"
```

---

## Task 10: Final build + test run

```bash
swift build && swift test
```

All tests must pass. Fix any regressions before marking complete.

```bash
git add -A
git commit -m "chore: final build verification for feature pack"
```

---

## Summary of files changed

| File | Changes |
|------|---------|
| `HubViewModel.swift` | Tab state, clipboard state, openTab/closeTab, FileClipboard |
| `ContentView.swift` | TabBar insertion, panel toggles, openFolder name+useCase fix |
| `EditorView.swift` | FindBar, Cmd+F, toolbar CSS fix, webView capture |
| `Sidebar.swift` | Drag/drop, cut/copy/paste, rename, duplicate, viewModel ref |
| `TabBar.swift` | New file — TabPill + TabBar |
| `FolderManagerTests.swift` | New test for name+useCase in CLAUDE.md |
