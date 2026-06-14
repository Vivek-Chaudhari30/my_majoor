import Foundation
import AppKit

/// Searches the local filesystem using `mdfind` (Spotlight), scoped to safe
/// user directories: Documents, Downloads, Desktop, and Desktop.
///
/// On first invocation the user is shown a clear permission alert explaining
/// what Majoor is about to access. The consent is persisted via UserDefaults
/// so the alert only fires once.
enum FileSearchClient {

    // MARK: - Safe search roots

    private static let safeRoots: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Desktop"
        ]
    }()

    // MARK: - Consent gate

    private static let consentKey = "MajoorFileSearchConsentGranted"

    /// Returns `true` if the user has already granted consent.
    private static var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    /// Shows a modal alert on the main thread asking for consent.
    /// Must be called from a background thread (will dispatch to main and block).
    /// Returns `true` if the user clicked Allow.
    private static func requestConsent() -> Bool {
        var granted = false
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Allow Majoor to search your files?"
            alert.informativeText = """
                Majoor will use Spotlight (mdfind) to search files in your \
                Documents, Downloads, and Desktop folders. \
                No file contents are read or sent to any server — only file names and paths \
                are surfaced to help you find and open files quickly.
                """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Don't Allow")
            let response = alert.runModal()
            granted = (response == .alertFirstButtonReturn)
            sema.signal()
        }
        sema.wait()
        return granted
    }

    // MARK: - Public API

    struct SearchResult {
        let paths: [String]
        /// Human-readable summary for Majoor's spoken reply (≤ 200 chars).
        let summary: String
        let ok: Bool
    }

    /// Searches for `query` using `mdfind` in safe directories.
    /// - Parameter query: The raw user query string (e.g. "resume pdf", "invoice").
    /// - Parameter openTop: If `true`, also opens the top matching file with `/usr/bin/open`.
    /// - Returns: A `SearchResult` describing what was found.
    static func search(query: String, openTop: Bool = false) -> SearchResult {
        // 1. Consent gate
        if !hasConsent {
            let granted = requestConsent()
            if granted {
                UserDefaults.standard.set(true, forKey: consentKey)
            } else {
                return SearchResult(
                    paths: [],
                    summary: "File search permission denied by user.",
                    ok: false
                )
            }
        }

        // 2. Build mdfind command scoped to safe roots.
        //    mdfind -onlyin <dir> supports one directory at a time, so we
        //    run three searches and merge results.
        var allPaths: [String] = []
        for root in safeRoots {
            let found = runMdfind(query: query, inDirectory: root)
            allPaths.append(contentsOf: found)
        }

        // Deduplicate while preserving order.
        var seen = Set<String>()
        let unique = allPaths.filter { seen.insert($0).inserted }

        if unique.isEmpty {
            return SearchResult(
                paths: [],
                summary: "No files found for \"\(query)\".",
                ok: true
            )
        }

        // 3. Optionally open the top result.
        if openTop, let top = unique.first {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [top]
            try? task.run()
            Log.info("FileSearchClient: opened top result \(top)")
        }

        // 4. Build a concise summary (≤ 5 paths spoken aloud is already a lot).
        let shown = unique.prefix(5).map { URL(fileURLWithPath: $0).lastPathComponent }
        let listText = shown.joined(separator: ", ")
        let moreText = unique.count > 5 ? " and \(unique.count - 5) more" : ""
        let summary = "Found \(unique.count) file\(unique.count == 1 ? "" : "s"): \(listText)\(moreText)."

        return SearchResult(paths: Array(unique), summary: summary, ok: true)
    }

    // MARK: - mdfind wrapper

    private static func runMdfind(query: String, inDirectory directory: String) -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        // -onlyin: restricts Spotlight to one directory tree
        // We pass the raw query; mdfind treats it as a full-text or metadata query.
        task.arguments = ["-onlyin", directory, query]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // suppress stderr

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            Log.error("mdfind failed for directory \(directory): \(error.localizedDescription)")
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return []
        }

        return output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
