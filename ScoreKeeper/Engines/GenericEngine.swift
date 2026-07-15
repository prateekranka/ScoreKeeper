import Foundation

struct GenericEngine: GameEngine {
    let gameType: GameType = .generic
    let requiresConfiguration = true

    func totalScore(for entries: [ScoreEntry]) -> Int {
        entries.reduce(0) { $0 + $1.points }
    }

    func isGameOver(session: GameSession) -> Bool {
        // Manual completion remains authoritative. A configured target is an
        // automatic trigger, but only after a real scoring round has been
        // submitted. This keeps a target-configured game open at launch and
        // allows a zero-point round to count as a submitted round without
        // accidentally ending the game.
        guard !session.isComplete else { return true }
        guard let targetScore = session.targetScore, targetScore > 0 else { return false }
        guard !session.rounds.isEmpty else { return false }

        return session.players.contains { player in
            player.totalScore(in: session) >= targetScore
        }
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
