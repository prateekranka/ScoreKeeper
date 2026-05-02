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
        case .phase10: return "Phase 10"
        }
    }

    var subtitle: String {
        switch self {
        case .generic: return "Track any game"
        case .whatsForDinner: return "Lowest hand wins"
        case .phase10: return "Complete all 10 phases"
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
        case .generic: return Color(red: 0.58, green: 0.65, blue: 0.71)
        case .whatsForDinner: return Color(red: 0.91, green: 0.12, blue: 0.55)
        case .phase10: return Color(red: 0.20, green: 0.60, blue: 0.86)
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
