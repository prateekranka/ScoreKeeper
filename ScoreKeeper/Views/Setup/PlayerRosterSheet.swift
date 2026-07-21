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
                    BauhausEmptyState(
                        title: "No Saved Players",
                        message: "Play a game to save player names to your roster.",
                        systemImage: "person.2",
                        heroStyle: .players
                    )
                    .padding(AppTheme.spacingMedium)
                } else {
                    List {
                        ForEach(savedPlayers) { player in
                            rosterRow(player)
                                .listRowInsets(EdgeInsets(
                                    top: AppTheme.spacingSmall,
                                    leading: AppTheme.spacingMedium,
                                    bottom: AppTheme.spacingSmall,
                                    trailing: AppTheme.spacingMedium
                                ))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        pendingDeleteName = player.name
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .accessibilityIdentifier("delete_roster_player_\(player.name)")
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
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
                    .foregroundStyle(selectedNames.isEmpty ? ClubhouseTheme.inkMuted : ClubhouseTheme.bauhausBlue)
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
        let isSelected = selectedNames.contains(player.name)

        return Button {
            if isSelected {
                selectedNames.remove(player.name)
            } else {
                selectedNames.insert(player.name)
            }
        } label: {
            HStack(spacing: AppTheme.spacingSmall) {
                PlayerShapeIcon(colorIndex: player.colorIndex, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(AppFonts.body.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text(player.gamesPlayed.quantityText("game"))
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                if isSelected {
                    StatusPill(kind: .custom("Selected", ClubhouseTheme.bauhausBlue))
                } else {
                    Circle()
                        .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(AppTheme.spacingSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(
                        isSelected ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.panelBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: ClubhouseTheme.paperShadow, radius: isSelected ? 10 : 4, y: isSelected ? 3 : 1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(player.name), \(player.gamesPlayed.quantityText("game")) played")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("roster_player_\(player.name)")
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
