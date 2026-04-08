import Foundation
import SwiftData

@Model
final class ScoreEntry {
    var id: UUID = UUID()
    var playerID: UUID = UUID()
    var points: Int = 0
    var metadata: String?
    var round: Round?

    init(playerID: UUID, points: Int, metadata: String? = nil) {
        self.id = UUID()
        self.playerID = playerID
        self.points = points
        self.metadata = metadata
    }
}

// MARK: - Phase 10 Metadata

struct Phase10Metadata: Codable {
    var phaseCompleted: Int // 0 means no phase completed this round
    var leftoverPoints: Int
}

extension ScoreEntry {
    var phase10Metadata: Phase10Metadata? {
        get {
            guard let metadata, let data = metadata.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Phase10Metadata.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                metadata = nil
                return
            }
            metadata = String(data: data, encoding: .utf8)
        }
    }
}
