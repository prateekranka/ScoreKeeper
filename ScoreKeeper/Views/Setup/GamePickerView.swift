import SwiftUI

struct GamePickerView: View {
    @Environment(NavigationRouter.self) private var router
    @State private var sectionsVisible = false
    @State private var selectedGameType: GameType = .generic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                BauhausScreenHeader(
                    title: "Choose a Game",
                    subtitle: "Pick your format for tonight.",
                    heroStyle: .chooseGame
                )
                .staggeredEntrance(visible: sectionsVisible, index: 0)

                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(Array(GameType.allCases.enumerated()), id: \.element.id) { index, gameType in
                        GamePickerOptionCard(
                            gameType: gameType,
                            isSelected: selectedGameType == gameType,
                            action: {
                                selectedGameType = gameType
                                router.push(.playerSetup(gameType))
                            }
                        )
                        .accessibilityIdentifier("game_tile_\(gameType.rawValue)")
                        .staggeredEntrance(visible: sectionsVisible, index: index + 1)
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .padding(.bottom, 88)
        }
        .appBackground()
        .navigationTitle("Games")
        .safeAreaInset(edge: .bottom) {
            BauhausPrimaryButton(
                title: "Continue",
                systemImage: "arrow.right",
                fill: ClubhouseTheme.bauhausBlue,
                action: { router.push(.playerSetup(selectedGameType)) }
            )
            .accessibilityIdentifier("game_picker_continue_button")
            .padding(.vertical, AppTheme.spacingSmall)
            .padding(.horizontal, AppTheme.spacingSmall)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingSmall)
        }
        .onAppear {
            sectionsVisible = true
        }
    }
}

private struct GamePickerOptionCard: View {
    let gameType: GameType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingMedium) {
                GameTypeArtwork(gameType: gameType)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .multilineTextAlignment(.leading)

                    Text(gameType.subtitle)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                RadioIndicator(isSelected: isSelected)
            }
            .padding(AppTheme.spacingMedium)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(
                        isSelected ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.rule,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(gameType.displayName). \(gameType.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RadioIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.rule,
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(ClubhouseTheme.bauhausBlue)
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityHidden(true)
    }
}
