import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void
    var accessibilityID: String? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingMedium) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(gameType.displayName)
                        .font(AppFonts.tileTitle)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text(gameType.subtitle)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Circle()
                            .stroke(gameType.color, lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .fill(gameType.color)
                                    .frame(width: 12, height: 12)
                            }

                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                GameTypeArtwork(gameType: gameType)
                    .frame(width: 154, height: 142)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(ClubhouseTheme.paperCard)
                    .shadow(color: ClubhouseTheme.paperShadow, radius: 0, x: 3, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(gameType.color, lineWidth: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge - 4, style: .continuous)
                    .inset(by: 4)
                    .strokeBorder(ClubhouseTheme.rule, lineWidth: 0.75)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(accessibilityID ?? "")
        .accessibilityLabel("\(gameType.displayName). \(gameType.subtitle). \(gameType.minPlayers) to \(gameType.maxPlayers) players.")
    }
}

struct GameTypeArtwork: View {
    let gameType: GameType

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 150, proxy.size.height / 132)

            artwork
                .frame(width: 150, height: 132)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch gameType {
        case .generic:
            ZStack {
                Circle()
                    .fill(ClubhouseTheme.blue)
                    .frame(width: 108, height: 108)
                Circle()
                    .fill(ClubhouseTheme.yellow)
                    .frame(width: 76, height: 76)
                    .offset(x: 24, y: 22)
                Circle()
                    .fill(ClubhouseTheme.paperCard)
                    .frame(width: 46, height: 46)
                Rectangle()
                    .fill(ClubhouseTheme.ruleStrong)
                    .frame(width: 1, height: 132)
                Rectangle()
                    .fill(ClubhouseTheme.ruleStrong)
                    .frame(width: 132, height: 1)
            }
        case .phase10:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(ClubhouseTheme.yellow, lineWidth: 30)
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(ClubhouseTheme.green, lineWidth: 30)
                Circle()
                    .trim(from: 0.5, to: 0.75)
                    .stroke(ClubhouseTheme.blue, lineWidth: 30)
                Circle()
                    .trim(from: 0.75, to: 1)
                    .stroke(ClubhouseTheme.red, lineWidth: 30)
                Text("10")
                    .font(AppFonts.scoreMedium)
                    .foregroundStyle(ClubhouseTheme.ink)
            }
            .padding(22)
        case .whatsForDinner:
            ZStack {
                Circle()
                    .fill(ClubhouseTheme.blue)
                    .frame(width: 82, height: 82)
                    .offset(x: -18, y: -20)
                Circle()
                    .fill(ClubhouseTheme.yellow)
                    .frame(width: 92, height: 92)
                    .offset(x: -36, y: 38)
                Rectangle()
                    .fill(ClubhouseTheme.ink)
                    .frame(width: 96, height: 48)
                    .offset(x: 24, y: 37)
                TriangleShape()
                    .fill(ClubhouseTheme.green)
                    .frame(width: 44, height: 62)
                    .rotationEffect(.degrees(50))
                    .offset(x: 48, y: -24)
            }
        }
    }
}

private struct ScoreSheetArtwork: View {
    let gameType: GameType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(ClubhouseTheme.paperCard)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                }

            sheetContent
                .padding(7)
        }
        .frame(width: 62, height: 46)
    }

    @ViewBuilder
    private var sheetContent: some View {
        switch gameType {
        case .generic:
            VStack(spacing: 5) {
                ledgerLine(colorIndex: 0, score: "12")
                ledgerLine(colorIndex: 1, score: "7")
                ledgerLine(colorIndex: 2, score: "24")
            }
        case .whatsForDinner:
            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(gameType.color)
                VStack(spacing: 5) {
                    ledgerLine(colorIndex: 3, score: "3")
                    ledgerLine(colorIndex: 4, score: "9")
                }
            }
        case .phase10:
            VStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(row * 5 + column < 3 ? gameType.color : ClubhouseTheme.paperSunken)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 0.75)
                                }
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
    }

    private func ledgerLine(colorIndex: Int, score: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(PlayerColors.color(for: colorIndex))
                .frame(width: 5, height: 5)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            Text(score)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.ink)
        }
    }
}
