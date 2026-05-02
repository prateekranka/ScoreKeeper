import Foundation

struct PlayerStats {
    let name: String
    let gamesPlayed: Int
    let wins: Int
    let bestRank: Int
    let avgScore: Double
    var winRate: Double { gamesPlayed > 0 ? Double(wins) / Double(gamesPlayed) : 0 }
}

struct H2HRecord {
    let playerA: String
    let playerB: String
    let gameType: GameType?
    let aWins: Int
    let bWins: Int
    let gamesTogether: Int
    var id: String { gameType?.rawValue ?? "all" }
    var aWinRate: Double { gamesTogether > 0 ? Double(aWins) / Double(gamesTogether) : 0 }
    var bWinRate: Double { gamesTogether > 0 ? Double(bWins) / Double(gamesTogether) : 0 }
}
