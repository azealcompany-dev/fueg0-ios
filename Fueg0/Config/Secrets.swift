import Foundation

enum Secrets {
    /// YouTube Data API v3 key.
    /// Resolution order: `YOUTUBE_API_KEY` environment variable, then `YouTubeAPIKey` in `Secrets.plist`.
    /// The plist is copied into the app at build time from `Fueg0/Config/Secrets.plist` and is not committed.
    static var youtubeAPIKey: String {
        if let key = normalized(ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? "") {
            return key
        }
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let raw = dict["YouTubeAPIKey"] as? String,
            let key = normalized(raw)
        else {
            return ""
        }
        return key
    }

    static func normalized(_ raw: String) -> String? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = [
            "",
            "your_api_key",
            "your-api-key",
            "changeme",
            "paste_key_here",
            "insert_key_here",
            "youtube_api_key"
        ]
        if placeholders.contains(key.lowercased()) { return nil }
        return key
    }
}
