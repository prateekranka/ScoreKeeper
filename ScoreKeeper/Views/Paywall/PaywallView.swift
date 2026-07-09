import SwiftUI

struct PaywallView: View {
    var onCancel: () -> Void = {}
    var onUnlock: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreAccessManager.self) private var storeAccess
    @State private var didCompleteUnlock = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingLarge) {
                    PaywallHero()
                    PaywallBenefits()
                    purchaseSection
                }
                .padding(AppTheme.spacingMedium)
            }
            .appBackground()
            .navigationTitle("Unlimited Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(storeAccess.isPurchasing || storeAccess.isRestoring)
        .task {
            if storeAccess.hasUnlimitedAccess {
                completeUnlock()
            }
        }
        .onChange(of: storeAccess.hasUnlimitedAccess) { _, isUnlocked in
            if isUnlocked {
                completeUnlock()
            }
        }
    }

    private func completeUnlock() {
        guard !didCompleteUnlock else { return }
        didCompleteUnlock = true
        onUnlock()
        dismiss()
    }

    private var purchaseSection: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            AppActionButton(role: .primary(PlayerColors.palette[3])) {
                Task {
                    if await storeAccess.purchaseUnlimitedGames() {
                        completeUnlock()
                    }
                }
            } label: {
                if storeAccess.isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Completing purchase")
                } else if let price = storeAccess.displayPrice {
                    Text("Unlock Forever · \(price)")
                } else {
                    Text("Unlock Forever")
                }
            }
            .disabled(storeAccess.displayPrice == nil || storeAccess.isPurchasing || storeAccess.isRestoring)
            .accessibilityIdentifier("purchase_unlimited_button")

            Button {
                Task {
                    if await storeAccess.restorePurchases() {
                        completeUnlock()
                    }
                }
            } label: {
                if storeAccess.isRestoring {
                    ProgressView()
                        .accessibilityLabel("Restoring purchases")
                } else {
                    Text("Restore Purchases")
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(storeAccess.isPurchasing || storeAccess.isRestoring)
            .accessibilityIdentifier("restore_purchases_button")

            if let message = storeAccess.message {
                VStack(spacing: AppTheme.spacingSmall) {
                    Text(message)
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if storeAccess.product == nil, !storeAccess.isLoadingProduct {
                        Button("Try Again") {
                            Task { await storeAccess.retryLoadingProduct() }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }

            Text("One-time purchase. No subscription. Payment is charged to your Apple Account after confirmation.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, AppTheme.spacingMedium)
    }
}

private struct PaywallHero: View {
    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            ZStack {
                Circle()
                    .fill(PlayerColors.palette[2].opacity(0.22))
                    .frame(width: 132, height: 132)

                Image(systemName: "trophy.fill")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PlayerColors.palette[2])
                    .symbolEffect(.bounce, value: true)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppTheme.spacingSmall) {
                Text("Your first 25 games were on us")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Keep every scoreboard, Phase 10 night, and dinner reveal going with one small purchase.")
                    .font(AppFonts.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, AppTheme.spacingMedium)
    }
}

private struct PaywallBenefits: View {
    private let benefits = [
        PaywallBenefit(systemImage: "infinity", title: "Unlimited games", detail: "Start as many new games and rematches as you like."),
        PaywallBenefit(systemImage: "lock.shield.fill", title: "Private by design", detail: "Scores and history stay on your device."),
        PaywallBenefit(systemImage: "arrow.clockwise.icloud", title: "Restore anytime", detail: "Your purchase follows the Apple Account that bought it.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(benefits) { benefit in
                HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                    Image(systemName: benefit.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PlayerColors.palette[3])
                        .frame(width: 36, height: 36)
                        .background(PlayerColors.palette[3].opacity(0.13), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(AppFonts.headline)
                        Text(benefit.detail)
                            .font(AppFonts.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppTheme.spacingMedium)

                if benefit.id != benefits.last?.id {
                    Divider().padding(.leading, 68)
                }
            }
        }
        .appCard(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct PaywallBenefit: Identifiable {
    let systemImage: String
    let title: String
    let detail: String

    var id: String { title }
}
