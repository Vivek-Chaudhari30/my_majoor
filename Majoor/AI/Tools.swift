import Foundation

/// JSON Schemas for the tools Majoor exposes to gpt-4o-mini.
/// The actual schemas live in `Majoor/Resources/Tools.json` so both Swift and
/// the Python eval harness read from the same source of truth.
enum Tools {
    static let all: [[String: Any]] = loadFromBundle()

    private static func loadFromBundle() -> [[String: Any]] {
        guard let url = Bundle.main.url(forResource: "Tools", withExtension: "json") else {
            Log.error("Tools.json not found in bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                Log.error("Tools.json is not an array of objects.")
                return []
            }
            return arr
        } catch {
            Log.error("Failed to load Tools.json: \(error.localizedDescription)")
            return []
        }
    }
}

/// A model-chosen tool invocation, ready for ToolExecutor.
struct ToolCall {
    let id: String
    let name: String
    let arguments: [String: Any]
}

/// One previous round of conversation, used as in-memory context.
struct Turn: Sendable {
    let userTranscript: String
    let assistantReply: String
}

enum BrainError: Error, LocalizedError {
    case noToolSelected
    case malformedResponse(String)
    case iterationCapHit

    var errorDescription: String? {
        switch self {
        case .noToolSelected:        return "Model did not return a tool call."
        case .malformedResponse(let s): return "Malformed chat response: \(s)"
        case .iterationCapHit:       return "Agent loop exceeded iteration cap."
        }
    }
}

/// System prompt loader — reads from Majoor/Resources/SystemPrompt.txt.
/// Both Swift and the Python eval harness read this same file.
enum SystemPrompt {
    static let text: String = loadFromBundle()

    private static func loadFromBundle() -> String {
        guard let url = Bundle.main.url(forResource: "SystemPrompt", withExtension: "txt") else {
            Log.error("SystemPrompt.txt not found in bundle.")
            return "You are Majoor."
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            Log.error("Failed to load SystemPrompt.txt: \(error.localizedDescription)")
            return "You are Majoor."
        }
    }
}
