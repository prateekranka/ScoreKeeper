import Foundation

struct GenericEngine: GameEngine {
    let gameType: GameType = .generic
    let requiresConfiguration = true

    func totalScore(for entries: [ScoreEntry]) -> Int {
        entries.reduce(0) { $0 + $1.points }
    }

    func isGameOver(session: GameSession) -> Bool {
        // Generic games end manually
        session.isComplete
    }

    func winners(session: GameSession) -> [UUID] {
        let playerScores = session.players.map { player in
            (player.id, player.totalScore(in: session))
        }

        guard !playerScores.isEmpty else { return [] }
        guard playerScores.contains(where: { $0.1 != 0 }) else { return [] }

        let bestScore: Int
        switch session.winCondition {
        case .highestScore:
            bestScore = playerScores.map(\.1).max() ?? 0
        case .lowestScore:
            bestScore = playerScores.map(\.1).min() ?? 0
        }

        return playerScores.filter { $0.1 == bestScore }.map(\.0)
    }
}
