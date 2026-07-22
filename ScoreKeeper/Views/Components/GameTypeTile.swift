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
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(ClubhouseTheme.paperSunken)
                .overlay {
                    BauhausGridLines()
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                }

            artwork
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch gameType {
        case .generic:
            ScoreboardGeometricArt()
        case .phase10:
            Phase10GeometricArt()
        case .whatsForDinner:
            DinnerGeometricArt()
        }
    }
}

private struct ScoreboardGeometricArt: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ClubhouseTheme.bauhausBlue)
                .frame(width: 16, height: 26)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 16, height: 38)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ClubhouseTheme.bauhausRed)
                .frame(width: 16, height: 20)
        }
    }
}

private struct Phase10GeometricArt: View {
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { column in
                        let index = row * 5 + column
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(index < 4 ? ClubhouseTheme.bauhausRed : ClubhouseTheme.paperCard)
                            .overlay {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .strokeBorder(ClubhouseTheme.rule, lineWidth: 0.75)
                            }
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 10, height: 10)
                .offset(x: 6, y: -6)
        }
    }
}

private struct DinnerGeometricArt: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 30, height: 30)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(ClubhouseTheme.bauhausGreen)
                .frame(width: 18, height: 18)
                .offset(x: 12, y: 10)

            BauhausStar(color: ClubhouseTheme.bauhausRed)
                .frame(width: 12, height: 12)
                .offset(x: -14, y: -12)
        }
    }
}
