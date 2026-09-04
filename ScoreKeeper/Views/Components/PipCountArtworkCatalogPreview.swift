#if DEBUG
import SwiftUI

struct PipCountArtworkCatalogPreview: View {
    private let assets: [(String, PipCountIllustrationAsset)] = [
        ("Hero", .hero),
        ("Empty state", .emptyState),
        ("Score", .scoreEmblem),
        ("Crew", .crewEmblem),
        ("Unlimited", .unlimitedEmblem),
        ("Celebration", .celebrationEmblem)
    ]

    private let scenes: [(String, PipCountArtworkScene)] = [
        ("Home", .home),
        ("Home empty", .homeEmpty),
        ("Game picker", .gamePicker),
        ("Player setup", .playerSetup),
        ("Game settings", .gameSettings),
        ("Handwriting", .handwriting),
        ("Scoring", .scoring),
        ("Game over", .gameOver),
        ("Paywall", .paywall),
        ("Onboarding score", .onboardingScore),
        ("Onboarding setup", .onboardingSetup),
        ("Onboarding history", .onboardingHistory),
        ("Roster", .roster)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    previewSection(title: "Vector assets") {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(assets, id: \.0) { item in
                                previewCard(title: item.0) {
                                    PipCountAssetArtwork(asset: item.1)
                                        .frame(height: 150)
                                }
                            }
                        }
                    }

                    previewSection(title: "Screen routing") {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(scenes, id: \.0) { item in
                                previewCard(title: item.0) {
                                    PipCountGeometricArtwork(scene: item.1)
                                        .frame(height: 150)
                                }
                            }
                        }
                    }

                    previewSection(title: "Player pieces") {
                        HStack(spacing: 24) {
                            ForEach(0..<8, id: \.self) { index in
                                VStack(spacing: 8) {
                                    BauhausPlayerShape(colorIndex: index, size: 44)
                                    Text("\(index + 1)")
                                        .font(AppFonts.caption)
                                        .foregroundStyle(ClubhouseTheme.inkMuted)
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                    }
                }
                .padding(24)
            }
            .appBackground()
            .navigationTitle("pipcount artwork")
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 16)]
    }

    private func previewSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)
            content()
        }
    }

    private func previewCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
                .frame(maxWidth: .infinity)
            Text(title)
                .font(AppFonts.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(14)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

#Preview("Artwork catalogue") {
    PipCountArtworkCatalogPreview()
}
#endif
