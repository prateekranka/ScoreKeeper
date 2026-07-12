import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void
    var accessibilityID: String? = nil

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingSmall) {
                GameTypeArtwork(gameType: gameType)
                    .frame(height: 58)

                Text(gameType.displayName)
                    .font(AppFonts.tileTitle)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(gameType.subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 144)
            .padding(.vertical, 12)
            .padding(.horizontal, AppTheme.spacingMedium)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(gameType.color, lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge - 4, style: .continuous)
                    .inset(by: 4)
                    .strokeBorder(ClubhouseTheme.rule, lineWidth: 0.5)
            }
            .shadow(color: ClubhouseTheme.paperShadow, radius: 5, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(accessibilityID ?? "")
        .accessibilityLabel("\(gameType.displayName). \(gameType.subtitle). \(gameType.minPlayers) to \(gameType.maxPlayers) players.")
    }
}

struct GameTypeArtwork: View {
    let gameType: GameType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(ClubhouseTheme.paperSunken)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                }

            GeometryReader { proxy in
                artwork
                    .scaleEffect(min(1, proxy.size.height / 58))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    private var artwork: some View {
        ScoreSheetArtwork(gameType: gameType)
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
                .font(Font.custom("VT323", size: 12))
                .foregroundStyle(ClubhouseTheme.ink)
        }
    }
}
