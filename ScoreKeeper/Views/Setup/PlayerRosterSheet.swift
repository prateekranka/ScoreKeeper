import SwiftUI
import SwiftData

struct PlayerRosterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayer.gamesPlayed, order: .reverse) private var savedPlayers: [SavedPlayer]
    var onSelect: ([String]) -> Void

    @State private var selectedNames: Set<String> = []
    @State private var pendingDeleteName: String?
    @State private var showDeleteConfirmation = false
    @State private var saveError: String?

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
                                rosterRow(player)
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
            .confirmationDialog(
                "Delete saved player?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(pendingDeleteName ?? "player")", role: .destructive) {
                    deletePendingPlayer()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the name from your saved roster. Existing games are unchanged.")
            }
            .alert(
                "Couldn’t update saved roster",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func rosterRow(_ player: SavedPlayer) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Button {
                if selectedNames.contains(player.name) {
                    selectedNames.remove(player.name)
                } else {
                    selectedNames.insert(player.name)
                }
            } label: {
                VStack(spacing: AppTheme.spacingSmall) {
                    PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small)
                    Text("\(player.gamesPlayed) games")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
                .padding(AppTheme.spacingSmall)
                .frame(maxWidth: .infinity)
                .background(
                    selectedNames.contains(player.name)
                        ? PlayerColors.lightColor(for: player.colorIndex)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                )
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("\(player.name), \(player.gamesPlayed) games played")
            .accessibilityValue(selectedNames.contains(player.name) ? "Selected" : "Not selected")
            .accessibilityIdentifier("roster_player_\(player.name)")

            Button(role: .destructive) {
                pendingDeleteName = player.name
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Delete \(player.name) from saved roster")
            .accessibilityIdentifier("delete_roster_player_\(player.name)")
        }
    }

    private func deletePendingPlayer() {
        guard let pendingDeleteName,
              let player = savedPlayers.first(where: { $0.name == pendingDeleteName }) else {
            return
        }

        selectedNames.remove(pendingDeleteName)
        modelContext.delete(player)

        do {
            try modelContext.save()
            self.pendingDeleteName = nil
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            selectedNames.insert(pendingDeleteName)
            saveError = message
        }
    }
}
