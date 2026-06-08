import Foundation

enum Config {
    /// OpenAI API key. Resolved on EACH access (not cached) so that the
    /// onboarding flow's API-key step takes effect without a relaunch.
    ///   1. ~/.majoor/config.json  →  { "openai_api_key": "sk-..." }
    ///   2. OPENAI_API_KEY environment variable
    static var openAIKey: String? {
        let fm = FileManager.default
        let configURL = fm.homeDirectoryForCurrentUser.appendingPathComponent(".majoor/config.json")

        if let data = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let key = json["openai_api_key"] as? String,
           !key.isEmpty {
            return key
        }
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        return nil
    }

    /// Persist the user's API key to ~/.majoor/config.json (0700 dir, 0600 file).
    /// Used by the onboarding flow.
    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".majoor", isDirectory: true)
        let file = dir.appendingPathComponent("config.json")

        do {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir,
                                       withIntermediateDirectories: true,
                                       attributes: [.posixPermissions: 0o700])
            }
            let payload: [String: Any] = ["openai_api_key": key]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: file, options: .atomic)
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            return true
        } catch {
            Log.error("Failed to save API key: \(error.localizedDescription)")
            return false
        }
    }
}
