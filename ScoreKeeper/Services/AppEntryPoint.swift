import Observation
import UIKit
import UserNotifications

struct GiftQuickAction: Equatable, Sendable {
    static let type = "pipcount.gift"
    let title = "50% off gift"
    let symbol = "gift"

    static func item(isPro: Bool, hasDismissedPaywall: Bool) -> GiftQuickAction? {
        !isPro && hasDismissedPaywall ? GiftQuickAction() : nil
    }
}

@MainActor
@Observable
final class AppEntryPoint {
    static let shared = AppEntryPoint()
    var destination: NotificationDestination?

    func open(_ destination: NotificationDestination) {
        self.destination = destination
    }

    func updateQuickAction(isPro: Bool, hasDismissedPaywall: Bool) {
        UIApplication.shared.shortcutItems = GiftQuickAction.item(isPro: isPro, hasDismissedPaywall: hasDismissedPaywall).map {
            [UIApplicationShortcutItem(type: GiftQuickAction.type, localizedTitle: $0.title, localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: $0.symbol))]
        } ?? []
    }
}

@MainActor
final class PipCountAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.shortcutItem?.type == GiftQuickAction.type {
            AppEntryPoint.shared.open(.gift)
        }
        let configuration = connectingSceneSession.configuration
        configuration.delegateClass = PipCountSceneDelegate.self
        return configuration
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let value = response.notification.request.content.userInfo["destination"] as? String,
              let destination = NotificationDestination(rawValue: value) else { return }
        await AppEntryPoint.shared.open(destination)
    }
}

@MainActor
final class PipCountSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if connectionOptions.shortcutItem?.type == GiftQuickAction.type {
            AppEntryPoint.shared.open(.gift)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handled = shortcutItem.type == GiftQuickAction.type
        if handled { AppEntryPoint.shared.open(.gift) }
        completionHandler(handled)
    }
}
