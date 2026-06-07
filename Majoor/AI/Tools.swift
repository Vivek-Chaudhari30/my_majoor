import Foundation

/// JSON Schemas for the tools Majoor exposes to gpt-4o-mini.
/// Format follows OpenAI's "tools" parameter for chat.completions.
enum Tools {
    static let all: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "open_app",
                "description": "Open a macOS application by name. Use this when the user asks to open or launch an app installed on their Mac (e.g. Safari, Notes, Visual Studio Code, Spotify).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "app_name": [
                            "type": "string",
                            "description": "The canonical name of the macOS application as it appears in /Applications. Examples: 'Safari', 'Notes', 'Visual Studio Code', 'Spotify'."
                        ],
                        "reply": [
                            "type": "string",
                            "description": "A short conversational confirmation to speak back to the user, under 10 words. e.g. 'Opening Safari.'"
                        ]
                    ],
                    "required": ["app_name", "reply"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "open_url",
                "description": "Open a specific web URL in the user's default browser. Use when the user asks to go to a specific website (e.g. gmail, linkedin, github, youtube). Pass the full URL.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "url": [
                            "type": "string",
                            "description": "The full URL to open, including https://. Examples: 'https://mail.google.com', 'https://www.linkedin.com'."
                        ],
                        "reply": [
                            "type": "string",
                            "description": "A short conversational confirmation, under 10 words."
                        ]
                    ],
                    "required": ["url", "reply"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "search_web",
                "description": "Run a Google search and open the results page in the default browser. Use when the user asks a general question or wants to search for something, rather than open a specific app or URL.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The search query as a natural English string."
                        ],
                        "reply": [
                            "type": "string",
                            "description": "A short conversational confirmation, under 10 words."
                        ]
                    ],
                    "required": ["query", "reply"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "system_command",
                "description": "Perform a local macOS system action.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["toggle_dark_mode", "mute", "unmute", "empty_trash", "sleep"],
                            "description": "The system action to perform."
                        ],
                        "reply": [
                            "type": "string",
                            "description": "A short conversational confirmation, under 10 words."
                        ]
                    ],
                    "required": ["action", "reply"]
                ]
            ]
        ]
    ]
}

/// A model-chosen tool invocation, ready for ToolExecutor (step 6).
struct ToolCall {
    let name: String
    let arguments: [String: Any]

    var reply: String? { arguments["reply"] as? String }
}

enum BrainError: Error, LocalizedError {
    case noToolSelected
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .noToolSelected: return "Model did not return a tool call."
        case .malformedResponse(let s): return "Malformed chat response: \(s)"
        }
    }
}
