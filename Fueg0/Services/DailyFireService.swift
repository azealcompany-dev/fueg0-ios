import Darwin
import Foundation

struct DailyVideo: Equatable, Codable, Sendable {
    var videoId: String
    var title: String
    var thumbnailURL: String
    var quote: String
}

/// Fetches and caches one Daily Fire video per calendar day.
enum DailyFireService {
    private static let legendaryMinSeconds = 480
    private static let relaxedMinSeconds = 360
    private static let legendaryMinViews = 100_000
    private static let relaxedMinViews = 25_000
    private static let legendaryOnlyKey = "legendary_speeches_only"
    private static let timeout: TimeInterval = 12

    private static let legendaryQueries = [
        "David Goggins stay hard full speech",
        "Jocko Willink extreme ownership speech",
        "Kobe Bryant Mamba Mentality",
        "Eric Thomas when you want to succeed",
        "Admiral McRaven make your bed speech",
        "Jordan Peterson responsibility",
        "Tony Robbins power within",
        "Denzel Washington fall forward",
        "Les Brown greatness within you",
        "Simon Sinek leaders eat last",
        "Michael Jordan hall of fame speech",
        "Steve Jobs Stanford commencement speech",
        "Arnold Schwarzenegger rules of success speech",
        "Matthew McConaughey university of houston speech"
    ]

    private static let expandedQueries = legendaryQueries + [
        "rocky balboa speech to his son",
        "300 this is sparta speech",
        "military motivation speech full",
        "no excuses motivation speech"
    ]

    private static let dateOverrides: [String: (id: String, title: String)] = [
        "2026-01-01": ("78rptzkY2jU", "David Goggins — Stay Hard (New Year Fire)"),
        "2026-07-04": ("3sK3wEAxZph", "Admiral McRaven — Make Your Bed"),
        "2026-12-31": ("wxWDt5U9Y8s", "Eric Thomas — When You Want To Succeed")
    ]

    private static let clickbait = try! NSRegularExpression(
        pattern: "(insane|shocking|you wont believe|gone wrong|destroyed|exposed|"
            + "beast mode|alpha male|sigma|gym hype|prank|reaction|tiktok|shorts|"
            + "#shorts|must watch|watch this)",
        options: [.caseInsensitive]
    )

    static func video(forToday forceRefresh: Bool = false) async -> DailyVideo {
        let today = dayStamp()
        if !forceRefresh, let cached = loadCached(day: today), !cached.videoId.isEmpty {
            return cached
        }
        let video = await fetchBest(day: today, legendaryOnly: isLegendaryOnly)
        cache(video, day: today)
        return video
    }

    static var isLegendaryOnly: Bool {
        if UserDefaults.standard.object(forKey: legendaryOnlyKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: legendaryOnlyKey)
    }

    static func cacheKey(day: String) -> String { "daily_video_\(day)" }

