import Foundation

struct ScoreInput {
    let playerID: UUID
    let points: Int
    let metadata: String?
}

enum ValidationResult {
    case valid
    case invalid(reason: String)
}

protocol GameEngine {
    var gameType: GameType { get }

    /// Whether this game needs the GameConfigView
    var requiresConfiguration: Bool { get }

    /// Calculate total score for a player given all their entries
    func totalScore(for entries: [ScoreEntry]) -> Int

    /// Determine if the game is over based on current state
    func isGameOver(session: GameSession) -> Bool

    /// Determine the winner(s) — returns player IDs
    func winners(session: GameSession) -> [UUID]

    /// Validate a score entry before committing
    func validateEntry(_ entry: ScoreInput) -> ValidationResult

    /// True when `lhs` places strictly ahead of `rhs` in the final standings.
    /// Ties return false in both directions. This is the single ranking rule
    /// shared by results, share cards, and statistics, so the declared winner
    /// always leads the order.
    func ranksAhead(_ lhs: Player, of rhs: Player, in session: GameSession) -> Bool

    /// One-line explanation of this engine's ranking rule for result surfaces.
    func rankingExplanation(session: GameSession) -> String
}

extension GameEngine {
    var requiresConfiguration: Bool { false }

    func validateEntry(_ entry: ScoreInput) -> ValidationResult {
        .valid
    }

    /// Score-based default: the strongest total leads for the session's win
    /// condition. Engines with progress-based rules override this.
    func ranksAhead(_ lhs: Player, of rhs: Player, in session: GameSession) -> Bool {
        let lhsScore = lhs.totalScore(in: session)
        let rhsScore = rhs.totalScore(in: session)
        guard lhsScore != rhsScore else { return false }
        return session.winCondition == .highestScore ? lhsScore > rhsScore : lhsScore < rhsScore
    }

    /// Players ordered from best to worst, with a stable name tiebreak.
    func rankedPlayers(session: GameSession) -> [Player] {
        session.players.sorted { lhs, rhs in
            if ranksAhead(lhs, of: rhs, in: session) { return true }
            if ranksAhead(rhs, of: lhs, in: session) { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Competition rank: ties share a rank and the next rank skips the tie.
    func rank(of player: Player, in session: GameSession) -> Int {
        session.players.filter { ranksAhead($0, of: player, in: session) }.count + 1
    }

    func rankingExplanation(session: GameSession) -> String {
        session.winCondition == .highestScore ? "highest score wins" : "lowest score wins"
    }
}

enum GameEngineFactory {
    static func engine(for type: GameType) -> GameEngine {
        switch type {
        case .generic: return GenericEngine()
        case .whatsForDinner: return WhatsForDinnerEngine()
        case .phase10: return Phase10Engine()
        }
    }
}
