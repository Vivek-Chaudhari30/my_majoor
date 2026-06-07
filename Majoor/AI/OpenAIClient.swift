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
    /// Default model is `gpt-4o-mini-transcribe` per MASTER_PLAN §5.
    func transcribe(fileURL: URL,
                    model: String = "gpt-4o-mini-transcribe",
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

        // Whisper-style prompt biasing — Whisper / gpt-4o-mini-transcribe both
        // accept a `prompt` field that biases decoding toward these tokens.
        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        add("Majoor, Gmail, GitHub, VS Code, Visual Studio Code, Safari, Chrome, Arc, Firefox, Brave, Cmd, Ctrl, Opt, YouTube, LinkedIn, Spotify, Notes, Calendar, Terminal, Finder, Reddit, Hacker News.\r\n")

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

    // MARK: - Agent loop (OpenAI's canonical 5-step pattern)

    /// Run the full chat-with-tools agent loop and return the final spoken text.
    ///
    /// MASTER_PLAN §1 / §10:
    /// - `tool_choice = "auto"` — model can reply with text OR call tools.
    /// - `temperature = 0` — deterministic tool routing.
    /// - Bounded at 3 iterations.
    /// - Tool execution happens inside this method; tool results are appended
    ///   back as `role: "tool"` messages, then the model is re-queried for the
    ///   final spoken reply.
    func chat(transcript: String,
              model: String = "gpt-4o-mini",
              maxIterations: Int = 3) async throws -> String {

        var messages: [[String: Any]] = [
            ["role": "system", "content": SystemPrompt.text],
            ["role": "user",   "content": transcript]
        ]

        for iteration in 0..<maxIterations {
            let body: [String: Any] = [
                "model": model,
                "messages": messages,
                "tools": Tools.all,
                "tool_choice": "auto",
                "temperature": 0
            ]
            let raw = try await postChatCompletion(body: body)

            guard let choices = raw["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any] else {
                throw BrainError.malformedResponse("no choices/message")
            }

            // 1) Append the assistant message VERBATIM so the next round preserves tool_calls.
            messages.append(reconstructAssistantMessage(message))

            // 2) Did the model call any tools?
            let toolCalls = parseToolCalls(message["tool_calls"])
            if toolCalls.isEmpty {
                // Plain text reply → that's the spoken text.
                let content = (message["content"] as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if content.isEmpty {
                    Log.warn("Model returned no text and no tools on iteration \(iteration + 1).")
                    return "Sorry, I didn't get that."
                }
                return content
            }

            // 3) Execute each tool, append a tool result message per call.
            for call in toolCalls {
                Log.info("Tool: \(call.name)  args: \(call.arguments)")
                let result = ToolExecutor.execute(call)
                Log.info("Result: \(result.summary) (ok=\(result.ok))")
                messages.append([
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": result.summary
                ])
            }
            // Loop — the model gets to see the tool results and produce a final reply.
        }

        Log.warn("Agent loop hit iteration cap (\(maxIterations)).")
        return "Sorry, I got stuck."
    }

    // MARK: - HTTP helper

    private func postChatCompletion(body: [String: Any]) async throws -> [String: Any] {
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        return json
    }

    // MARK: - Message reconstruction

    /// Build the exact message dict to append for the next round. We MUST keep
    /// `tool_calls` exactly as the model produced them — content can be omitted
    /// or null when tool_calls is present.
    private func reconstructAssistantMessage(_ message: [String: Any]) -> [String: Any] {
        var out: [String: Any] = ["role": "assistant"]
        if let toolCalls = message["tool_calls"] {
            out["tool_calls"] = toolCalls
            // When tool_calls present, content may legitimately be null.
            if let content = message["content"] as? String, !content.isEmpty {
                out["content"] = content
            }
        } else {
            out["content"] = message["content"] as? String ?? ""
        }
        return out
    }

    private func parseToolCalls(_ raw: Any?) -> [ToolCall] {
        guard let array = raw as? [[String: Any]] else { return [] }
        return array.compactMap { entry in
            guard let id = entry["id"] as? String,
                  let function = entry["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let argsString = function["arguments"] as? String else { return nil }
            let args: [String: Any]
            if let data = argsString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                args = parsed
            } else {
                args = [:]
            }
            return ToolCall(id: id, name: name, arguments: args)
        }
    }
}

enum OpenAIError: Error, LocalizedError {
    case tooShort
    case noHTTPResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .tooShort:        return "Audio too short."
        case .noHTTPResponse:  return "No HTTP response."
        case .http(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}
