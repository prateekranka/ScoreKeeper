import SwiftUI

struct GamePickerView: View {
    @Environment(NavigationRouter.self) private var router
    @State private var sectionsVisible = false

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.spacingMedium),
        GridItem(.flexible(), spacing: AppTheme.spacingMedium)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                GamePickerHero()
                    .staggeredEntrance(visible: sectionsVisible, index: 0)

                LazyVGrid(columns: columns, spacing: AppTheme.spacingMedium) {
                    ForEach(Array(GameType.allCases.enumerated()), id: \.element.id) { index, gameType in
                        GameTypeTile(gameType: gameType, action: {
                            router.push(.playerSetup(gameType))
                        }, accessibilityID: "game_tile_\(gameType.rawValue)")
                        .staggeredEntrance(visible: sectionsVisible, index: index + 1)
                    }
                }

                SmartSetupPreview()
                    .staggeredEntrance(visible: sectionsVisible, index: GameType.allCases.count + 1)
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Games")
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                sectionsVisible = true
            }
        }
    }
}

private struct GamePickerHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            AppSectionHeader(
                title: "Choose a Game",
                subtitle: "Pick a rule set, then ScoreKeeper will shape the score sheet.",
                systemImage: "dice"
            )

            HStack(spacing: AppTheme.spacingSmall) {
                SetupFeatureChip(title: "Smart defaults", systemImage: "wand.and.stars", tint: PlayerColors.palette[2])
                SetupFeatureChip(title: "Saved crews", systemImage: "person.2.fill", tint: PlayerColors.palette[1])
                SetupFeatureChip(title: "Fast rematch", systemImage: "arrow.counterclockwise", tint: PlayerColors.palette[0])
            }
        }
        .padding(AppTheme.spacingMedium)
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

private struct SetupFeatureChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(AppFonts.caption)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .padding(.horizontal, 4)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct SmartSetupPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(
                title: "What gets set up",
                subtitle: "Each mode keeps only the choices that matter.",
                systemImage: "checklist"
            )

            FeatureRow(systemImage: "plus.forwardslash.minus", title: "Scoreboard", detail: "Highest or lowest score, target score, any game")
            FeatureRow(systemImage: "10.circle.fill", title: "Phase 10", detail: "Phase progress, leftover points, completion toggles")
            FeatureRow(systemImage: "fork.knife.circle.fill", title: "Dinner", detail: "Caller, card values, lowest total wins")
        }
        .padding(AppTheme.spacingMedium)
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .foregroundStyle(PlayerColors.palette[3])
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body)
                Text(detail)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}
