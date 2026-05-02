import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void
    var accessibilityID: String? = nil

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingSmall) {
                GameTypeArtwork(gameType: gameType)
                    .frame(height: 64)

                Text(gameType.displayName)
                    .font(AppFonts.headline)
                    .foregroundStyle(.white)

                Text(gameType.subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 144)
            .padding(.vertical, AppTheme.spacingLarge)
            .padding(.horizontal, AppTheme.spacingMedium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [gameType.color, gameType.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: gameType.color.opacity(0.3), radius: 8, y: 4)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
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
                .fill(.white.opacity(0.18))
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 58, height: 58)
                        .offset(x: -18, y: -22)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(.black.opacity(0.12))
                        .frame(width: 72, height: 72)
                        .offset(x: 22, y: 26)
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
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.18), in: Circle())
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
            .foregroundStyle(.white)
        case .phase10:
            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { phase in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(phase <= 4 ? .white : .white.opacity(0.35))
                        .frame(width: 8, height: CGFloat(18 + phase * 2))
                }
            }
            .overlay {
                Text("10")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(gameType.color)
                    .padding(8)
                    .background(.white, in: Circle())
            }
        }
    }
}
