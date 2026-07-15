import SwiftUI

enum WinCondition: Codable {
    case highestScore
    case lowestScore
}

enum GameType: String, Codable, CaseIterable, Identifiable {
    case generic
    case whatsForDinner
    case phase10

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generic: return "Scoreboard"
        case .whatsForDinner: return "What's for Dinner"
        case .phase10: return "Ten Phases"
        }
    }

    var subtitle: String {
        switch self {
        case .generic: return "Track any game"
        case .whatsForDinner: return "Lowest hand wins"
        case .phase10: return "ten-stage card-game scoring"
        }
    }

    var icon: String {
        switch self {
        case .generic: return "number.circle.fill"
        case .whatsForDinner: return "fork.knife.circle.fill"
        case .phase10: return "10.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .generic: return ClubhouseTheme.felt
        case .whatsForDinner: return PlayerColors.palette[4]
        case .phase10: return PlayerColors.palette[3]
        }
    }

    var defaultWinCondition: WinCondition {
        switch self {
        case .generic: return .highestScore
        case .whatsForDinner: return .lowestScore
        case .phase10: return .lowestScore
        }
    }

    var minPlayers: Int { 2 }
    var maxPlayers: Int { 15 }
}

/// Shared parsing and validation for the optional target-score field.
/// Empty input intentionally means that the game is completed manually.
enum TargetScoreConfiguration {
    static func validationMessage(for rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        guard let score = Int(value), score > 0 else {
            return "Enter a whole number greater than zero, or leave it blank."
        }
        return nil
    }

    static func value(from rawValue: String) -> Int? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let score = Int(value), score > 0 else { return nil }
        return score
    }
}
