import Foundation
import SwiftData

@Model
final class GameSession {
    var id: UUID = UUID()
    var gameTypeRaw: String = GameType.generic.rawValue
    var createdAt: Date
    var completedAt: Date?
    var isComplete: Bool = false
    var winnerID: UUID?
    var targetScore: Int?
    var phase10SkipOnFail: Bool = false
    var winConditionRaw: String = WinCondition.highestScore.rawValueString

    @Relationship(deleteRule: .cascade, inverse: \Player.session)
    var players: [Player] = []

    @Relationship(deleteRule: .cascade, inverse: \Round.session)
    var rounds: [Round] = []

    var gameType: GameType {
        get { GameType(rawValue: gameTypeRaw) ?? .generic }
        set { gameTypeRaw = newValue.rawValue }
    }

    var winCondition: WinCondition {
        get {
            WinCondition.from(rawValueString: winConditionRaw)
        }
        set {
            winConditionRaw = newValue.rawValueString
        }
    }

    var isInProgress: Bool { !isComplete }

    var sortedRounds: [Round] {
        rounds.sorted { $0.roundNumber < $1.roundNumber }
    }

    var currentRoundNumber: Int {
        (rounds.map(\.roundNumber).max() ?? 0) + 1
    }

    init(gameType: GameType) {
        self.id = UUID()
        self.gameTypeRaw = gameType.rawValue
        self.createdAt = .now
        self.winConditionRaw = gameType.defaultWinCondition.rawValueString
    }
}

extension WinCondition {
    var rawValueString: String {
        switch self {
        case .highestScore: return "highest"
        case .lowestScore: return "lowest"
        }
    }

    static func from(rawValueString: String) -> WinCondition {
        switch rawValueString {
        case "lowest": return .lowestScore
        default: return .highestScore
        }
    }
}
