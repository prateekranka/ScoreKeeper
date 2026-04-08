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
}

extension GameEngine {
    var requiresConfiguration: Bool { false }

    func validateEntry(_ entry: ScoreInput) -> ValidationResult {
        .valid
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
