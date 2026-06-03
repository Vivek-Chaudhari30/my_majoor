import Foundation

enum Config {
    /// OpenAI API key. Resolved at first access from:
    ///   1. ~/.majoor/config.json  →  { "openai_api_key": "sk-..." }
    ///   2. OPENAI_API_KEY environment variable
    static let openAIKey: String? = {
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
    }()
}
