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
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .multilineTextAlignment(.center)

                Text(gameType.subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 168)
            .padding(.vertical, AppTheme.spacingLarge)
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
            .shadow(color: ClubhouseTheme.paperShadow, radius: 10, y: 4)
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

            artwork
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch gameType {
        case .generic:
            HStack(spacing: 8) {
                ForEach(["#", "+", "-"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 24, weight: .heavy, design: .default))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .frame(width: 34, height: 34)
                        .background(ClubhouseTheme.paperCard, in: Circle())
                        .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                }
            }
        case .whatsForDinner:
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 30, weight: .bold))
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(index == 1 ? 0.95 : 0.55))
                            .frame(width: 42, height: 8)
                    }
                }
            }
            .foregroundStyle(gameType.color)
        case .phase10:
            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { phase in
                    Circle()
                        .fill(phase <= 4 ? ClubhouseTheme.felt : ClubhouseTheme.paperCard)
                        .frame(width: 11, height: 11)
                        .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                }
            }
            .overlay {
                Text("10")
                    .font(.system(size: 24, weight: .black, design: .default))
                    .foregroundStyle(gameType.color)
                    .padding(8)
                    .background(ClubhouseTheme.paperCard, in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
            }
        }
    }
}
