import SwiftUI
import SwiftData

struct PlayerRosterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedPlayer.gamesPlayed, order: .reverse) private var savedPlayers: [SavedPlayer]
    var onSelect: ([String]) -> Void

    @State private var selectedNames: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if savedPlayers.isEmpty {
                    ContentUnavailableView(
                        "No Saved Players",
                        systemImage: "person.slash",
                        description: Text("Play a game to save player names to your roster.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: AppTheme.spacingSmall) {
                            ForEach(savedPlayers) { player in
                                rosterChip(player)
                            }
                        }
                        .padding(AppTheme.spacingMedium)
                    }
                }
            }
            .navigationTitle("Select Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedNames.count))") {
                        onSelect(Array(selectedNames))
                        dismiss()
                    }
                    .disabled(selectedNames.isEmpty)
                }
            }
        }
    }

    private func rosterChip(_ player: SavedPlayer) -> some View {
        Button {
            if selectedNames.contains(player.name) {
                selectedNames.remove(player.name)
            } else {
                selectedNames.insert(player.name)
            }
        } label: {
            VStack(spacing: AppTheme.spacingSmall) {
                PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .medium)
                Text("\(player.gamesPlayed) games")
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.spacingSmall)
            .frame(maxWidth: .infinity)
            .background(
                selectedNames.contains(player.name)
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            )
            .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(player.name), \(player.gamesPlayed) games played")
        .accessibilityValue(selectedNames.contains(player.name) ? "Selected" : "Not selected")
        .accessibilityIdentifier("roster_player_\(player.name)")
    }
}
