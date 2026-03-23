import Foundation
import AppKit

public struct AppReleaseAsset: Decodable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let browserDownloadURL: URL
    public let size: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

public struct AppReleaseInfo: Decodable, Equatable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String
    public let htmlURL: URL
    public let publishedAt: Date?
    public let assets: [AppReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    public var displayVersion: String {
        AppVersion.normalized(tagName)
    }
}

public struct AppVersion: Comparable, Equatable, Sendable {
    let components: [Int]

    public init(_ raw: String) {
        let normalized = Self.normalized(raw)
        self.components = normalized
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    public static func normalized(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let allowed = withoutPrefix.prefix { $0.isNumber || $0 == "." }
        return allowed.isEmpty ? "0" : String(allowed)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return false }
        }
        return true
    }
}

public enum AppUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(message: String)
    case updateAvailable(AppReleaseInfo)
    case downloading(AppReleaseInfo, progress: Double?)
    case readyToInstall(AppReleaseInfo)
    case failure(message: String)
}

public enum AppUpdateError: LocalizedError {
    case invalidResponse
    case missingReleaseAsset
    case missingAppBundleInArchive
    case currentAppNotReplaceable
    case installLaunchFailed

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid update response."
        case .missingReleaseAsset:
            return "No macOS app archive was found in the latest GitHub release."
        case .missingAppBundleInArchive:
            return "The downloaded release did not contain an app bundle."
        case .currentAppNotReplaceable:
            return "Automatic update requires running Amplify from a writable .app bundle."
        case .installLaunchFailed:
            return "The downloaded update could not be installed automatically."
        }
    }
}

@MainActor
public final class AppUpdateService: NSObject, ObservableObject {
    public static let shared = AppUpdateService()

    @Published public private(set) var state: AppUpdateState = .idle
    @Published public var isPresentingSheet = false

    public let currentVersion: String

    private let owner = "jihjihk"
    private let repo = "amplify"
    private lazy var latestReleaseURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    private var downloadedRelease: AppReleaseInfo?
    private var downloadedArchiveURL: URL?
    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?

    override init() {
        self.currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        super.init()
    }

    public func checkForUpdates(manual: Bool = true) {
        state = .checking
        isPresentingSheet = true

        Task {
            do {
                let release = try await fetchLatestRelease()
                if AppVersion(currentVersion) < AppVersion(release.displayVersion) {
                    state = .updateAvailable(release)
                } else {
                    state = .upToDate(message: "Amplify \(currentVersion) is current.")
                    if !manual {
                        isPresentingSheet = false
                    }
                }
            } catch {
                state = .failure(message: error.localizedDescription)
            }
        }
    }

    public func dismissSheet() {
        if case .checking = state { return }
        isPresentingSheet = false
    }

    public func openReleasePage() {
        guard case .updateAvailable(let release) = state else {
            if let url = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        NSWorkspace.shared.open(release.htmlURL)
    }

    public func downloadAndInstall() {
        let release: AppReleaseInfo
        switch state {
        case .updateAvailable(let foundRelease), .downloading(let foundRelease, _), .readyToInstall(let foundRelease):
            release = foundRelease
        default:
            return
        }

        guard let asset = preferredAsset(in: release.assets) else {
            state = .failure(message: AppUpdateError.missingReleaseAsset.localizedDescription)
            return
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session?.downloadTask(with: asset.browserDownloadURL)
        downloadTask = task
        downloadedRelease = release
        state = .downloading(release, progress: nil)
        task?.resume()
    }

    private func fetchLatestRelease() async throws -> AppReleaseInfo {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Amplify-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppReleaseInfo.self, from: data)
    }

    private func preferredAsset(in assets: [AppReleaseAsset]) -> AppReleaseAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }

    private func handleDownloadedArchive(at location: URL) {
        guard let release = downloadedRelease else {
            state = .failure(message: AppUpdateError.invalidResponse.localizedDescription)
            return
        }

        do {
            let fm = FileManager.default
            let tempRoot = fm.temporaryDirectory.appendingPathComponent("AmplifyUpdate-\(UUID().uuidString)")
            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

            let archiveURL = tempRoot.appendingPathComponent(location.lastPathComponent.isEmpty ? "Amplify.zip" : location.lastPathComponent)
            try? fm.removeItem(at: archiveURL)
            try fm.moveItem(at: location, to: archiveURL)

            let extractURL = tempRoot.appendingPathComponent("Extracted")
            try fm.createDirectory(at: extractURL, withIntermediateDirectories: true)

            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", archiveURL.path, extractURL.path]
            try unzip.run()
            unzip.waitUntilExit()
            guard unzip.terminationStatus == 0 else {
                throw AppUpdateError.installLaunchFailed
            }

            guard let newAppURL = findAppBundle(in: extractURL) else {
                throw AppUpdateError.missingAppBundleInArchive
            }

            downloadedArchiveURL = archiveURL
            state = .readyToInstall(release)
            try installDownloadedApp(newAppURL: newAppURL)
        } catch {
            state = .failure(message: error.localizedDescription)
        }
    }

    private func installDownloadedApp(newAppURL: URL) throws {
        let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentAppURL.pathExtension == "app" else {
            throw AppUpdateError.currentAppNotReplaceable
        }

        let parentURL = currentAppURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parentURL.path) else {
            throw AppUpdateError.currentAppNotReplaceable
        }

        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("amplify-install-update-\(UUID().uuidString).sh")
        let escapedCurrent = shellEscaped(currentAppURL.path)
        let escapedNew = shellEscaped(newAppURL.path)
        let script = """
        #!/bin/zsh
        set -euo pipefail
        APP_PATH=\(escapedCurrent)
        NEW_APP=\(escapedNew)
        PARENT_DIR=$(dirname "$APP_PATH")
        TMP_TARGET="$PARENT_DIR/.Amplify-updating.app"
        for _ in {1..60}; do
          if [ ! -d "$APP_PATH" ]; then
            break
          fi
          sleep 1
        done
        rm -rf "$TMP_TARGET"
        /usr/bin/ditto "$NEW_APP" "$TMP_TARGET"
        rm -rf "$APP_PATH"
        mv "$TMP_TARGET" "$APP_PATH"
        open "$APP_PATH"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/zsh")
        launcher.arguments = ["-lc", "nohup \(shellEscaped(scriptURL.path)) >/tmp/amplify-updater.log 2>&1 &"]
        try launcher.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func findAppBundle(in root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return nil
        }

        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                return url
            }
        }
        return nil
    }

    private func shellEscaped(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

extension AppUpdateService: URLSessionDownloadDelegate {
    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor [weak self] in
            self?.handleDownloadedArchive(at: location)
        }
    }

    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            self?.state = .failure(message: error.localizedDescription)
        }
    }

    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor [weak self] in
            guard let self, let release = self.downloadedRelease else { return }
            self.state = .downloading(release, progress: progress)
        }
    }
}
