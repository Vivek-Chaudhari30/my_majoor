import Foundation

/// Result of executing a tool. `summary` is the natural-language phrase fed
/// back to the model as the tool's `content`, e.g. "Opened Gmail in Safari".
/// The model uses it to produce its final spoken reply.
struct ToolResult {
    let ok: Bool
    let summary: String
}

enum ToolExecutor {
    @discardableResult
    static func execute(_ call: ToolCall) -> ToolResult {
        switch call.name {
        case "open_app":
            guard let raw = call.arguments["name"] as? String, !raw.isEmpty else {
                return ToolResult(ok: false, summary: "open_app missing name")
            }
            switch AppCatalog.resolve(spokenName: raw) {
            case .app(let canonical):
                let ok = runOpen(["-a", canonical])
                return ToolResult(ok: ok, summary: ok ? "Opened \(canonical)" : "Could not open \(canonical)")
            case .url(let url):
                let ok = runOpen([url.absoluteString])
                return ToolResult(ok: ok, summary: ok ? "Opened \(url.absoluteString)" : "Could not open \(url.absoluteString)")
            }

        case "open_url":
            guard let urlString = call.arguments["url"] as? String,
                  let url = normalizedURL(urlString) else {
                return ToolResult(ok: false, summary: "open_url got an invalid URL")
            }
            let ok = runOpen([url.absoluteString])
            return ToolResult(ok: ok, summary: ok ? "Opened \(url.absoluteString)" : "Could not open \(url.absoluteString)")

        case "open_url_in_app":
            guard let urlString = call.arguments["url"] as? String,
                  let url = normalizedURL(urlString) else {
                return ToolResult(ok: false, summary: "open_url_in_app got an invalid URL")
            }
            guard let appRaw = call.arguments["app"] as? String, !appRaw.isEmpty else {
                return ToolResult(ok: false, summary: "open_url_in_app missing app")
            }
            let appName: String = {
                if case .app(let canonical) = AppCatalog.resolve(spokenName: appRaw) { return canonical }
                return appRaw
            }()
            let ok = runOpen(["-a", appName, url.absoluteString])
            return ToolResult(
                ok: ok,
                summary: ok ? "Opened \(url.absoluteString) in \(appName)"
                            : "Could not open \(url.absoluteString) in \(appName)"
            )

        case "search_web":
            guard let query = call.arguments["query"] as? String, !query.isEmpty else {
                return ToolResult(ok: false, summary: "search_web missing query")
            }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let ok = runOpen(["https://www.google.com/search?q=\(encoded)"])
            return ToolResult(ok: ok, summary: ok ? "Searched the web for \"\(query)\"" : "Search failed")

        case "search_files":
            guard let query = call.arguments["query"] as? String, !query.isEmpty else {
                return ToolResult(ok: false, summary: "search_files missing query")
            }
            let openTop = (call.arguments["open_top"] as? Bool) ?? false
            let result = FileSearchClient.search(query: query, openTop: openTop)
            return ToolResult(ok: result.ok, summary: result.summary)

        case "remember":
            guard let fact = call.arguments["fact"] as? String, !fact.isEmpty else {
                return ToolResult(ok: false, summary: "remember missing fact")
            }
            Task { @MainActor in MemoryStore.shared.append(fact) }
            return ToolResult(ok: true, summary: "Saved: \(fact)")

        case "system_command":
            guard let command = call.arguments["command"] as? String else {
                return ToolResult(ok: false, summary: "system_command missing command")
            }
            return runSystemCommand(command)

        default:
            Log.error("Unknown tool: \(call.name)")
            return ToolResult(ok: false, summary: "Unknown tool: \(call.name)")
        }
    }

    // MARK: - System commands

    private static func runSystemCommand(_ command: String) -> ToolResult {
        let script: String
        let summary: String
        switch command {
        case "toggle_dark_mode":
            script  = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
            summary = "Toggled dark mode"
        case "mute":
            script  = "set volume with output muted"
            summary = "Muted volume"
        case "unmute":
            script  = "set volume without output muted"
            summary = "Unmuted volume"
        case "empty_trash":
            script  = "tell application \"Finder\" to empty trash"
            summary = "Emptied the trash"
        case "sleep":
            script  = "tell application \"System Events\" to sleep"
            summary = "Putting Mac to sleep"
        case "lock":
            // Ctrl+Cmd+Q is the lock shortcut on modern macOS.
            script  = "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
            summary = "Locked the screen"
        default:
            return ToolResult(ok: false, summary: "Unknown system command: \(command)")
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            Log.info("Ran system command: \(command)")
            return ToolResult(ok: true, summary: summary)
        } catch {
            Log.error("osascript failed: \(error.localizedDescription)")
            return ToolResult(ok: false, summary: "System command failed")
        }
    }

    // MARK: - /usr/bin/open helpers

    @discardableResult
    private static func runOpen(_ args: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = args
        do {
            try task.run()
            Log.info("Ran: /usr/bin/open \(args.joined(separator: " "))")
            return true
        } catch {
            Log.error("/usr/bin/open failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Accept bare domains like "gmail.com" and prepend https:// if missing.
    private static func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}
