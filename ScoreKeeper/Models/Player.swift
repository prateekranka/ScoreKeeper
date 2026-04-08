import Foundation
import SwiftData

@Model
final class Player {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 0
    var session: GameSession?

    init(name: String, colorIndex: Int) {
        self.id = UUID()
        self.name = name
        self.colorIndex = colorIndex
    }

    func totalScore(in session: GameSession) -> Int {
        session.rounds.flatMap(\.entries).filter { $0.playerID == id }.reduce(0) { $0 + $1.points }
    }
}
