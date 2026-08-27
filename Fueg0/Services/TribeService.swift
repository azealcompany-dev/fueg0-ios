import FirebaseFirestore
import Foundation

enum TribeFeedLoad {
    case loaded([TribeActivity])
    case unavailable
}

struct TribeService {
    private var db: Firestore { Firestore.firestore() }

    static func weekKey(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        // Convert Sunday=1 ... Saturday=7 into days since Monday.
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: start) ?? start
        return weekFormatter.string(from: monday)
    }

    func fetchLeaderboard(userTribeID: String?) async throws -> [TribeLeaderboardEntry] {
        let week = Self.weekKey()
        var entries: [TribeLeaderboardEntry] = []
        for tribe in Tribe.all {
            let snap = try await db.collection("tribes").document(tribe.id).getDocument()
            let points = Self.points(from: snap.data(), currentWeek: week)
            entries.append(
                TribeLeaderboardEntry(
                    tribe: tribe,
                    weeklyPoints: points.weekly,
                    totalPoints: points.total,
                    level: Tribe.level(fromTotalPoints: points.total),
                    rank: 0,
                    isUserTribe: userTribeID == tribe.id
                )
            )
        }

        entries.sort {
            if $0.weeklyPoints != $1.weeklyPoints {
                return $0.weeklyPoints > $1.weeklyPoints
            }
            return $0.tribe.name < $1.tribe.name
        }

        return entries.enumerated().map { index, entry in
            TribeLeaderboardEntry(
                tribe: entry.tribe,
                weeklyPoints: entry.weeklyPoints,
                totalPoints: entry.totalPoints,
                level: entry.level,
                rank: index + 1,
                isUserTribe: entry.isUserTribe
            )
        }
    }

    func fetchFeed(tribeID: String) async -> TribeFeedLoad {
        guard Tribe.byID(tribeID) != nil else { return .unavailable }
        do {
            let snap = try await db.collection("tribes")
                .document(tribeID)
                .collection("feed")
                .order(by: "timestamp", descending: true)
                .limit(to: 30)
                .getDocuments()

            let items = snap.documents.compactMap { doc -> TribeActivity? in
                let data = doc.data()
                let type = data["type"] as? String ?? ""
                guard type == "joined" || type == "goal_completed" else { return nil }
                let name = (data["userName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return TribeActivity(
                    id: doc.documentID,
                    userName: (name?.isEmpty == false ? name! : "Warrior"),
                    message: data["message"] as? String ?? "",
                    timestamp: Self.date(from: data["timestamp"]) ?? Date(),
                    type: type
                )
            }
            return .loaded(items)
        } catch {
            return .unavailable
        }
    }

    func writeMembership(uid: String, tribeID: String) async throws {
        guard let normalized = Tribe.normalizeID(tribeID) else {
            throw TribeServiceError.invalidTribe
        }
        try await db.collection("users").document(uid).setData(
            [
                "tribeId": normalized,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    static let pointsPerGoal = 15

    @discardableResult
    func awardPointsForGoal(
        goalId: String,
        goalTitle: String,
        tribeID: String,
        userName: String,
        userID: String
    ) async -> Int {
        guard Tribe.byID(tribeID) != nil else { return 0 }
        let today = Self.weekFormatter.string(from: Date())
        let awardID = "\(today)_\(goalId)"
        let awardRef = db.collection("users").document(userID).collection("tribeGoalAwards").document(awardID)
        let tribeRef = db.collection("tribes").document(tribeID)
        let userRef = db.collection("users").document(userID)
        let week = Self.weekKey()
        let localKey = FlutterPrefs.tribeGoalAward(date: today, goalId: goalId)

        do {
            let existing = try await awardRef.getDocument()
            if existing.exists { return 0 }

            _ = try await db.runTransaction { tx, errorPointer in
                do {
                    let snap = try tx.getDocument(tribeRef)
                    let data = snap.data()
                    var total = Self.intValue(data?["totalPoints"]) ?? 0
                    var weekly = Self.intValue(data?["weeklyPoints"]) ?? 0
                    if (data?["weekKey"] as? String ?? "") != week { weekly = 0 }
                    total += Self.pointsPerGoal
                    weekly += Self.pointsPerGoal
                    tx.setData(
                        [
                            "totalPoints": total,
                            "weeklyPoints": weekly,
                            "weekKey": week,
                            "updatedAt": FieldValue.serverTimestamp()
                        ],
                        forDocument: tribeRef,
                        merge: true
                    )
                    tx.setData(
                        ["tribeContributions": FieldValue.increment(Int64(Self.pointsPerGoal))],
                        forDocument: userRef,
                        merge: true
                    )
                    tx.setData(
                        ["awardedAt": FieldValue.serverTimestamp()],
                        forDocument: awardRef,
                        merge: true
                    )
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            UserDefaults.standard.set(true, forKey: localKey)
            await postGoalActivity(tribeID: tribeID, userName: userName, userID: userID, goalTitle: goalTitle)
            return Self.pointsPerGoal
        } catch {
            if UserDefaults.standard.bool(forKey: localKey) { return 0 }
            UserDefaults.standard.set(true, forKey: localKey)
            return Self.pointsPerGoal
        }
    }

    @discardableResult
    func removePointsForGoal(
        goalId: String,
        tribeID: String,
        userID: String
    ) async -> Int {
        guard Tribe.byID(tribeID) != nil else { return 0 }
        let today = Self.weekFormatter.string(from: Date())
        let awardID = "\(today)_\(goalId)"
        let awardRef = db.collection("users").document(userID).collection("tribeGoalAwards").document(awardID)
        let tribeRef = db.collection("tribes").document(tribeID)
        let userRef = db.collection("users").document(userID)
        let week = Self.weekKey()
        let localKey = FlutterPrefs.tribeGoalAward(date: today, goalId: goalId)

        do {
            let existing = try await awardRef.getDocument()
            if !existing.exists {
                if UserDefaults.standard.bool(forKey: localKey) {
                    UserDefaults.standard.set(false, forKey: localKey)
                    return -Self.pointsPerGoal
                }
                return 0
            }

            _ = try await db.runTransaction { tx, errorPointer in
                do {
                    let snap = try tx.getDocument(tribeRef)
                    let data = snap.data()
                    var total = Self.intValue(data?["totalPoints"]) ?? 0
                    var weekly = Self.intValue(data?["weeklyPoints"]) ?? 0
                    if (data?["weekKey"] as? String ?? "") != week { weekly = 0 }
                    total = max(0, total - Self.pointsPerGoal)
                    weekly = max(0, weekly - Self.pointsPerGoal)
                    tx.setData(
                        [
                            "totalPoints": total,
                            "weeklyPoints": weekly,
                            "weekKey": week,
                            "updatedAt": FieldValue.serverTimestamp()
                        ],
                        forDocument: tribeRef,
                        merge: true
                    )
                    tx.setData(
                        ["tribeContributions": FieldValue.increment(Int64(-Self.pointsPerGoal))],
                        forDocument: userRef,
                        merge: true
                    )
                    tx.deleteDocument(awardRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            UserDefaults.standard.set(false, forKey: localKey)
            return -Self.pointsPerGoal
        } catch {
            if UserDefaults.standard.bool(forKey: localKey) {
                UserDefaults.standard.set(false, forKey: localKey)
                return -Self.pointsPerGoal
            }
            return 0
        }
    }

    func postGoalActivity(tribeID: String, userName: String, userID: String, goalTitle: String) async {
        guard Tribe.byID(tribeID) != nil else { return }
        let clippedName = String(userName.prefix(80))
        let message = String("completed \(goalTitle) (+\(Self.pointsPerGoal) pts)".prefix(300))
        let payload: [String: Any] = [
            "userName": clippedName.isEmpty ? "Warrior" : clippedName,
            "message": message,
            "type": "goal_completed",
            "timestamp": FieldValue.serverTimestamp(),
            "userId": userID
        ]
        do {
            try await db.collection("tribes").document(tribeID).collection("feed").addDocument(data: payload)
        } catch {
            // Feed is best-effort.
        }
    }

    func postJoinedActivity(tribeID: String, userName: String, userID: String) async {
        guard Tribe.byID(tribeID) != nil else { return }
        let clippedName = String(userName.prefix(80))
        let payload: [String: Any] = [
            "userName": clippedName.isEmpty ? "Warrior" : clippedName,
            "message": "joined the tribe",
            "type": "joined",
            "timestamp": FieldValue.serverTimestamp(),
            "userId": userID
        ]
        do {
            try await db.collection("tribes").document(tribeID).collection("feed").addDocument(data: payload)
        } catch {
            // Feed is best-effort. Membership already landed on the user doc.
        }
    }

    private static func points(from data: [String: Any]?, currentWeek: String) -> (total: Int, weekly: Int) {
        guard let data else { return (0, 0) }
        let total = intValue(data["totalPoints"]) ?? 0
        let storedWeek = data["weekKey"] as? String ?? ""
        let weekly = storedWeek == currentWeek ? (intValue(data["weeklyPoints"]) ?? 0) : 0
        return (max(0, total), max(0, weekly))
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? Int64 { return Int(n) }
        if let n = any as? NSNumber { return n.intValue }
        if let d = any as? Double { return Int(d) }
        return nil
    }

    private static func date(from any: Any?) -> Date? {
        if let ts = any as? Timestamp { return ts.dateValue() }
        if let date = any as? Date { return date }
        if let string = any as? String {
            if let fractional = isoFractional.date(from: string) { return fractional }
            if let plain = isoPlain.date(from: string) { return plain }
            return weekFormatter.date(from: string)
        }
        return nil
    }

    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

enum TribeServiceError: LocalizedError {
    case invalidTribe
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidTribe:
            return "Invalid tribe selection. Please try again."
        case .notSignedIn:
            return "Sign in to join a tribe."
        }
    }
}
