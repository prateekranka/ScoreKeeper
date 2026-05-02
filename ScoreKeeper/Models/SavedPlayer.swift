import Foundation
import SwiftData

@Model
final class SavedPlayer {
    var name: String
    var colorIndex: Int
    var gamesPlayed: Int = 0
    var lastUsed: Date

    init(name: String, colorIndex: Int) {
        self.name = name
        self.colorIndex = colorIndex
        self.lastUsed = .now
    }
}
