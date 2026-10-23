import Foundation

/// Loads a shuffled motivational-video feed for Ignite.
/// YouTube Data API results are cached per calendar day. Order is reshuffled per session.
enum DailyFireService {
    static let sessionID = UUID().uuidString

    private static let cacheKey = "daily_fire_catalog_v2"
    private static let lastPlayedKey = "daily_fire_last_played_id"
    private static let blockedKey = "daily_fire_blocked_ids"
    private static let legendaryOnlyKey = "legendary_speeches_only"

    static var isLegendaryOnly: Bool {
        legendaryOnly(in: .standard)
    }

    static func loadFeed(forceRefresh: Bool = false, defaults: UserDefaults = .standard) async -> DailyFireFeed {
        if forceRefresh {
            defaults.removeObject(forKey: cacheKey)
            defaults.removeObject(forKey: blockedKey)
        }
        let engine = DailyFireEngine(
            apiKey: Secrets.youtubeAPIKey,
            curated: MotivationalCatalog.videos,
            quotes: SampleContent.quotes,
            blockedIDs: blockedIDs(in: defaults),
            legendaryOnly: legendaryOnly(in: defaults),
            fetch: liveFetch
        )
        let result = await engine.load(
            day: DailyFireShuffle.dayStamp(.now, timeZone: .current),
            sessionID: sessionID,
            lastPlayedID: defaults.string(forKey: lastPlayedKey),
            cached: forceRefresh ? nil : readCache(defaults)
        )
        if let cache = result.cacheToWrite, let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: cacheKey)
        }
        return result.feed
    }

    static func rememberPlayed(_ videoID: String, defaults: UserDefaults = .standard) {
        guard DailyFireID.isPlayable(videoID) else { return }
        defaults.set(videoID, forKey: lastPlayedKey)
    }

    static func block(_ videoID: String, defaults: UserDefaults = .standard) {
        guard DailyFireID.isPlayable(videoID) else { return }
        var ids = blockedIDs(in: defaults)
        ids.insert(videoID)
        defaults.set(ids.sorted(), forKey: blockedKey)
    }

    static func liveFetch(_ url: URL) async throws -> (Int, Data) {
        let request = YouTubeRequest.make(
            url: url,
            bundleID: Bundle.main.bundleIdentifier ?? "com.azealcompany.fueg0"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    private static func legendaryOnly(in defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: legendaryOnlyKey) == nil { return true }
        return defaults.bool(forKey: legendaryOnlyKey)
    }

    private static func blockedIDs(in defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: blockedKey) ?? [])
    }

    private static func readCache(_ defaults: UserDefaults) -> DailyFireCatalogCache? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(DailyFireCatalogCache.self, from: data)
    }
}
