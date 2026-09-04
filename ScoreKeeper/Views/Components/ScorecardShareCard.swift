import SwiftUI
import UIKit

/// Fixed-layout scorecard rendered to a shareable image.
///
/// Game-over recap and game-detail screens share this card instead of plain
/// text, so the recipient sees the final scoreboard as a picture. Layout and
/// type are fixed (not dynamic-type or dark-mode driven) so the image reads
/// the same way in every share destination; the card forces the light scheme.
struct ScorecardShareCard: View {
    let session: GameSession
    let engine: GameEngine

    private let cardWidth: CGFloat = 360

    var body: some View {
        ZStack(alignment: .top) {
            ClubhouseTheme.paper

            VStack(alignment: .leading, spacing: 0) {
                header

                Text(session.gameType.displayName)
                    .font(Font.system(size: 32, weight: .black))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .padding(.top, 16)

                Text(resultLine)
                    .font(Font.system(size: 21, weight: .bold))
                    .foregroundStyle(ClubhouseTheme.blue)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 5)

                Rectangle()
                    .fill(ClubhouseTheme.green)
                    .frame(width: 88, height: 5)
                    .padding(.top, 14)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("final scores")
                        .font(Font.system(size: 16, weight: .bold))
                        .foregroundStyle(ClubhouseTheme.ink)

                    Spacer()

                    Text(session.winCondition == .lowestScore ? "lowest score wins" : "highest score wins")
                        .font(Font.system(size: 12))
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
                .padding(.top, 24)
                .padding(.bottom, 10)

                if standings.isEmpty {
                    Text("no scores recorded")
                        .font(Font.system(size: 14))
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .padding(.vertical, 14)
                } else {
                    ForEach(standings) { standing in
                        standingRow(standing)
                    }
                }

                Rectangle()
                    .fill(ClubhouseTheme.rule)
                    .frame(height: 1)
                    .padding(.top, 16)

                Text(roundsLine)
                    .font(Font.system(size: 13))
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .padding(.top, 12)
            }
            .padding(22)
            .background(
                ClubhouseTheme.paperCard,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ruleStrong.opacity(0.45), lineWidth: 1)
            }
            .padding(18)
        }
        .frame(width: cardWidth)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("pipcount")
                .font(Font.system(size: 15, weight: .bold))
                .foregroundStyle(ClubhouseTheme.ink)

            Spacer()

            Text(dateLine)
                .font(Font.system(size: 13))
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
    }

    private func standingRow(_ standing: PlayerStanding) -> some View {
        HStack(spacing: 10) {
            Text("\(standing.rank)")
                .font(Font.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(width: 20, alignment: .leading)

            Rectangle()
                .fill(PlayerColors.color(for: standing.player.colorIndex))
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))

            Text(standing.player.name)
                .font(Font.system(size: 14, weight: standing.isWinner ? .bold : .semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            Text("\(standing.score)")
                .font(Font.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(standing.isWinner ? ClubhouseTheme.brass : ClubhouseTheme.ink)
                .frame(minWidth: 42, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background {
            if standing.isWinner {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ClubhouseTheme.yellow.opacity(0.10))
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule.opacity(0.8))
                .frame(height: 0.75)
        }
    }

    private var standings: [PlayerStanding] {
        session.standings(using: engine)
    }

    private var resultLine: String {
        let winners = engine.winners(session: session)
        let names = session.players.filter { winners.contains($0.id) }.map(\.name)

        if names.count == 1 {
            return "\(names[0]) won"
        }
        if names.count > 1 {
            return "tie: \(names.joined(separator: " & "))"
        }
        return "no winner"
    }

    private var dateLine: String {
        (session.completedAt ?? session.createdAt).shortDateString
    }

    private var roundsLine: String {
        "\(session.sortedRounds.count.quantityText("round")) played"
    }

    /// Renders the card into a shareable image (3x for crisp results).
    static func shareImage(session: GameSession, engine: GameEngine) -> Image? {
        let renderer = ImageRenderer(content: ScorecardShareCard(session: session, engine: engine))
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(uiImage: UIImage(cgImage: cgImage))
    }
}
