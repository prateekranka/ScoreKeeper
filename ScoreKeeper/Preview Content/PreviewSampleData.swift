import SwiftData
import Foundation

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: GameSession.self, Player.self, Round.self, ScoreEntry.self,
        configurations: config
    )

    // Sample completed game
    let session = GameSession(gameType: .generic)
    session.isComplete = true
    session.completedAt = Date().addingTimeInterval(-86400)
    container.mainContext.insert(session)

    let player1 = Player(name: "Alice", colorIndex: 0)
    player1.session = session
    session.players.append(player1)

    let player2 = Player(name: "Bob", colorIndex: 1)
    player2.session = session
    session.players.append(player2)

    let round1 = Round(roundNumber: 1)
    round1.session = session
    session.rounds.append(round1)

    let entry1 = ScoreEntry(playerID: player1.id, points: 25)
    entry1.round = round1
    round1.entries.append(entry1)

    let entry2 = ScoreEntry(playerID: player2.id, points: 30)
    entry2.round = round1
    round1.entries.append(entry2)

    session.winnerID = player2.id

    return container
}()
