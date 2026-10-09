import Foundation
import SwiftData

@Model
final class SavedPlayer {
    var name: String
    var colorIndex: Int
    var gamesPlayed: Int = 0
    var lastUsed: Date

    var displayName: String {
        Self.displayName(for: name)
    }

    static func displayName(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unnamed player" : name
    }

    init(name: String, colorIndex: Int) {
        self.name = name
        self.colorIndex = colorIndex
        self.lastUsed = .now
    }
}
