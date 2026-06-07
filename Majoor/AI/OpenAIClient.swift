import Foundation

final class OpenAIClient {
    private let session: URLSession
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Transcription

    /// POST audio to /v1/audio/transcriptions and return the transcript text.
    func transcribe(fileURL: URL,
                    model: String = "whisper-1",
                    language: String? = "en") async throws -> String {
        let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audio = try Data(contentsOf: fileURL)
        guard audio.count > 256 else { throw OpenAIError.tooShort }

        var body = Data()
        func add(_ s: String) { body.append(s.data(using: .utf8)!) }

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        add("\(model)\r\n")

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        add("json\r\n")

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        add("Open Safari, go to Gmail, search for the weather in Boston, Xcode, Spotify.\r\n")

        if let language {
            add("--\(boundary)\r\n")
            add("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            add("\(language)\r\n")
        }

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        add("Content-Type: audio/m4a\r\n\r\n")
        body.append(audio)
        add("\r\n--\(boundary)--\r\n")

        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.noHTTPResponse }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            throw OpenAIError.http(http.statusCode, bodyStr)
        }
        struct Resp: Decodable { let text: String }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return resp.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Chat / tool calling

    /// Send the transcript to gpt-4o-mini with our tool schemas, return the chosen ToolCall.
    func chat(transcript: String, model: String = "gpt-4o-mini") async throws -> ToolCall {
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are Majoor, a voice-first macOS assistant.
        The user just spoke a short command, which has been transcribed for you.
        You MUST respond by calling exactly one tool — never reply with plain text.

        Tool selection rules — apply IN ORDER, pick the FIRST that matches:

        1. The user mentions a domain (e.g. "gmail.com", "youtube.com", "github.com/foo")
           → call open_url with the full https:// URL.

        2. The user mentions a known web service by name
           (Gmail, LinkedIn, GitHub, YouTube, Twitter, X, Reddit, ChatGPT, Claude,
            Google Docs, Google Drive, Google Calendar, Instagram, Facebook, WhatsApp Web)
           → call open_url with its canonical https URL.
           Examples:
             "open gmail"            → open_url https://mail.google.com
             "go to linkedin"        → open_url https://www.linkedin.com
             "open youtube"          → open_url https://www.youtube.com

        3. The user is asking a QUESTION or wants to LOOK SOMETHING UP
           (phrases like "search for...", "look up...", "find...", "what is...",
            "how is...", "where is...", "google..."), even if the word "open"
           appears in their command.
           → call search_web with a clean concise query (strip filler words like
             "open and", "can you", "please").
           Examples:
             "search the weather in Boston"          → search_web "weather in Boston"
             "open and search about how is the weather in Boston"
                                                     → search_web "weather in Boston"
             "what is the capital of France"         → search_web "capital of France"

        4. The user explicitly wants to launch a MAC APPLICATION by name
           (Safari, Notes, Calendar, Visual Studio Code, Spotify, Terminal, Finder, etc.)
           → call open_app with the canonical app name as it appears in /Applications.
           Map casual names: "vs code" → "Visual Studio Code", "chrome" → "Google Chrome".

        5. Anything ambiguous or unrecognized
           → call search_web with the user's utterance as the query.

        For every tool call, include a short conversational `reply` (under 10 words)
        in the arguments — this is spoken aloud as confirmation.
        Examples of good replies: "Opening Gmail.", "Searching for that.", "Got it."
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            "tools": Tools.all,
            "tool_choice": "required",
            "temperature": 0.2
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.noHTTPResponse }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            throw OpenAIError.http(http.statusCode, bodyStr)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrainError.malformedResponse("not a JSON object")
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw BrainError.malformedResponse("no choices/message")
        }
        guard let toolCalls = message["tool_calls"] as? [[String: Any]],
              let toolCall = toolCalls.first,
              let function = toolCall["function"] as? [String: Any],
              let name = function["name"] as? String,
              let argsString = function["arguments"] as? String,
              let argsData = argsString.data(using: .utf8),
              let args = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw BrainError.noToolSelected
        }
        return ToolCall(name: name, arguments: args)
    }
}

enum OpenAIError: Error, LocalizedError {
    case tooShort
    case noHTTPResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .tooShort: return "Audio too short."
        case .noHTTPResponse: return "No HTTP response."
        case .http(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}
