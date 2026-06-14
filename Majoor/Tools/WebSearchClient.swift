import Foundation

/// Lightweight web-search client that returns plain-text result snippets
/// the model can synthesise into a spoken answer.
///
/// Strategy (no API key required for any tier):
///   1. DuckDuckGo Instant Answer API  — zero-click JSON, free, no key.
///      Returns a short AbstractText / Answer for well-known queries.
///   2. If the instant answer is empty, fall back to scraping the first 3
///      DuckDuckGo HTML result snippets (no API key, public HTML endpoint).
///
/// The combined result is returned as a single plain-text string, capped at
/// ~800 characters so it fits comfortably inside the model's context.

enum WebSearchClient {

    // MARK: - Public

    /// Fetch search results for `query` and return a short plain-text summary.
    /// Throws on network failure; returns a descriptive string if no content
    /// is found so the model can still respond gracefully.
    static func search(query: String) async throws -> String {
        // 1. Try DuckDuckGo Instant Answer
        if let instant = try? await duckDuckGoInstant(query: query), !instant.isEmpty {
            return truncated(instant)
        }

        // 2. Fall back to HTML snippet scrape
        let snippets = try await duckDuckGoSnippets(query: query)
        if !snippets.isEmpty {
            return truncated(snippets.joined(separator: " | "))
        }

        return "No results found for: \(query)"
    }

    // MARK: - DuckDuckGo Instant Answer API

    /// Returns the AbstractText or Answer field from the DDG zero-click JSON.
    private static func duckDuckGoInstant(query: String) async throws -> String? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1"
        guard let url = URL(string: urlString) else { return nil }

        var req = URLRequest(url: url)
        req.setValue("Majoor/1.0 macOS voice assistant", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Try: AbstractText, Answer, or Definition
        for key in ["AbstractText", "Answer", "Definition"] {
            if let text = json[key] as? String, !text.isEmpty {
                let source = json["AbstractSource"] as? String ?? ""
                return source.isEmpty ? text : "\(text) (Source: \(source))"
            }
        }

        // Try RelatedTopics[0].Text as a last resort
        if let topics = json["RelatedTopics"] as? [[String: Any]],
           let first = topics.first,
           let text = first["Text"] as? String,
           !text.isEmpty {
            return text
        }

        return nil
    }

    // MARK: - DuckDuckGo HTML scrape (fallback)

    /// Scrapes up to 3 result snippets from DuckDuckGo HTML search.
    private static func duckDuckGoSnippets(query: String) async throws -> [String] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        // DuckDuckGo lite HTML — lightweight, no JS needed
        let urlString = "https://html.duckduckgo.com/html/?q=\(encoded)"
        guard let url = URL(string: urlString) else { return [] }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        return extractSnippets(from: html, limit: 3)
    }

    // MARK: - HTML snippet extraction (no dependencies)

    /// Very small HTML parser: pulls text from <a class="result__snippet"> tags.
    /// Falls back to stripping all tags if no snippets found.
    private static func extractSnippets(from html: String, limit: Int) -> [String] {
        var results: [String] = []

        // Look for result__snippet spans
        let pattern = #"class="result__snippet"[^>]*>(.*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: pattern,
                                                 options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let nsHtml = html as NSString
            let matches = regex.matches(in: html,
                                        range: NSRange(location: 0, length: nsHtml.length))
            for match in matches.prefix(limit) {
                let raw = nsHtml.substring(with: match.range(at: 1))
                let clean = stripHTML(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { results.append(clean) }
            }
        }

        // Fallback: pull any <a class="result__a"> link titles
        if results.isEmpty {
            let titlePattern = #"class="result__a"[^>]*>(.*?)</a>"#
            if let regex = try? NSRegularExpression(pattern: titlePattern,
                                                     options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let nsHtml = html as NSString
                let matches = regex.matches(in: html,
                                            range: NSRange(location: 0, length: nsHtml.length))
                for match in matches.prefix(limit) {
                    let raw = nsHtml.substring(with: match.range(at: 1))
                    let clean = stripHTML(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty { results.append(clean) }
                }
            }
        }

        return results
    }

    /// Strip HTML tags from a string.
    private static func stripHTML(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else { return s }
        let ns = s as NSString
        return regex.stringByReplacingMatches(in: s,
                                              range: NSRange(location: 0, length: ns.length),
                                              withTemplate: "")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;",  with: "<")
            .replacingOccurrences(of: "&gt;",  with: ">")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    // MARK: - Helpers

    private static func truncated(_ s: String, maxChars: Int = 800) -> String {
        guard s.count > maxChars else { return s }
        return String(s.prefix(maxChars)) + "…"
    }
}
