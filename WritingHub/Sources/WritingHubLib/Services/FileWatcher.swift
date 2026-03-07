import Foundation
import CoreServices

/// FSEvents-based file watcher with debouncing and self-write tracking.
/// All operations are dispatched to the main queue.
public final class FileWatcher: @unchecked Sendable {
    private let path: String
    private var stream: FSEventStreamRef?
    private var debounceTimer: Timer?
    private var pendingSelfWrites: Set<String> = []

    public var onChange: (@Sendable () -> Void)?

    public init(path: String) {
        self.path = path
    }

    // MARK: - Self-write tracking

    /// Mark a file path as a self-write so the watcher ignores it.
    /// The path is automatically removed after 500ms.
    public func markSelfWrite(_ filePath: String) {
        pendingSelfWrites.insert(filePath)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pendingSelfWrites.remove(filePath)
        }
    }

    // MARK: - Start / Stop

    public func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let pathsToWatch = [path] as CFArray

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagUseCFTypes)

        stream = FSEventStreamCreate(
            nil,
            FileWatcher.eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,  // 200ms latency
            flags
        )

        guard let stream = stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    public func stop() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        debounceTimer?.invalidate()
        debounceTimer = nil
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    // MARK: - FSEvents Callback

    private static let eventCallback: FSEventStreamCallback = {
        (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in

        guard let info = clientCallBackInfo else { return }
        let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

        // Check if any event path is NOT a self-write and not noise (.git, .DS_Store)
        var hasExternalChange = false

        if let cfArray = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] {
            for path in cfArray {
                // Skip .git directory changes and .DS_Store files
                if path.contains("/.git/") || path.hasSuffix(".DS_Store") {
                    continue
                }
                if !watcher.pendingSelfWrites.contains(path) {
                    hasExternalChange = true
                    break
                }
            }
        } else {
            hasExternalChange = true
        }

        if hasExternalChange {
            watcher.scheduleDebounce()
        }
    }

    // MARK: - Debounce

    private func scheduleDebounce() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.onChange?()
        }
    }
}
