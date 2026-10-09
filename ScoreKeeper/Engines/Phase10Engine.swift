import Foundation

struct Phase10Engine: GameEngine {
    let gameType: GameType = .phase10

    func totalScore(for entries: [ScoreEntry]) -> Int {
        // Total is sum of leftover card points
        entries.reduce(0) { $0 + $1.points }
    }

    func currentPhase(for playerID: UUID, in session: GameSession) -> Int {
        // Phase = highest phase completed so far
        let entries = session.rounds.flatMap(\.entries).filter { $0.playerID == playerID }
        var maxPhase = 0
        for entry in entries {
            if let meta = entry.phase10Metadata, meta.phaseCompleted > maxPhase {
                maxPhase = meta.phaseCompleted
            }
        }
        return maxPhase
    }

    func isGameOver(session: GameSession) -> Bool {
        // Game ends when any player completes phase 10
        session.players.contains { player in
            currentPhase(for: player.id, in: session) >= 10
        }
    }

    /// Progress decides placement first: more completed stages always ranks
    /// ahead of fewer. Within the same stage count, fewer leftover points
    /// rank ahead — the same rule the winner calculation applies.
    func ranksAhead(_ lhs: Player, of rhs: Player, in session: GameSession) -> Bool {
        let lhsPhase = currentPhase(for: lhs.id, in: session)
        let rhsPhase = currentPhase(for: rhs.id, in: session)
        guard lhsPhase == rhsPhase else { return lhsPhase > rhsPhase }

        let lhsPoints = lhs.totalScore(in: session)
        let rhsPoints = rhs.totalScore(in: session)
        return lhsPoints < rhsPoints
    }

    func rankingExplanation(session: GameSession) -> String {
        "most stages wins. ties go to the fewest points"
    }

    func winners(session: GameSession) -> [UUID] {
        let hasProgress = session.players.contains { player in
            currentPhase(for: player.id, in: session) > 0 || player.totalScore(in: session) != 0
        }
        guard hasProgress else { return [] }

        // Players who completed phase 10; ties broken by lowest total points
        let completedPlayers = session.players.filter { player in
            currentPhase(for: player.id, in: session) >= 10
        }

        guard !completedPlayers.isEmpty else {
            // If no one finished, highest phase wins, then lowest points
            let maxPhase = session.players.map { currentPhase(for: $0.id, in: session) }.max() ?? 0
            let atMaxPhase = session.players.filter { currentPhase(for: $0.id, in: session) == maxPhase }
            let lowestPoints = atMaxPhase.map { $0.totalScore(in: session) }.min() ?? 0
            return atMaxPhase.filter { $0.totalScore(in: session) == lowestPoints }.map(\.id)
        }

        let lowestPoints = completedPlayers.map { $0.totalScore(in: session) }.min() ?? 0
        return completedPlayers.filter { $0.totalScore(in: session) == lowestPoints }.map(\.id)
    }
}
