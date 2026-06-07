import Foundation

enum ToolExecutor {
    /// Run the tool the model picked. Returns true on success.
    @discardableResult
    static func execute(_ call: ToolCall) -> Bool {
        switch call.name {
        case "open_app":
            guard let raw = call.arguments["app_name"] as? String, !raw.isEmpty else {
                Log.error("open_app missing app_name")
                return false
            }
            switch AppCatalog.resolve(spokenName: raw) {
            case .app(let name):
                return runOpen(["-a", name])
            case .url(let url):
                return runOpen([url.absoluteString])
            }

        case "open_url":
            guard let urlString = call.arguments["url"] as? String,
                  let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                Log.error("open_url got an invalid or non-http(s) URL")
                return false
            }
            return runOpen([url.absoluteString])

        case "search_web":
            guard let query = call.arguments["query"] as? String, !query.isEmpty else {
                Log.error("search_web missing query")
                return false
            }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return runOpen(["https://www.google.com/search?q=\(encoded)"])

        case "system_command":
            guard let action = call.arguments["action"] as? String else { return false }
            return runSystemCommand(action)

        default:
            Log.error("Unknown tool: \(call.name)")
            return false
        }
    }

    @discardableResult
    private static func runSystemCommand(_ action: String) -> Bool {
        let script: String
        switch action {
        case "toggle_dark_mode":
            script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        case "mute":
            script = "set volume with output muted"
        case "unmute":
            script = "set volume without output muted"
        case "empty_trash":
            script = "tell application \"Finder\" to empty trash"
        case "sleep":
            script = "tell application \"System Events\" to sleep"
        default:
            return false
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            Log.info("Ran system command: \(action)")
            return true
        } catch {
            Log.error("osascript failed: \(error.localizedDescription)")
            return false
        }
    }

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
}
