import SwiftUI

struct ScoreCard: View {
    let player: Player
    let totalScore: Int
    let isLeading: Bool

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .medium)

            Text("\(totalScore)")
                .font(AppFonts.scoreMedium)
                .monospacedDigit()
                .foregroundStyle(isLeading ? PlayerColors.color(for: player.colorIndex) : .primary)
                .contentTransition(.numericText())

            if isLeading {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(minWidth: 100)
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .strokeBorder(
                    isLeading ? PlayerColors.color(for: player.colorIndex).opacity(0.5) : .clear,
                    lineWidth: 2
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.name), total score \(totalScore)\(isLeading ? ", leading" : "")")
    }
}
