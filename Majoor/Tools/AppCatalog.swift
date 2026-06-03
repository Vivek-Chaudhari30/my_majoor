import Foundation

/// Maps spoken / casual names to canonical macOS app names or web URLs.
/// The model already does most of this mapping, but this layer is a safety net
/// for cases like the user saying "gmail" and the model picking `open_app("Gmail")`.
enum AppCatalog {
    enum Resolution {
        case app(name: String)
        case url(URL)
    }

    /// Spoken names that should be opened as URLs in the default browser.
    private static let urlAliases: [String: String] = [
        "gmail": "https://mail.google.com",
        "google mail": "https://mail.google.com",
        "linkedin": "https://www.linkedin.com",
        "github": "https://github.com",
        "youtube": "https://www.youtube.com",
        "twitter": "https://x.com",
        "x": "https://x.com",
        "reddit": "https://www.reddit.com",
        "google calendar": "https://calendar.google.com",
        "google docs": "https://docs.google.com",
        "google drive": "https://drive.google.com",
        "chatgpt": "https://chatgpt.com",
        "claude": "https://claude.ai",
        "instagram": "https://www.instagram.com",
        "facebook": "https://www.facebook.com",
        "whatsapp web": "https://web.whatsapp.com"
    ]

    /// Spoken / casual app names → exact macOS app name as it appears in /Applications.
    private static let appAliases: [String: String] = [
        "vs code": "Visual Studio Code",
        "vscode": "Visual Studio Code",
        "code": "Visual Studio Code",
        "chrome": "Google Chrome",
        "brave": "Brave Browser",
        "browser": "Safari",
        "settings": "System Settings",
        "preferences": "System Settings",
        "system preferences": "System Settings",
        "calendar": "Calendar",
        "messages": "Messages",
        "imessage": "Messages",
        "notes": "Notes",
        "terminal": "Terminal",
        "iterm": "iTerm",
        "finder": "Finder",
        "music": "Music",
        "spotify": "Spotify",
        "slack": "Slack",
        "discord": "Discord",
        "zoom": "zoom.us",
        "xcode": "Xcode"
    ]

    static func resolve(spokenName raw: String) -> Resolution {
        let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let urlStr = urlAliases[key], let url = URL(string: urlStr) {
            return .url(url)
        }
        if let canonical = appAliases[key] {
            return .app(name: canonical)
        }
        return .app(name: raw)
    }
}
