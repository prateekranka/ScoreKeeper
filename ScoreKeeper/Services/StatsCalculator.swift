import Foundation

@MainActor
enum StatsCalculator {

    static func stats(for name: String, sessions: [GameSession]) -> PlayerStats {
        var gamesPlayed = 0
        var wins = 0
        var totalScoreSum = 0
        var scoreEntryCount = 0
        var bestRank = Int.max

        for session in sessions {
            // One player-identity rule everywhere: names match
            // case-insensitively, the same way recent-game lists already match
            // legacy mixed-case history (PC17-013).
            let matchingPlayers = session.players.filter { $0.name.matchesPlayerName(name) }
            guard let player = matchingPlayers.first else { continue }

            gamesPlayed += 1

            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = Set(engine.winners(session: session))
            if matchingPlayers.contains(where: { winnerIDs.contains($0.id) }) {
                wins += 1
            }

            // One pass over this session's entries; totals and ranks come
            // from it instead of re-flattening entries inside sort comparators.
            let entries = session.rounds.flatMap(\.entries)
            let playerEntries = entries.filter { $0.playerID == player.id }
            totalScoreSum += playerEntries.reduce(0) { $0 + $1.points }
            scoreEntryCount += playerEntries.count

            bestRank = min(bestRank, engine.rank(of: player, in: session))
        }

        let avgScore = scoreEntryCount > 0 ? Double(totalScoreSum) / Double(scoreEntryCount) : 0

        return PlayerStats(
            name: name,
            gamesPlayed: gamesPlayed,
            wins: wins,
            bestRank: bestRank == Int.max ? 0 : bestRank,
            avgScore: avgScore
        )
    }

    static func headToHead(_ a: String, vs b: String, sessions: [GameSession], gameType: GameType? = nil) -> H2HRecord {
        var aWins = 0
        var bWins = 0
        var gamesTogether = 0

        for session in sessions {
            if let gameType, session.gameType != gameType { continue }

            let players = session.players
            guard players.contains(where: { $0.name.matchesPlayerName(a) }),
                  players.contains(where: { $0.name.matchesPlayerName(b) }) else {
                continue
            }
            gamesTogether += 1

            let winnerIDs = Set(GameEngineFactory.engine(for: session.gameType).winners(session: session))
            if players.contains(where: { $0.name.matchesPlayerName(a) && winnerIDs.contains($0.id) }) {
                aWins += 1
            }
            if players.contains(where: { $0.name.matchesPlayerName(b) && winnerIDs.contains($0.id) }) {
                bWins += 1
            }
        }

        return H2HRecord(playerA: a, playerB: b, gameType: gameType, aWins: aWins, bWins: bWins, gamesTogether: gamesTogether)
    }

    static func headToHeadByGameType(_ a: String, vs b: String, sessions: [GameSession]) -> [H2HRecord] {
        GameType.allCases.compactMap { gameType in
            let record = headToHead(a, vs: b, sessions: sessions, gameType: gameType)
            return record.gamesTogether > 0 ? record : nil
        }
    }

    static func gamesBetween(_ a: String, and b: String, gameType: GameType, sessions: [GameSession]) -> [GameSession] {
        sessions.filter { session in
            session.gameType == gameType
                && session.players.contains { $0.name.matchesPlayerName(a) }
                && session.players.contains { $0.name.matchesPlayerName(b) }
        }
    }

    static func allPlayerNames(from sessions: [GameSession]) -> [String] {
        Array(Set(sessions.flatMap { $0.players.map(\.name) })).sorted()
    }
}

extension String {
    /// Player identity is name-based and case-insensitive, matching setup
    /// (which stores lowercase names) and the recent-game lists. Every stats
    /// query uses this one rule so legacy mixed-case history stays together.
    func matchesPlayerName(_ other: String) -> Bool {
        caseInsensitiveCompare(other) == .orderedSame
    }
}
