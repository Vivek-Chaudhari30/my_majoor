import Foundation

/// Persistent memory in ~/.majoor/memory.json.
/// Schema:
///   {
///     "facts": [ "my name is Vivek", "I prefer Safari", ... ]
///   }
/// The list of facts is injected into the system prompt at chat time as
/// a `[USER FACTS]` block so the model can recall them across sessions.
/// Append-only for v1 — no removal API yet (model can re-state preferred fact).
@MainActor
final class MemoryStore {
    static let shared = MemoryStore()

    private(set) var facts: [String]

    private let fileURL: URL
    private let dirURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.dirURL = home.appendingPathComponent(".majoor", isDirectory: true)
        self.fileURL = dirURL.appendingPathComponent("memory.json")
        self.facts = []
        load()
    }

    // MARK: - Disk

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = dict["facts"] as? [String] {
                self.facts = list
                Log.info("Loaded \(list.count) memory fact(s).")
            }
        } catch {
            Log.error("Failed to load memory.json: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            if !FileManager.default.fileExists(atPath: dirURL.path) {
                try FileManager.default.createDirectory(at: dirURL,
                                                        withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
            }
            let payload: [String: Any] = ["facts": facts]
            let data = try JSONSerialization.data(withJSONObject: payload,
                                                  options: [.prettyPrinted, .sortedKeys])
            try data.write(to: fileURL, options: .atomic)
            // Best-effort tightened perms; ignore failure.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            Log.error("Failed to write memory.json: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Append a new fact and persist.
    func append(_ fact: String) {
        let trimmed = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Best-effort dedupe (case-insensitive exact match).
        if facts.contains(where: { $0.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
            Log.info("Memory dedupe: \"\(trimmed)\" already known.")
            return
        }
        facts.append(trimmed)
        save()
        Log.info("Memory: stored \"\(trimmed)\" (total \(facts.count)).")
    }

    /// Formatted block for injection as a system message. Empty string if no facts.
    func systemPromptInjection() -> String {
        guard !facts.isEmpty else { return "" }
        let lines = facts.map { "- \($0)" }.joined(separator: "\n")
        return "[USER FACTS — what you know about the user]\n\(lines)"
    }
}
