import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)?

    @State private var isCompleting = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    unlockSummary
                    benefitsPanel
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.bottom, AppTheme.spacingLarge)
            }

            purchaseFooter
        }
        .appBackground()
        .sensoryFeedback(.success, trigger: storeManager.isUnlocked)
        .onAppear {
            storeManager.paywallPresentedThisSession = true
            Task { await storeManager.loadProduct() }
        }
        .onChange(of: storeManager.isUnlocked) { _, isUnlocked in
            if isUnlocked {
                completeUnlockFlow()
            }
        }
    }

    private var sheetHeader: some View {
        ReleaseSheetHeader(
            title: "PipCount Pro",
            subtitle: "One unlock. Every game night.",
            systemImage: "trophy.fill",
            titleIdentifier: "paywall_title"
        ) {
            closeButton
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
    }

    private var unlockSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingSmall) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LIFETIME UNLOCK")
                        .columnHeaderStyle()

                    Text(storeManager.displayPrice)
                        .font(AppFonts.scoreDisplay)
                        .monospacedDigit()
                        .foregroundStyle(ClubhouseTheme.ink)
                        .accessibilityLabel("\(storeManager.displayPrice), one-time purchase")
                }

                Spacer()

                Label("ONE-TIME", systemImage: "checkmark.circle.fill")
                    .font(AppFonts.columnHeader)
                    .foregroundStyle(ClubhouseTheme.feltDeep)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(ClubhouseTheme.felt.opacity(0.10), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(ClubhouseTheme.felt.opacity(0.24), lineWidth: 1)
                    }
            }

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            Text("Your first 25 games are free. Pro removes the game limit permanently.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var benefitsPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            AppSectionHeader(
                title: "What Pro unlocks",
                subtitle: "The same PipCount, with no game limit.",
                systemImage: "checkmark.seal.fill"
            )

            VStack(spacing: 0) {
                benefitRow(
                    systemImage: "infinity",
                    title: "Unlimited scorecards",
                    detail: "Start as many games as your table can handle"
                )
                divider
                benefitRow(
                    systemImage: "creditcard.fill",
                    title: "Pay once",
                    detail: "No subscription, renewal, or recurring charge"
                )
                divider
                benefitRow(
                    systemImage: "dice.fill",
                    title: "Every game mode",
                    detail: "Scoreboard, Ten Phases, and What's for Dinner"
                )
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var divider: some View {
        Rectangle()
            .fill(ClubhouseTheme.rule)
            .frame(height: 1)
            .padding(.leading, 44)
    }

    private var purchaseFooter: some View {
        glassGroup(spacing: AppTheme.spacingSmall) {
            VStack(spacing: AppTheme.spacingSmall) {
                statusText

                AppActionButton(role: .primary(ClubhouseTheme.felt)) {
                    Task {
                        if await storeManager.purchase() {
                            completeUnlockFlow()
                        }
                    }
                } label: {
                    purchaseButtonLabel
                }
                .accessibilityIdentifier("paywall_unlock_button")
                .disabled(isPurchaseButtonDisabled)

                Button("Restore purchase") {
                    Task {
                        if await storeManager.restore() {
                            completeUnlockFlow()
                        }
                    }
                }
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(minHeight: 44)
                .accessibilityIdentifier("paywall_restore_button")
                .disabled(isRestoreButtonDisabled)
            }
            .padding(AppTheme.spacingSmall)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.bottom, AppTheme.spacingSmall)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(width: 44, height: 44)
                .appGlass(cornerRadius: 22, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Close")
        .accessibilityIdentifier("paywall_close_button")
    }

    @ViewBuilder
    private var statusText: some View {
        switch storeManager.productState {
        case .unavailable(let message):
            VStack(spacing: AppTheme.spacingSmall) {
                Text(message)
                    .statusStyle(color: ClubhouseTheme.lacquer)

                Button("Retry loading purchase details") {
                    Task { await storeManager.retryProductLoad() }
                }
                .font(AppFonts.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(minHeight: 44)
                .accessibilityIdentifier("paywall_retry_button")
            }
        case .notLoaded, .loading, .loaded:
            switch storeManager.purchaseState {
            case .idle:
                EmptyView()
            case .loading:
                Text("Loading purchase details...")
                    .statusStyle()
            case .purchasing:
                Text("Unlocking PipCount Pro...")
                    .statusStyle()
            case .restoring:
                Text("Checking past purchases...")
                    .statusStyle()
            case .success:
                Text("Unlocked. Starting your game...")
                    .statusStyle(color: ClubhouseTheme.felt)
            case .failed(let message):
                Text(message)
                    .statusStyle(color: ClubhouseTheme.lacquer)
            }
        }
    }

    @ViewBuilder
    private var purchaseButtonLabel: some View {
        switch storeManager.productState {
        case .unavailable:
            Label("Unlock unavailable", systemImage: "exclamationmark.triangle")
        case .notLoaded, .loading, .loaded:
            switch storeManager.purchaseState {
            case .loading, .purchasing, .restoring:
                HStack(spacing: AppTheme.spacingSmall) {
                    ProgressView()
                        .tint(ClubhouseTheme.onFelt)
                    Text("Please wait")
                }
            case .success:
                Label("Pro unlocked", systemImage: "checkmark.seal.fill")
            case .idle, .failed:
                if storeManager.product == nil {
                    Label("Unlock unavailable", systemImage: "exclamationmark.triangle")
                } else {
                    Label("Unlock Pro — \(storeManager.displayPrice)", systemImage: "checkmark.seal.fill")
                }
            }
        }
    }

    private var isPurchaseButtonDisabled: Bool {
        !storeManager.canPurchase || isCompleting
    }

    private var isRestoreButtonDisabled: Bool {
        if isCompleting { return true }

        switch storeManager.purchaseState {
        case .purchasing, .restoring:
            return true
        case .loading, .idle, .success, .failed:
            return false
        }
    }

    private func benefitRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.felt)
                .frame(width: 36, height: 36)
                .background(ClubhouseTheme.felt.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(detail)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.spacingSmall)
        .accessibilityElement(children: .combine)
    }

    private func completeUnlockFlow() {
        guard storeManager.isUnlocked, !isCompleting else { return }

        isCompleting = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            dismiss()
            onUnlocked?()
        }
    }
}

private extension Text {
    func statusStyle(color: Color = ClubhouseTheme.inkMuted) -> some View {
        self
            .font(AppFonts.caption)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }
}
