import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: gameType.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text(gameType.displayName)
                    .font(AppFonts.headline)
                    .foregroundStyle(.white)

                Text(gameType.subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
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
        }
        .buttonStyle(.plain)
    }
}