    private static func loadCached(day: String) -> DailyVideo? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(day: day)) else { return nil }
        return try? JSONDecoder().decode(DailyVideo.self, from: data)
    }

    private static func cache(_ video: DailyVideo, day: String) {
        if let data = try? JSONEncoder().encode(video) {
            UserDefaults.standard.set(data, forKey: cacheKey(day: day))
        }
    }

    private static func fetchBest(day: String, legendaryOnly: Bool) async -> DailyVideo {
        if let override = dateOverrides[day] {
            return DailyVideo(
                videoId: override.id,
                title: override.title,
                thumbnailURL: "https://i.ytimg.com/vi/\(override.id)/hqdefault.jpg",
                quote: quote(for: day)
            )
        }

        let key = Secrets.youtubeAPIKey
        guard !key.isEmpty else { return fallback(day: day) }

        let queries = legendaryOnly ? legendaryQueries : expandedQueries
        let query = queries.randomElement() ?? legendaryQueries[0]
        let minSeconds = legendaryOnly ? legendaryMinSeconds : relaxedMinSeconds
        let minViews = legendaryOnly ? legendaryMinViews : relaxedMinViews

        do {
            let candidates = try await searchVideos(query: query, key: key, legendaryOnly: legendaryOnly)
            guard !candidates.isEmpty else { return fallback(day: day) }

            let details = try await videoDetails(ids: candidates.map(\.id), key: key)
            var scored: [(candidate: Candidate, score: Double)] = []

            for candidate in candidates {
                guard let detail = details[candidate.id] else { continue }
                let duration = parseISODuration(detail.duration)
                let views = Int(detail.viewCount) ?? 0
                if duration < minSeconds { continue }
                if views < minViews { continue }
                if isLowQuality(candidate.title, legendaryOnly: legendaryOnly) { continue }
                let score = scoreVideo(
                    title: candidate.title,
                    views: views,
                    durationSec: duration,
                    query: query,
                    legendaryOnly: legendaryOnly
                )
                scored.append((candidate, score))
            }

            scored.sort { $0.score > $1.score }
            if let best = scored.first?.candidate {
                return DailyVideo(
                    videoId: best.id,
                    title: best.title,
                    thumbnailURL: best.thumb,
                    quote: quote(for: day)
                )
            }
        } catch {
            // Fall through to the static speech.
        }
        return fallback(day: day)
    }

    private struct Candidate {
        var id: String
        var title: String
        var thumb: String
    }

    private struct Detail {
        var duration: String
        var viewCount: String
    }

    private static func searchVideos(query: String, key: String, legendaryOnly: Bool) async throws -> [Candidate] {
        let duration = legendaryOnly ? "long" : "medium"
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        comps.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoDuration", value: duration),
            URLQueryItem(name: "order", value: "viewCount"),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = comps.url else { return [] }
        let data = try await get(url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            guard
                let idWrap = item["id"] as? [String: Any],
                let id = idWrap["videoId"] as? String,
                let snippet = item["snippet"] as? [String: Any],
                let title = snippet["title"] as? String,
                let thumbs = snippet["thumbnails"] as? [String: Any]
            else { return nil }
            let thumb = (thumbs["high"] as? [String: Any])
                ?? (thumbs["medium"] as? [String: Any])
                ?? (thumbs["default"] as? [String: Any])
            let thumbURL = thumb?["url"] as? String ?? "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"
            return Candidate(id: id, title: title, thumb: thumbURL)
        }
    }

    private static func videoDetails(ids: [String], key: String) async throws -> [String: Detail] {
        let clipped = ids.prefix(25)
        guard !clipped.isEmpty else { return [:] }
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        comps.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails,statistics"),
            URLQueryItem(name: "id", value: clipped.joined(separator: ",")),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = comps.url else { return [:] }
        let data = try await get(url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [:] }

        var map: [String: Detail] = [:]
        for item in items {
            guard
                let id = item["id"] as? String,
                let content = item["contentDetails"] as? [String: Any],
                let duration = content["duration"] as? String
            else { continue }
            let stats = item["statistics"] as? [String: Any]
            let views = stats?["viewCount"] as? String ?? "0"
            map[id] = Detail(duration: duration, viewCount: views)
        }
        return map
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private static func parseISODuration(_ iso: String) -> Int {
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: iso, range: NSRange(iso.startIndex..., in: iso))
        else { return 0 }
        func group(_ i: Int) -> Int {
            let range = match.range(at: i)
            guard range.location != NSNotFound, let swift = Range(range, in: iso) else { return 0 }
            return Int(iso[swift]) ?? 0
        }
        return group(1) * 3600 + group(2) * 60 + group(3)
    }

    private static func isLowQuality(_ title: String, legendaryOnly: Bool) -> Bool {
        let ns = title as NSString
        if clickbait.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)) != nil {
            return true
        }
        let caps = (try? NSRegularExpression(pattern: #"\b[A-Z]{2,}\b"#))
            .map { $0.numberOfMatches(in: title, range: NSRange(location: 0, length: ns.length)) } ?? 0
        if caps >= 4 { return true }
        if legendaryOnly {
            let junk = ["edit", "compilation", "mix", "remix", "lofi", "1 hour", "10 hours"]
            let lower = title.lowercased()
            if junk.contains(where: { lower.contains($0) }) { return true }
        }
        return false
    }

    private static func scoreVideo(
        title: String,
        views: Int,
        durationSec: Int,
        query: String,
        legendaryOnly: Bool
    ) -> Double {
        var score = log(Double(max(1, min(views, 100_000_000)))) * 10
        let minutes = Double(durationSec) / 60
        let durationBonus = legendaryOnly ? min(max(minutes, 8), 45) : min(max(minutes, 6), 30)
        score += durationBonus * 2

        let titleLower = title.lowercased()
        let matched = query.lowercased().split(separator: " ").filter { $0.count > 3 && titleLower.contains($0) }.count
        score += Double(matched) * 15

        let quality = ["speech", "mentality", "motivation", "commencement", "ownership", "greatness"]
        score += Double(quality.filter { titleLower.contains($0) }.count) * 8
        if titleLower.contains("full") { score += 10 }
        if titleLower.contains("official") { score += 6 }
        return score
    }

    private static func quote(for day: String) -> String {
        let quotes = SampleContent.quotes
        let index = abs(day.hashValue) % quotes.count
        return quotes[index]
    }

    private static func fallback(day: String) -> DailyVideo {
        DailyVideo(
            videoId: "78rptzkY2jU",
            title: "David Goggins — Stay Hard",
            thumbnailURL: "https://i.ytimg.com/vi/78rptzkY2jU/hqdefault.jpg",
            quote: quote(for: day)
        )
    }

    private static func dayStamp(_ date: Date = .now) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
