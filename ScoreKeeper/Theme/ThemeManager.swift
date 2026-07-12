import SwiftUI

@MainActor @Observable
final class ThemeManager {
    var mode: String {
        didSet { UserDefaults.standard.set(mode, forKey: "themeMode") }
    }

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-in-memory-store"), arguments.contains("-force-light-theme") {
            mode = "light"
        } else {
            mode = UserDefaults.standard.string(forKey: "themeMode") ?? "system"
        }
    }

    var effectiveColorScheme: ColorScheme? {
        switch mode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var iconName: String {
        switch mode {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    func cycle() {
        switch mode {
        case "system": mode = "light"
        case "light": mode = "dark"
        case "dark": mode = "system"
        default: mode = "system"
        }
    }
}
