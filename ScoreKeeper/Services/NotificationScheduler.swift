import Foundation
import UserNotifications

enum NotificationDestination: String, Sendable {
    case home, gift, proManagement
}

struct LocalNotification: Equatable, Sendable {
    let identifier: String
    let body: String
    let date: Date
    let destination: NotificationDestination
}

@MainActor
protocol LocalNotificationCenter {
    func requestAuthorization() async throws -> Bool
    func isAuthorized() async -> Bool
    func add(_ notification: LocalNotification) async throws
    func removePending(identifiers: [String])
    func removeAllPending()
    func removeAllDelivered()
}

@MainActor
final class SystemLocalNotificationCenter: LocalNotificationCenter {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    func add(_ notification: LocalNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = "PipCount"
        content.body = notification.body
        content.sound = .default
        content.userInfo = ["destination": notification.destination.rawValue]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .timeZone], from: notification.date
        )
        try await center.add(UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    func removePending(identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func removeAllPending() { center.removeAllPendingNotificationRequests() }
    func removeAllDelivered() { center.removeAllDeliveredNotifications() }
}

@MainActor
final class SilentLocalNotificationCenter: LocalNotificationCenter {
    func requestAuthorization() async throws -> Bool { false }
    func isAuthorized() async -> Bool { false }
    func add(_ notification: LocalNotification) async throws {}
    func removePending(identifiers: [String]) {}
    func removeAllPending() {}
    func removeAllDelivered() {}
}

@MainActor
final class NotificationScheduler {
    static let identifiers = ["pipcount.trial", "pipcount.gift"] + (0..<4).map { "pipcount.friday.\($0)" }

    private let center: any LocalNotificationCenter
    private let preferences: MonetizationPreferences
    private var revision = 0
    private var isSynchronizing = false
    private var latestEntitlement = ProEntitlement()
    private var latestDate = Date()

    init(center: any LocalNotificationCenter, preferences: MonetizationPreferences) {
        self.center = center
        self.preferences = preferences
    }

    func askPermissionIfNeeded(entitlement: ProEntitlement) async {
        guard !entitlement.hasConverted, preferences.value(.converted) == 0,
              preferences.value(.permissionAsked) == 0 else { return }
        preferences.set(.permissionAsked)
        preferences.setDateOnce(.weeklyAnchor, date: Date())
        _ = try? await center.requestAuthorization()
    }

    func synchronize(entitlement: ProEntitlement, now: Date = Date()) async {
        latestEntitlement = entitlement
        latestDate = now
        if entitlement.hasConverted { preferences.set(.converted) }
        revision += 1
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }
        var completedRevision: Int
        repeat {
            completedRevision = revision
            await update(entitlement: latestEntitlement, now: latestDate, revision: completedRevision)
        } while completedRevision != revision
    }

    private func update(entitlement: ProEntitlement, now: Date, revision: Int) async {
        if preferences.value(.converted) > 0 {
            center.removeAllPending()
            center.removeAllDelivered()
            return
        }
        guard preferences.value(.permissionAsked) > 0, await center.isAuthorized(), self.revision == revision else { return }
        center.removePending(identifiers: Self.identifiers)
        let notifications = Self.plan(
            entitlement: entitlement,
            exitOfferClosedAt: preferences.date(.exitOfferClosedAt),
            weeklyAnchor: preferences.date(.weeklyAnchor),
            now: now
        )
        for notification in notifications {
            guard self.revision == revision, preferences.value(.converted) == 0 else { return }
            try? await center.add(notification)
        }
    }

    static func plan(
        entitlement: ProEntitlement,
        exitOfferClosedAt: Date?,
        weeklyAnchor: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> [LocalNotification] {
        guard !entitlement.hasConverted else { return [] }
        var result: [LocalNotification] = []
        if let trialEnd = entitlement.trialEnd {
            let date = trialEnd.addingTimeInterval(-24 * 60 * 60)
            if date > now {
                result.append(LocalNotification(identifier: "pipcount.trial", body: "Your free trial ends tomorrow.", date: date, destination: .proManagement))
            }
        }
        if !entitlement.isPro, let closed = exitOfferClosedAt {
            let date = closed.addingTimeInterval(24 * 60 * 60)
            if date > now {
                result.append(LocalNotification(identifier: "pipcount.gift", body: "Your 50% gift is still here.", date: date, destination: .gift))
            }
        }
        if let anchor = weeklyAnchor,
           let first = calendar.nextDate(after: anchor, matching: DateComponents(hour: 18, minute: 0, second: 0, weekday: 6), matchingPolicy: .nextTime) {
            for index in 0..<4 {
                if let date = calendar.date(byAdding: .weekOfYear, value: index, to: first), date > now {
                    result.append(LocalNotification(identifier: "pipcount.friday.\(index)", body: "Game night?", date: date, destination: .home))
                }
            }
        }
        return result
    }
}
