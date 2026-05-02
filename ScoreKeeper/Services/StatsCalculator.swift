import Foundation

@MainActor
enum StatsCalculator {

    static func stats(for name: String, sessions: [GameSession]) -> PlayerStats {
        let relevant = sessions.filter { session in
            session.players.contains { $0.name == name }
        }
        let wins = relevant.filter { session in
            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = engine.winners(session: session)
            return session.players.contains { $0.name == name && winnerIDs.contains($0.id) }
        }.count

        var totalScoreSum = 0
        var scoreEntryCount = 0
        var bestRank = Int.max
        for session in relevant {
            let engine = GameEngineFactory.engine(for: session.gameType)
            let sorted = session.players.sorted { p1, p2 in
                let s1 = engine.totalScore(for: session.rounds.flatMap(\.entries).filter { $0.playerID == p1.id })
                let s2 = engine.totalScore(for: session.rounds.flatMap(\.entries).filter { $0.playerID == p2.id })
                return session.winCondition == .lowestScore ? s1 < s2 : s1 > s2
            }
            if let rank = sorted.firstIndex(where: { $0.name == name }) {
                bestRank = min(bestRank, rank + 1)
            }
            if let player = session.players.first(where: { $0.name == name }) {
                let entries = session.rounds.flatMap(\.entries).filter { $0.playerID == player.id }
                totalScoreSum += entries.reduce(0) { $0 + $1.points }
                scoreEntryCount += entries.count
            }
        }

        let avgScore = scoreEntryCount > 0 ? Double(totalScoreSum) / Double(scoreEntryCount) : 0

        return PlayerStats(
            name: name,
            gamesPlayed: relevant.count,
            wins: wins,
            bestRank: bestRank == Int.max ? 0 : bestRank,
            avgScore: avgScore
        )
    }

    static func headToHead(_ a: String, vs b: String, sessions: [GameSession], gameType: GameType? = nil) -> H2HRecord {
        let together = sessions.filter { session in
            let names = session.players.map(\.name)
            let matchesType = gameType.map { session.gameType == $0 } ?? true
            return matchesType && names.contains(a) && names.contains(b)
        }
        let aWins = together.filter { session in
            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = engine.winners(session: session)
            return session.players.contains { $0.name == a && winnerIDs.contains($0.id) }
        }.count
        let bWins = together.filter { session in
            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = engine.winners(session: session)
            return session.players.contains { $0.name == b && winnerIDs.contains($0.id) }
        }.count

        return H2HRecord(playerA: a, playerB: b, gameType: gameType, aWins: aWins, bWins: bWins, gamesTogether: together.count)
    }

    static func headToHeadByGameType(_ a: String, vs b: String, sessions: [GameSession]) -> [H2HRecord] {
        GameType.allCases.compactMap { gameType in
            let record = headToHead(a, vs: b, sessions: sessions, gameType: gameType)
            return record.gamesTogether > 0 ? record : nil
        }
    }

    static func gamesBetween(_ a: String, and b: String, gameType: GameType, sessions: [GameSession]) -> [GameSession] {
        sessions.filter { session in
            let names = session.players.map(\.name)
            return session.gameType == gameType && names.contains(a) && names.contains(b)
        }
    }

    static func allPlayerNames(from sessions: [GameSession]) -> [String] {
        Array(Set(sessions.flatMap { $0.players.map(\.name) })).sorted()
    }
}
