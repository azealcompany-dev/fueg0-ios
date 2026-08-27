import Foundation
import UserNotifications

enum NotificationService {
    static let requestID = "fueg0.daily.fire"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: FlutterPrefs.notificationsEnabled)
    }

    static var hour: Int {
        UserDefaults.standard.object(forKey: FlutterPrefs.notificationHour) as? Int ?? 7
    }

    static var minute: Int {
        UserDefaults.standard.object(forKey: FlutterPrefs.notificationMinute) as? Int ?? 0
    }

    static func scheduleIfEnabled() async {
        guard isEnabled else {
            cancelAll()
            return
        }
        _ = await reschedule(enabled: true, hour: hour, minute: minute)
    }

    @discardableResult
    static func reschedule(enabled: Bool, hour: Int, minute: Int) async -> Bool {
        let defaults = UserDefaults.standard
        defaults.set(hour, forKey: FlutterPrefs.notificationHour)
        defaults.set(minute, forKey: FlutterPrefs.notificationMinute)
        defaults.set(enabled, forKey: FlutterPrefs.notificationsEnabled)

        guard enabled else {
            cancelAll()
            return false
        }

        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            defaults.set(false, forKey: FlutterPrefs.notificationsEnabled)
            cancelAll()
            return false
        }
        guard granted else {
            defaults.set(false, forKey: FlutterPrefs.notificationsEnabled)
            cancelAll()
            return false
        }

        cancelAll()
        let content = UNMutableNotificationContent()
        content.title = "Don't break the chain."
        content.body = "Your fire is ready. Tap IGNITE and lock the day."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            defaults.set(false, forKey: FlutterPrefs.notificationsEnabled)
            return false
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
