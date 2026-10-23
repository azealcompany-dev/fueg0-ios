import Foundation
#if canImport(Fueg0)
@testable import Fueg0
#endif

struct DailyFireCheckReport {
    var failures: [String]
    var checks: Int
}

enum DailyFireChecks {
    static func run() async -> DailyFireCheckReport {
        var failures: [String] = []
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }

        checkCatalog(check)
        checkIDs(check)
        checkShuffle(check)
        checkDurationAndFilters(check)
        checkEmbedAndRequest(check)
        checkDayStamp(check)
        await checkLoads(check)

        return DailyFireCheckReport(failures: failures, checks: checks)
    }

    private static func checkCatalog(_ check: (Bool, String) -> Void) {
        let ids = MotivationalCatalog.videos.map(\.videoId)
        check(Set(ids).count == ids.count, "curated ids must be unique")
        check(ids.count >= 8, "curated list should be long enough to shuffle")
        check(ids.allSatisfy(DailyFireID.isPlayable), "every curated id must be 11 url-safe characters")
        check(!ids.contains("78rptzkY2jU"), "removed Goggins fallback id must not ship")
        check(!ids.contains("wxWDt5U9Y8s"), "removed Eric Thomas id must not ship")
        check(!ids.contains("3sK3wEAxZph"), "invalid McRaven id must not ship")
        let legendary = DailyFireEngine.queries(legendaryOnly: true)
        let expanded = DailyFireEngine.queries(legendaryOnly: false)
        check(expanded.count > legendary.count, "expanded search pool should add queries")
        check(!legendary.contains("300 this is sparta speech"), "legendary pool stays on speeches")
    }

    private static func checkIDs(_ check: (Bool, String) -> Void) {
        check(DailyFireID.isPlayable("pxBQLFLei70"), "known McRaven id is playable shape")
        check(DailyFireID.isPlayable("IdTMDpizis8"), "Jocko id is playable shape")
        check(!DailyFireID.isPlayable("3sK3wEAxZph12"), "ids that are not 11 characters are rejected")
        check(!DailyFireID.isPlayable(""), "empty id is rejected")
        check(!DailyFireID.isPlayable("short"), "short id is rejected")
        check(!DailyFireID.isPlayable("has space!!"), "ids with spaces are rejected")
        check(!DailyFireID.isPlayable("***********"), "punctuation ids are rejected")
    }

    private static func checkShuffle(_ check: (Bool, String) -> Void) {
        let videos = MotivationalCatalog.videos
        let day = "2026-10-23"
        let seedA = DailyFireShuffle.seed(day: day, sessionID: "session-a")
        let seedB = DailyFireShuffle.seed(day: day, sessionID: "session-b")
        let seedNextDay = DailyFireShuffle.seed(day: "2026-10-24", sessionID: "session-a")
        check(seedA == DailyFireShuffle.seed(day: day, sessionID: "session-a"), "seed is stable")
        check(seedA != seedB, "a new session changes the seed")
        check(seedA != seedNextDay, "a new day changes the seed")

        let first = DailyFireShuffle.ordered(videos, seed: seedA, avoiding: nil)
        let again = DailyFireShuffle.ordered(videos, seed: seedA, avoiding: nil)
        let otherSession = DailyFireShuffle.ordered(videos, seed: seedB, avoiding: nil)
        let otherDay = DailyFireShuffle.ordered(videos, seed: seedNextDay, avoiding: nil)
        check(first.map(\.videoId) == again.map(\.videoId), "same seed keeps the same order")
        check(first.map(\.videoId) != otherSession.map(\.videoId), "sessions shuffle into a fresh order")
        check(first.map(\.videoId) != otherDay.map(\.videoId), "days shuffle into a fresh order")
        check(Set(first.map(\.videoId)).count == first.count, "shuffle does not repeat an id")
        for pair in zip(first.map(\.videoId), first.map(\.videoId).dropFirst()) {
            check(pair.0 != pair.1, "shuffle has no adjacent duplicates")
        }

        let last = first[0].videoId
        let avoided = DailyFireShuffle.ordered(videos, seed: seedA, avoiding: last)
        check(avoided[0].videoId != last, "a new order does not open on the video just played")
        check(Set(avoided.map(\.videoId)) == Set(first.map(\.videoId)), "avoiding a repeat keeps the same videos")

        let only = [videos[0]]
        let single = DailyFireShuffle.ordered(only, seed: seedA, avoiding: videos[0].videoId)
        check(single.count == 1 && single[0].videoId == videos[0].videoId, "a one-video feed still returns that video")

        let duplicated = [videos[0], videos[0], videos[1]]
        let collapsed = DailyFireShuffle.ordered(duplicated, seed: seedA, avoiding: nil)
        check(collapsed.count == 2, "duplicate ids collapse before shuffle")
    }

    private static func checkDurationAndFilters(_ check: (Bool, String) -> Void) {
        check(YouTubePayload.parseISODuration("PT19M20S") == 1160, "minutes and seconds parse")
        check(YouTubePayload.parseISODuration("PT1H2M3S") == 3723, "hours minutes and seconds parse")
        check(YouTubePayload.parseISODuration("PT4M") == 240, "minutes-only parse")
        check(YouTubePayload.parseISODuration("PT45S") == 45, "seconds-only parse")
        check(YouTubePayload.parseISODuration("nope") == 0, "garbage duration is zero")
        check(YouTubePayload.isClickbait("INSANE gym prank you wont believe"), "clickbait titles are rejected")
        check(!YouTubePayload.isClickbait("Admiral McRaven Make Your Bed"), "speech titles stay")
        check(YouTubePayload.decodeTitle("It&#39;s &amp; fire") == "It's & fire", "html entities decode")

        let kept = YouTubeCandidate(id: "pxBQLFLei70", title: "Make Your Bed", thumbnailURL: "https://example.com/a.jpg")
        let hidden = YouTubeCandidate(id: "IdTMDpizis8", title: "GOOD", thumbnailURL: "https://example.com/b.jpg")
        let tiny = YouTubeCandidate(id: "UF8uR6Z6KLc", title: "Stanford", thumbnailURL: "https://example.com/c.jpg")
        let bait = YouTubeCandidate(id: "qp0HIF3SfI4", title: "Must Watch insane prank", thumbnailURL: "https://example.com/d.jpg")
        let details = [
            "pxBQLFLei70": YouTubeDetail(durationSeconds: 1160, embeddable: true, privacyStatus: "public", uploadStatus: "processed"),
            "IdTMDpizis8": YouTubeDetail(durationSeconds: 180, embeddable: false, privacyStatus: "public", uploadStatus: "processed"),
            "UF8uR6Z6KLc": YouTubeDetail(durationSeconds: 30, embeddable: true, privacyStatus: "public", uploadStatus: "processed"),
            "qp0HIF3SfI4": YouTubeDetail(durationSeconds: 600, embeddable: true, privacyStatus: "public", uploadStatus: "processed")
        ]
        let selected = YouTubePayload.select(
            candidates: [kept, hidden, tiny, bait],
            details: details,
            requireDetails: true
        )
        check(selected.map(\.id) == ["pxBQLFLei70"], "unembeddable, too short, and clickbait videos drop")

        let quota = Data(#"{"error":{"code":403,"message":"quota","errors":[{"reason":"quotaExceeded"}]}}"#.utf8)
        check(YouTubePayload.errorReason(in: quota) == "quotaExceeded", "quota errors are recognized")
        check(YouTubePayload.errorReason(in: Data("[]".utf8)) == nil, "a list payload is not an api error")
    }

    private static func checkEmbedAndRequest(_ check: (Bool, String) -> Void) {
        let origin = YouTubeEmbed.origin(bundleID: "com.azealcompany.fueg0")
        check(origin == "https://com.azealcompany.fueg0", "embed origin is the https bundle id")
        let html = YouTubeEmbed.html(videoID: "pxBQLFLei70", origin: origin)
        check(html != nil, "a real id produces an embed document")
        let page = html ?? ""
        check(page.contains("pxBQLFLei70"), "embed document contains the video id")
        check(page.contains("https://www.youtube.com/iframe_api"), "embed uses the official iframe api")
        check(page.contains("strict-origin-when-cross-origin"), "embed sends a referrer")
        check(page.contains("controls: 1"), "player controls stay visible")
        check(!page.contains("controls: 0"), "player controls are not hidden")
        check(page.contains("origin: 'https://com.azealcompany.fueg0'"), "player origin matches the bundle referrer")
        check(YouTubeEmbed.html(videoID: "3sK3wEAxZph12", origin: origin) == nil, "ids with the wrong length do not produce html")

        let url = URL(string: "https://www.googleapis.com/youtube/v3/search?key=abc")!
        let request = YouTubeRequest.make(url: url, bundleID: "com.azealcompany.fueg0")
        check(
            request.value(forHTTPHeaderField: YouTubeRequest.bundleHeader) == "com.azealcompany.fueg0",
            "api requests identify the ios bundle"
        )
        let fallback = YouTubeRequest.make(url: url, bundleID: "  ")
        check(
            fallback.value(forHTTPHeaderField: YouTubeRequest.bundleHeader) == "com.azealcompany.fueg0",
            "empty bundle id falls back to the app id"
        )

        let search = DailyFireEngine.searchURL(query: "stay hard", key: "test-key")
        let items = URLComponents(url: search!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        check(value("videoEmbeddable") == "true", "search asks for embeddable videos")
        check(value("videoSyndicated") == "true", "search asks for syndicated videos")
        check(value("type") == "video", "search asks for videos")
        check(value("key") == "test-key", "search includes the key")
        check(!items.contains { $0.name == "videoDuration" }, "search does not force long videos only")
        check(Secrets.normalized("changeme") == nil, "placeholder keys are ignored")
        check(Secrets.normalized("  ") == nil, "blank keys are ignored")
        check(Secrets.normalized("AIzaSyRealKey") == "AIzaSyRealKey", "a real key is kept")
    }

    private static func checkDayStamp(_ check: (Bool, String) -> Void) {
        var parts = DateComponents()
        parts.calendar = Calendar(identifier: .gregorian)
        parts.timeZone = TimeZone(secondsFromGMT: 0)
        parts.year = 2026
        parts.month = 10
        parts.day = 23
        parts.hour = 23
        parts.minute = 30
        let date = parts.date!
        check(
            DailyFireShuffle.dayStamp(date, timeZone: TimeZone(secondsFromGMT: 0)!) == "2026-10-23",
            "day stamp uses the provided timezone"
        )
        check(
            DailyFireShuffle.dayStamp(date, timeZone: TimeZone(secondsFromGMT: 2 * 60 * 60)!) == "2026-10-24",
            "day stamp rolls over in the user's timezone"
        )
    }

    private static func checkLoads(_ check: (Bool, String) -> Void) async {
        let log = FetchLog()
        let missing = engine(key: "", log: log) { _, _ in (200, Data()) }
        let missingLoad = await missing.load(day: "2026-10-23", sessionID: "a", lastPlayedID: nil, cached: nil)
        check(log.urls.isEmpty, "missing key does not call youtube")
        check(missingLoad.feed.source == .curated, "missing key uses the curated feed")
        check(missingLoad.feed.notice == DailyFireNotice.missingKey, "missing key explains the fallback")
        check(!missingLoad.feed.videos.isEmpty, "missing key still returns videos")
        check(missingLoad.cacheToWrite?.source == .curated, "curated result is cacheable")

        log.urls.removeAll()
        let quotaBody = Data(#"{"error":{"errors":[{"reason":"quotaExceeded"}]}}"#.utf8)
        let quota = engine(key: "live-key", log: log) { url, _ in
            url.path.contains("/search") ? (403, quotaBody) : (500, Data())
        }
        let quotaLoad = await quota.load(day: "2026-10-23", sessionID: "a", lastPlayedID: nil, cached: nil)
        check(quotaLoad.feed.source == .curated, "quota errors fall back to curated videos")
        check(quotaLoad.feed.notice == DailyFireNotice.unavailable, "quota errors tell the user search is down")
        check(Set(quotaLoad.feed.videos.map(\.videoId)) == Set(MotivationalCatalog.videos.map(\.videoId)), "quota fallback is the full curated list")

        log.urls.removeAll()
        let offline = engine(key: "live-key", log: log) { _, _ in
            throw URLError(.notConnectedToInternet)
        }
        let offlineLoad = await offline.load(day: "2026-10-23", sessionID: "a", lastPlayedID: nil, cached: nil)
        check(offlineLoad.feed.source == .curated, "network errors fall back to curated videos")
        check(offlineLoad.feed.notice == DailyFireNotice.offline, "network errors say there is no connection")

        log.urls.removeAll()
        let empty = engine(key: "live-key", log: log) { _, _ in (200, Data(#"{"items":[]}"#.utf8)) }
        let emptyLoad = await empty.load(day: "2026-10-23", sessionID: "a", lastPlayedID: nil, cached: nil)
        check(emptyLoad.feed.notice == DailyFireNotice.empty, "empty search uses the saved list")
        check(emptyLoad.feed.source == .curated, "empty search source is curated")

        log.urls.removeAll()
        let broken = engine(key: "live-key", log: log) { _, _ in (200, Data("not-json".utf8)) }
        let brokenLoad = await broken.load(day: "2026-10-23", sessionID: "a", lastPlayedID: nil, cached: nil)
        check(brokenLoad.feed.source == .curated, "malformed json does not crash and falls back")
        check(!brokenLoad.feed.videos.isEmpty, "malformed json still leaves a feed")

        let searchBody = Data(#"""
        {"items":[
          {"id":{"kind":"youtube#video","videoId":"abcdefghijk"},"snippet":{"title":"Stay Hard &#39;til the end","thumbnails":{"high":{"url":"https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg"}}}},
          {"id":{"videoId":"3sK3wEAxZph"},"snippet":{"title":"bad id"}},
          {"id":{"videoId":"zzzzzzzzzzz"},"snippet":{"title":"INSANE prank must watch"}}
        ]}
        """#.utf8)
        let detailsBody = Data(#"""
        {"items":[
          {"id":"abcdefghijk","contentDetails":{"duration":"PT12M"},"status":{"embeddable":true,"privacyStatus":"public","uploadStatus":"processed"}},
          {"id":"zzzzzzzzzzz","contentDetails":{"duration":"PT12M"},"status":{"embeddable":true,"privacyStatus":"public","uploadStatus":"processed"}}
        ]}
        """#.utf8)
        log.urls.removeAll()
        let live = engine(key: "live-key", log: log) { url, _ in
            if url.path.contains("/videos") { return (200, detailsBody) }
            return (200, searchBody)
        }
        let liveLoad = await live.load(day: "2026-10-23", sessionID: "session-a", lastPlayedID: nil, cached: nil)
        let liveIDs = Set(liveLoad.feed.videos.map(\.videoId))
        check(liveLoad.feed.source == .youtube, "playable search results are a youtube feed")
        check(liveLoad.feed.notice == nil, "a live feed has no fallback notice")
        check(liveIDs.contains("abcdefghijk"), "embeddable search hit is in the feed")
        check(!liveIDs.contains("3sK3wEAxZph"), "invalid search ids are dropped")
        check(!liveIDs.contains("zzzzzzzzzzz"), "clickbait search hits are dropped")
        check(liveIDs.isSuperset(of: Set(MotivationalCatalog.videos.map(\.videoId))), "a short api list is padded with curated videos")
        check(log.urls.contains { $0.path.contains("/search") }, "search is requested")
        check(log.urls.contains { $0.path.contains("/videos") }, "details are requested")
        let titled = liveLoad.feed.videos.first { $0.videoId == "abcdefghijk" }
        check(titled?.title == "Stay Hard 'til the end", "api titles are decoded")

        let sessionB = await live.load(day: "2026-10-23", sessionID: "session-b", lastPlayedID: nil, cached: nil)
        check(
            liveLoad.feed.videos.map(\.videoId) != sessionB.feed.videos.map(\.videoId),
            "the same catalog shuffles differently for another session"
        )
        check(liveLoad.feed.videos.first?.quote == sessionB.feed.videos.first?.quote, "the daily quote stays put across sessions")

        let blocked = Set(MotivationalCatalog.videos.map(\.videoId))
        log.urls.removeAll()
        let allBlocked = engine(key: "", blocked: blocked, log: log) { _, _ in (200, Data()) }
        let blockedLoad = await allBlocked.load(day: "2026-10-23", sessionID: "a", lastPlayedID: nil, cached: nil)
        check(blockedLoad.feed.videos.isEmpty, "blocking every saved video leaves an empty feed instead of crashing")

        log.urls.removeAll()
        let cache = DailyFireCatalogCache(
            day: "2026-10-23",
            videos: MotivationalCatalog.videos,
            notice: nil,
            source: .youtube
        )
        let cachedEngine = engine(key: "live-key", log: log) { _, _ in (500, Data()) }
        let cachedLoad = await cachedEngine.load(day: "2026-10-23", sessionID: "a", lastPlayedID: "pxBQLFLei70", cached: cache)
        check(log.urls.isEmpty, "today's cache does not hit the network")
        check(cachedLoad.cacheToWrite == nil, "a cache hit is not rewritten")
        check(cachedLoad.feed.videos.first?.videoId != "pxBQLFLei70", "cached playback still avoids the last video")
        check(cachedLoad.feed.source == .youtube, "cached youtube source is preserved")

        log.urls.removeAll()
        _ = await cachedEngine.load(day: "2026-10-24", sessionID: "a", lastPlayedID: nil, cached: cache)
        check(!log.urls.isEmpty, "a cache from another day refreshes")
    }

    private static func engine(
        key: String,
        blocked: Set<String> = [],
        log: FetchLog,
        handler: @escaping (URL, FetchLog) async throws -> (Int, Data)
    ) -> DailyFireEngine {
        DailyFireEngine(
            apiKey: key,
            curated: MotivationalCatalog.videos,
            quotes: ["Stay hard.", "Discipline equals freedom."],
            blockedIDs: blocked,
            legendaryOnly: true,
            fetch: { url in
                log.urls.append(url)
                return try await handler(url, log)
            }
        )
    }
}

final class FetchLog {
    var urls: [URL] = []
}
