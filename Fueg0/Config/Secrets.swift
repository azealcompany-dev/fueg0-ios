import Foundation

enum Secrets {
    static var youtubeAPIKey: String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let key = dict["YouTubeAPIKey"] as? String
        else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
