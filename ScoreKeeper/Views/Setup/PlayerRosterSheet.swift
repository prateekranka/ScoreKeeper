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
                        "no saved players",
                        systemImage: "person.slash",
                        description: Text("play a game to save player names to your roster")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(savedPlayers) { player in
                                rosterRow(player)
                            }
                        }
                        .padding(.horizontal, AppTheme.spacingMedium)
                    }
                }
            }
            .navigationTitle("select players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("add (\(selectedNames.count))") {
                        onSelect(Array(selectedNames))
                        dismiss()
                    }
                    .disabled(selectedNames.isEmpty)
                }
            }
            .confirmationDialog(
                "delete saved player?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("delete \(pendingDeleteName ?? "player")", role: .destructive) {
                    deletePendingPlayer()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("this removes the name from your saved roster. existing games are unchanged")
            }
            .alert(
                "couldn’t update saved roster",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("ok", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "please try again")
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
                HStack(spacing: AppTheme.spacingSmall) {
                    PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small, showName: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(AppFonts.body.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(1)
                        Text("\(player.gamesPlayed) games")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selectedNames.contains(player.name) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedNames.contains(player.name) ? ClubhouseTheme.blue : ClubhouseTheme.inkMuted)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(
                    selectedNames.contains(player.name)
                        ? PlayerColors.lightColor(for: player.colorIndex).opacity(0.35)
                        : Color.clear
                )
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
                }
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
