@preconcurrency import Combine
import Foundation

@MainActor
public final class MarkdownDocumentSession: ObservableObject {
    @Published public var html: String = ""
    @Published public private(set) var renderRevision: Int = 0
    @Published public private(set) var title: String = ""
    @Published public private(set) var version: Int?
    @Published public private(set) var editedDate: String?
    @Published public private(set) var notice: String?
    @Published public private(set) var isDirty = false

    public let fileURL: URL

    public var onDirtyStateChanged: ((Bool) -> Void)?
    public var onWillSave: ((String) -> Void)?
    public var onDidSave: (() -> Void)?
    public var onNotice: ((String?) -> Void)?

    private let folderManager: FolderManager
    private let gitService: GitService?
    private let fileWatcher: FileWatcher
    private var envelope = MarkdownDocumentEnvelope(frontMatterBlock: nil, bodyMarkdown: "", protectedSuffix: nil)
    private var lastLoadedDiskText: String = ""
    private var lastLoadedHTML: String = ""
    private var saveSubject = PassthroughSubject<String, Never>()
    private var saveCancellable: AnyCancellable?
    private var didStart = false
    private var isApplyingProgrammaticChange = false

    public init(fileURL: URL, workspaceRoot: URL?) {
        self.fileURL = fileURL.standardizedFileURL
        let rootURL = workspaceRoot ?? fileURL.deletingLastPathComponent()
        self.folderManager = FolderManager(root: rootURL)

        if workspaceRoot != nil {
            let gitService = GitService(repoPath: rootURL)
            try? gitService.initRepo()
            self.gitService = gitService
        } else {
            self.gitService = nil
        }

        self.fileWatcher = FileWatcher(path: self.fileURL.deletingLastPathComponent().path)
        self.fileWatcher.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleExternalChange()
            }
        }

        self.saveCancellable = saveSubject
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.autosaveIfNeeded(text)
            }

        startIfNeeded()
    }

    public func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        fileWatcher.start()
        loadFromDisk(force: true)
    }

    public func updateText(_ newText: String) {
        let newHTML = MarkdownRichTextCodec.html(fromMarkdown: newText)
        updateHTML(newHTML)
    }

    public func updateHTML(_ newHTML: String) {
        guard !isApplyingProgrammaticChange else { return }
        guard newHTML != html else { return }
        html = newHTML
        setDirty(newHTML != lastLoadedHTML)
        clearNotice()
        saveSubject.send(newHTML)
    }

    public func synchronizeLoadedHTML(_ normalizedHTML: String) {
        guard !isDirty else { return }
        isApplyingProgrammaticChange = true
        html = normalizedHTML
        lastLoadedHTML = normalizedHTML
        isApplyingProgrammaticChange = false
        setDirty(false)
        clearNotice()
    }

    public func reloadFromDisk() {
        loadFromDisk(force: true)
    }

    private func handleExternalChange() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            setNotice("\(fileURL.lastPathComponent) was removed from disk.")
            return
        }

        guard let diskText = try? String(contentsOf: fileURL, encoding: .utf8) else {
            setNotice("Couldn't read \(fileURL.lastPathComponent).")
            return
        }

        guard diskText != lastLoadedDiskText else { return }

        if isDirty {
            setNotice("\(fileURL.lastPathComponent) changed on disk while you had local edits.")
        } else {
            applyDiskText(diskText)
        }
    }

    private func loadFromDisk(force: Bool) {
        guard let diskText = try? String(contentsOf: fileURL, encoding: .utf8) else {
            setNotice("Couldn't read \(fileURL.lastPathComponent).")
            return
        }

        if force || !isDirty || html == lastLoadedHTML {
            applyDiskText(diskText)
        } else if diskText != lastLoadedDiskText {
            setNotice("\(fileURL.lastPathComponent) changed on disk while you had local edits.")
        }
    }

    private func applyDiskText(_ diskText: String) {
        lastLoadedDiskText = diskText
        envelope = MarkdownDocumentEnvelope.parse(from: diskText)
        updateMetadata(from: diskText)
        let renderedHTML = MarkdownRichTextCodec.html(fromMarkdown: envelope.bodyMarkdown)
        isApplyingProgrammaticChange = true
        html = renderedHTML
        lastLoadedHTML = renderedHTML
        isApplyingProgrammaticChange = false
        renderRevision += 1
        setDirty(false)
        clearNotice()
    }

    private func autosaveIfNeeded(_ candidateText: String) {
        guard candidateText == html, candidateText != lastLoadedHTML else {
            if candidateText == lastLoadedHTML {
                setDirty(false)
            }
            return
        }

        do {
            let currentDiskText = try String(contentsOf: fileURL, encoding: .utf8)
            guard currentDiskText == lastLoadedDiskText else {
                setNotice("\(fileURL.lastPathComponent) changed on disk before autosave completed.")
                return
            }

            onWillSave?(fileURL.path)
            fileWatcher.markSelfWrite(fileURL.path)

            let bodyMarkdown = MarkdownRichTextCodec.markdown(fromHTML: candidateText)
            let rebuiltDocument = envelope.rebuild(withBodyMarkdown: bodyMarkdown)
            let savedText = try folderManager.saveMarkdownDocument(rebuiltDocument, to: fileURL)
            lastLoadedDiskText = savedText
            envelope = MarkdownDocumentEnvelope.parse(from: savedText)
            updateMetadata(from: savedText)
            // Keep the live editor HTML as-is after autosave. Replacing it with a
            // normalized round-trip version resets the browser selection/caret.
            lastLoadedHTML = candidateText

            setDirty(false)
            clearNotice()

            do {
                try gitService?.autoCommit(message: "Update \(fileURL.lastPathComponent)", paths: [fileURL])
            } catch GitError.missingAuthorIdentity {
                // Disk autosave still succeeded; missing git identity should not read as a save failure.
            } catch {
                setNotice(error.localizedDescription)
            }

            onDidSave?()
        } catch {
            setNotice("Couldn't save \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func updateMetadata(from content: String) {
        let parsedPiece = try? WritingPiece.parse(from: content)
        title = parsedPiece?.frontMatter.title ?? fileURL.deletingPathExtension().lastPathComponent
        version = parsedPiece?.frontMatter.version
        editedDate = parsedPiece?.frontMatter.edited
    }

    private func setDirty(_ value: Bool) {
        guard isDirty != value else { return }
        isDirty = value
        onDirtyStateChanged?(value)
    }

    private func setNotice(_ message: String?) {
        notice = message
        onNotice?(message)
    }

    private func clearNotice() {
        if notice != nil {
            notice = nil
            onNotice?(nil)
        }
    }
}
