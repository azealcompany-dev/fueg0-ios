import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct DailyVideo: Equatable, Codable, Sendable {
    var videoId: String
    var title: String
    var thumbnailURL: String
    var quote: String
}

enum DailyFireSource: String, Codable, Equatable, Sendable {
    case youtube
    case curated
}

struct DailyFireFeed: Equatable, Sendable {
    var videos: [DailyVideo]
    var notice: String?
    var source: DailyFireSource
}

struct DailyFireCatalogCache: Codable, Equatable, Sendable {
    var day: String
    var videos: [DailyVideo]
    var notice: String?
    var source: DailyFireSource
}

struct DailyFireLoad: Equatable, Sendable {
    var feed: DailyFireFeed
    var cacheToWrite: DailyFireCatalogCache?
}

enum DailyFireNotice {
    static let missingKey = "Playing saved fires. Add a YouTube API key to search live."
    static let offline = "No connection. Playing saved fires."
    static let unavailable = "YouTube search is unavailable. Playing saved fires."
    static let empty = "YouTube had no playable videos. Playing saved fires."
}

enum DailyFireID {
    static func isPlayable(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

enum YouTubePlaybackFailure {
    /// Removed, private, or embed-restricted. Safe to skip permanently.
    static let videoFaultCodes: Set<String> = ["100", "101", "150"]
}

enum MotivationalCatalog {
    /// Official uploads checked with YouTube oEmbed (HTTP 200 means the video exists and can be embedded).
    /// Used when the Data API key is missing or YouTube search fails.
    static let videos: [DailyVideo] = [
        video("pxBQLFLei70", "Admiral William H. McRaven — Make Your Bed"),
        video("5tSTk1083VY", "David Goggins — Joe Rogan Experience #1080"),
        video("78I9dTB9vqM", "David Goggins — If You're Ambitious, Watch This"),
        video("IdTMDpizis8", "Jocko Willink — GOOD"),
        video("UF8uR6Z6KLc", "Steve Jobs — Stanford Commencement Address"),
        video("i5ZeIVPe5dg", "Arnold Schwarzenegger — USC Commencement Address"),
        video("qp0HIF3SfI4", "Simon Sinek — How Great Leaders Inspire Action"),
        video("kYfNvmF0Bqw", "Steve Jobs — Secrets of Life"),
        video("oTugjssqOT0", "Randy Pausch — Time Management"),
        video("H14bBuluwB8", "Angela Duckworth — Grit"),
        video("7sxpKhIbr0E", "Scott Geller — The Psychology of Self-Motivation"),
        video("wD2cVhC-63I", "Matthew McConaughey — Oscar Acceptance"),
        video("8jPQjjsBbIc", "Daniel Levitin — How to Stay Calm Under Stress"),
        video("arj7oStGLkU", "Tim Urban — Inside the Mind of a Master Procrastinator"),
        video("RcGyVTAoXEU", "Kelly McGonigal — How to Make Stress Your Friend"),
        video("eIho2S0ZahI", "Julian Treasure — How to Speak So That People Want to Listen")
    ]

    private static func video(_ id: String, _ title: String) -> DailyVideo {
        DailyVideo(
            videoId: id,
            title: title,
            thumbnailURL: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
            quote: ""
        )
    }
}

enum DailyFireShuffle {
    static func seed(day: String, sessionID: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in Data("\(day)|\(sessionID)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash == 0 ? 1 : hash
    }

    static func dayStamp(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Fisher-Yates. Same seed is stable. A new day or session id changes the seed.
    /// The previous video is moved off the front so a new session does not open on it.
    static func ordered(_ videos: [DailyVideo], seed: UInt64, avoiding lastID: String?) -> [DailyVideo] {
        var unique: [DailyVideo] = []
        var seen = Set<String>()
        for video in videos where DailyFireID.isPlayable(video.videoId) && seen.insert(video.videoId).inserted {
            unique.append(video)
        }
        guard unique.count > 1 else { return unique }

        var rng = SplitMix64(state: seed)
        for index in stride(from: unique.count - 1, through: 1, by: -1) {
            let swap = Int(rng.next() % UInt64(index + 1))
            unique.swapAt(index, swap)
        }
        if let lastID, unique[0].videoId == lastID {
            unique.append(unique.removeFirst())
        }
        return unique
    }
}

struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum YouTubeRequest {
    static let bundleHeader = "X-Ios-Bundle-Identifier"
    static let timeout: TimeInterval = 12

    static func make(url: URL, bundleID: String) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        let bundle = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(bundle.isEmpty ? "com.azealcompany.fueg0" : bundle, forHTTPHeaderField: bundleHeader)
        return request
    }
}

enum YouTubeEmbed {
    static func origin(bundleID: String?) -> String {
        let raw = (bundleID?.isEmpty == false) ? bundleID! : "com.azealcompany.fueg0"
        return "https://\(raw.lowercased())"
    }

    /// Official IFrame Player API document. Returns nil for an id the player cannot load.
    static func html(videoID: String, origin: String) -> String? {
        guard DailyFireID.isPlayable(videoID) else { return nil }
        let safeOrigin = origin.filter { $0 != "'" && $0 != "\\" && $0 != "<" && $0 != ">" }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>
          html, body { margin: 0; background: #000; height: 100%; }
          #player { position: absolute; top: 0; right: 0; bottom: 0; left: 0; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
          function fueg0Post(message) {
            try { window.webkit.messageHandlers.fueg0.postMessage(message); } catch (e) {}
          }
          var tag = document.createElement('script');
          tag.src = "https://www.youtube.com/iframe_api";
          document.head.appendChild(tag);
          var player;
          var ready = false;
          function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
              width: '100%',
              height: '100%',
              videoId: '\(videoID)',
              playerVars: {
                autoplay: 0,
                playsinline: 1,
                rel: 0,
                controls: 1,
                origin: '\(safeOrigin)'
              },
              events: {
                onReady: function() {
                  ready = true;
                  fueg0Post('ready');
                },
                onStateChange: function(event) {
                  if (event.data === 1) { fueg0Post('playing'); }
                },
                onError: function(event) {
                  var code = (event && event.data !== undefined) ? event.data : 'unknown';
                  fueg0Post('error:' + code);
                }
              }
            });
          }
          setTimeout(function() {
            if (!ready) { fueg0Post('error:timeout'); }
          }, 15000);
        </script>
        </body>
        </html>
        """
    }
}

struct YouTubeCandidate: Equatable {
    var id: String
    var title: String
    var thumbnailURL: String
}

struct YouTubeDetail: Equatable {
    var durationSeconds: Int
    var embeddable: Bool?
    var privacyStatus: String
    var uploadStatus: String
}

enum YouTubePayload {
    static let minimumSeconds = 90
    static let maximumSeconds = 4 * 60 * 60

    static func errorReason(in data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else { return nil }
        if let errors = error["errors"] as? [[String: Any]],
           let reason = errors.first?["reason"] as? String,
           !reason.isEmpty {
            return reason
        }
        if let message = error["message"] as? String, !message.isEmpty {
            return message
        }
        return "error"
    }

    static func searchCandidates(in data: Data) -> [YouTubeCandidate] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            let idWrap = item["id"] as? [String: Any]
            let id = (idWrap?["videoId"] as? String) ?? (item["id"] as? String)
            guard let id, DailyFireID.isPlayable(id) else { return nil }
            let snippet = item["snippet"] as? [String: Any]
            let title = decodeTitle((snippet?["title"] as? String) ?? "Motivational fire")
            let thumbs = snippet?["thumbnails"] as? [String: Any]
            let thumb = (thumbs?["high"] as? [String: Any])
                ?? (thumbs?["medium"] as? [String: Any])
                ?? (thumbs?["default"] as? [String: Any])
            let thumbURL = (thumb?["url"] as? String) ?? "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"
            return YouTubeCandidate(id: id, title: title, thumbnailURL: thumbURL)
        }
    }

    enum DetailsParse: Equatable {
        case parsed([String: YouTubeDetail])
        case failed
    }

    static func details(in data: Data) -> DetailsParse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .failed }
        if json["error"] != nil { return .failed }
        guard let items = json["items"] as? [[String: Any]] else { return .failed }
        var map: [String: YouTubeDetail] = [:]
        for item in items {
            guard let id = item["id"] as? String else { continue }
            let content = item["contentDetails"] as? [String: Any]
            let duration = parseISODuration((content?["duration"] as? String) ?? "")
            let status = item["status"] as? [String: Any]
            let embeddable = status?["embeddable"] as? Bool
            let privacy = (status?["privacyStatus"] as? String) ?? ""
            let upload = (status?["uploadStatus"] as? String) ?? ""
            map[id] = YouTubeDetail(
                durationSeconds: duration,
                embeddable: embeddable,
                privacyStatus: privacy,
                uploadStatus: upload
            )
        }
        return .parsed(map)
    }

    static func select(candidates: [YouTubeCandidate], details: [String: YouTubeDetail], requireDetails: Bool) -> [YouTubeCandidate] {
        candidates.filter { candidate in
            guard DailyFireID.isPlayable(candidate.id), !isClickbait(candidate.title) else { return false }
            guard requireDetails else { return true }
            guard let detail = details[candidate.id] else { return false }
            if detail.embeddable == false { return false }
            if detail.privacyStatus.lowercased() == "private" { return false }
            if ["rejected", "failed", "deleted"].contains(detail.uploadStatus.lowercased()) { return false }
            if detail.durationSeconds > 0,
               detail.durationSeconds < minimumSeconds || detail.durationSeconds > maximumSeconds {
                return false
            }
            return true
        }
    }

    static func parseISODuration(_ iso: String) -> Int {
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: iso, range: NSRange(iso.startIndex..., in: iso)),
              match.range.location != NSNotFound
        else { return 0 }
        func group(_ index: Int) -> Int {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swift = Range(range, in: iso) else { return 0 }
            return Int(iso[swift]) ?? 0
        }
        return group(1) * 3600 + group(2) * 60 + group(3)
    }

    static func isClickbait(_ title: String) -> Bool {
        let pattern = "(insane|shocking|you wont believe|gone wrong|destroyed|exposed|"
            + "beast mode|alpha male|sigma|gym hype|prank|reaction|tiktok|shorts|"
            + "#shorts|must watch|watch this)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(title.startIndex..., in: title)
        return regex.firstMatch(in: title, range: range) != nil
    }

    static func decodeTitle(_ raw: String) -> String {
        var title = raw
        let entities = [
            ("&quot;", "\""),
            ("&#34;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&")
        ]
        for (entity, character) in entities {
            title = title.replacingOccurrences(of: entity, with: character)
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Motivational fire" : trimmed
    }
}

struct DailyFireEngine {
    var apiKey: String
    var curated: [DailyVideo]
    var quotes: [String]
    var blockedIDs: Set<String>
    var legendaryOnly: Bool
    var fetch: (URL) async throws -> (Int, Data)

    static let legendaryQueries = [
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

    static let expandedQueries = legendaryQueries + [
        "rocky balboa speech to his son",
        "300 this is sparta speech",
        "military motivation speech full",
        "no excuses motivation speech"
    ]

    static func queries(legendaryOnly: Bool) -> [String] {
        legendaryOnly ? legendaryQueries : expandedQueries
    }

    static func searchURL(query: String, key: String) -> URL? {
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        comps?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "maxResults", value: "15"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "videoSyndicated", value: "true"),
            URLQueryItem(name: "safeSearch", value: "moderate"),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "key", value: key)
        ]
        return comps?.url
    }

    static func detailsURL(ids: [String], key: String) -> URL? {
        let playable = ids.filter(DailyFireID.isPlayable)
        guard !playable.isEmpty else { return nil }
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
        comps?.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails,status"),
            URLQueryItem(name: "id", value: playable.prefix(50).joined(separator: ",")),
            URLQueryItem(name: "key", value: key)
        ]
        return comps?.url
    }

    func load(
        day: String,
        sessionID: String,
        lastPlayedID: String?,
        cached: DailyFireCatalogCache?
    ) async -> DailyFireLoad {
        let quote = quoteForDay(day)
        if let cached, cached.day == day {
            let ready = prepare(cached.videos, quote: quote, day: day, sessionID: sessionID, lastPlayedID: lastPlayedID)
            if !ready.isEmpty {
                return DailyFireLoad(
                    feed: DailyFireFeed(videos: ready, notice: cached.notice, source: cached.source),
                    cacheToWrite: nil
                )
            }
        }

        let fetched = await fetchCatalog(day: day, quote: quote)
        let ready = prepare(fetched.videos, quote: quote, day: day, sessionID: sessionID, lastPlayedID: lastPlayedID)
        return DailyFireLoad(
            feed: DailyFireFeed(videos: ready, notice: fetched.notice, source: fetched.source),
            cacheToWrite: DailyFireCatalogCache(
                day: day,
                videos: fetched.videos,
                notice: fetched.notice,
                source: fetched.source
            )
        )
    }

    func quoteForDay(_ day: String) -> String {
        let lines = quotes.isEmpty ? ["Stay hard."] : quotes
        let index = Int(DailyFireShuffle.seed(day: day, sessionID: "quote") % UInt64(lines.count))
        return lines[index]
    }

    private func prepare(
        _ videos: [DailyVideo],
        quote: String,
        day: String,
        sessionID: String,
        lastPlayedID: String?
    ) -> [DailyVideo] {
        let allowed = videos
            .filter { DailyFireID.isPlayable($0.videoId) && !blockedIDs.contains($0.videoId) }
            .map { video -> DailyVideo in
                var copy = video
                copy.quote = quote
                return copy
            }
        let seed = DailyFireShuffle.seed(day: day, sessionID: sessionID)
        return DailyFireShuffle.ordered(allowed, seed: seed, avoiding: lastPlayedID)
    }

    private func fetchCatalog(day: String, quote: String) async -> (videos: [DailyVideo], notice: String?, source: DailyFireSource) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return (curated, DailyFireNotice.missingKey, .curated)
        }

        let pool = Self.queries(legendaryOnly: legendaryOnly)
        let queryIndex = Int(DailyFireShuffle.seed(day: day, sessionID: "query") % UInt64(max(pool.count, 1)))
        let query = pool.isEmpty ? "motivational speech" : pool[queryIndex]
        guard let search = Self.searchURL(query: query, key: key) else {
            return (curated, DailyFireNotice.unavailable, .curated)
        }

        do {
            let (status, data) = try await fetch(search)
            if status != 200 || YouTubePayload.errorReason(in: data) != nil {
                return (curated, DailyFireNotice.unavailable, .curated)
            }
            let candidates = YouTubePayload.searchCandidates(in: data)
            guard !candidates.isEmpty else {
                return (curated, DailyFireNotice.empty, .curated)
            }

            let selected = await vetted(candidates: candidates, key: key)
            guard !selected.isEmpty else {
                return (curated, DailyFireNotice.empty, .curated)
            }
            let apiVideos = selected.map { candidate in
                DailyVideo(
                    videoId: candidate.id,
                    title: candidate.title,
                    thumbnailURL: candidate.thumbnailURL,
                    quote: quote
                )
            }
            return (merge(api: apiVideos, curated: curated), nil, .youtube)
        } catch {
            return (curated, DailyFireNotice.offline, .curated)
        }
    }

    private func vetted(candidates: [YouTubeCandidate], key: String) async -> [YouTubeCandidate] {
        guard let url = Self.detailsURL(ids: candidates.map(\.id), key: key) else {
            return YouTubePayload.select(candidates: candidates, details: [:], requireDetails: false)
        }
        do {
            let (status, data) = try await fetch(url)
            guard status == 200 else {
                return YouTubePayload.select(candidates: candidates, details: [:], requireDetails: false)
            }
            switch YouTubePayload.details(in: data) {
            case .failed:
                return YouTubePayload.select(candidates: candidates, details: [:], requireDetails: false)
            case .parsed(let details):
                return YouTubePayload.select(candidates: candidates, details: details, requireDetails: true)
            }
        } catch {
            return YouTubePayload.select(candidates: candidates, details: [:], requireDetails: false)
        }
    }

    private func merge(api: [DailyVideo], curated: [DailyVideo]) -> [DailyVideo] {
        var seen = Set<String>()
        var combined: [DailyVideo] = []
        for video in api + curated where DailyFireID.isPlayable(video.videoId) && seen.insert(video.videoId).inserted {
            combined.append(video)
        }
        return combined
    }
}
