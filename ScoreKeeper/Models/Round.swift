import Foundation
import SwiftData

@Model
final class Round {
    var id: UUID = UUID()
    var roundNumber: Int = 1
    var createdAt: Date = Date()
    var session: GameSession?

    @Relationship(deleteRule: .cascade, inverse: \ScoreEntry.round)
    var entries: [ScoreEntry] = []

    init(roundNumber: Int) {
        self.id = UUID()
        self.roundNumber = roundNumber
        self.createdAt = Date()
    }

    func entry(for playerID: UUID) -> ScoreEntry? {
        entries.first { $0.playerID == playerID }
    }
}
