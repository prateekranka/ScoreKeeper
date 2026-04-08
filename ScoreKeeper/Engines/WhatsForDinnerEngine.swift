import Foundation

struct WhatsForDinnerEngine: GameEngine {
    let gameType: GameType = .whatsForDinner

    func totalScore(for entries: [ScoreEntry]) -> Int {
        entries.reduce(0) { $0 + $1.points }
    }

    func isGameOver(session: GameSession) -> Bool {
        session.isComplete
    }

    func winners(session: GameSession) -> [UUID] {
        // Lowest total score wins
        let playerScores = session.players.map { player in
            (player.id, player.totalScore(in: session))
        }

        guard !playerScores.isEmpty else { return [] }

        let lowestScore = playerScores.map(\.1).min() ?? 0
        return playerScores.filter { $0.1 == lowestScore }.map(\.0)
    }
}
