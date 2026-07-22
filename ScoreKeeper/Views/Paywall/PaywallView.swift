import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)?

    @State private var isCompleting = false
    #if DEBUG
    @ObservedObject private var tuning = PipTuning.shared
    #endif

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
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("PipCount")
                        .font(AppFonts.largeTitle)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .accessibilityIdentifier("paywall_title")
                    Text("Pro")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.bauhausRed)
                }

                Text("Unlock unlimited game night.")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("More games. More moments. Yours forever.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            Spacer(minLength: 0)

            ZStack(alignment: .topTrailing) {
                BauhausHeroArt(style: .home, height: 100)
                    #if DEBUG
                    .offset(x: tuning.paywallArtOffsetX, y: tuning.paywallArtOffsetY)
                    #endif
                closeButton
                    #if DEBUG
                    .offset(x: tuning.paywallCloseOffsetX, y: tuning.paywallCloseOffsetY)
                    #else
                    .offset(x: 4, y: -4)
                    #endif
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, AppTheme.spacingMedium)
    }

    private var unlockSummary: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("One-time purchase")
                    .columnHeaderStyle()

                Text(storeManager.displayPrice)
                    .font(AppFonts.scoreDisplay)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .accessibilityLabel("\(storeManager.displayPrice), one-time purchase")
            }

            Spacer(minLength: 0)

            StatusPill(kind: .custom("No subscription", ClubhouseTheme.bauhausGreen))
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var benefitsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            benefitRow(
                color: ClubhouseTheme.bauhausBlue,
                systemImage: "sparkle",
                title: "25 games free",
                detail: "Try before you upgrade."
            )
            divider
            benefitRow(
                color: ClubhouseTheme.bauhausRed,
                systemImage: "square.fill",
                title: "Then \(storeManager.displayPrice) one-time",
                detail: "Pay once. That’s it."
            )
            divider
            benefitRow(
                color: ClubhouseTheme.bauhausYellow,
                systemImage: "diamond.fill",
                title: "Unlimited games forever",
                detail: "All current and future games."
            )
            divider
            benefitRow(
                color: ClubhouseTheme.bauhausGreen,
                systemImage: "circle.grid.2x2.fill",
                title: "No subscription",
                detail: "No monthly fees. Ever."
            )
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var divider: some View {
        Rectangle()
            .fill(ClubhouseTheme.rule)
            .frame(height: 1)
            .padding(.leading, 48)
    }

    private var purchaseFooter: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            statusText

            BauhausPrimaryButton(
                title: purchaseButtonTitle,
                systemImage: purchaseSystemImage,
                fill: ClubhouseTheme.bauhausBlue,
                action: {
                    Task {
                        if await storeManager.purchase() {
                            completeUnlockFlow()
                        }
                    }
                }
            )
            .accessibilityIdentifier("paywall_unlock_button")
            .disabled(isPurchaseButtonDisabled)
            .opacity(isPurchaseButtonDisabled ? 0.55 : 1)

            Button("Restore purchase") {
                Task {
                    if await storeManager.restore() {
                        completeUnlockFlow()
                    }
                }
            }
            .font(AppFonts.body.weight(.semibold))
            .foregroundStyle(ClubhouseTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("paywall_restore_button")
            .disabled(isRestoreButtonDisabled)

            Label("Secure one-time purchase. Your progress is saved.", systemImage: "lock.fill")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, AppTheme.spacingMedium)
        .background(ClubhouseTheme.paper.opacity(0.96))
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(width: 40, height: 40)
                .background(ClubhouseTheme.paperCard, in: Circle())
                .overlay { Circle().strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1) }
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
                .foregroundStyle(ClubhouseTheme.bauhausBlue)
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
                    .statusStyle(color: ClubhouseTheme.bauhausGreen)
            case .failed(let message):
                Text(message)
                    .statusStyle(color: ClubhouseTheme.lacquer)
            }
        }
    }

    private var purchaseButtonTitle: String {
        switch storeManager.productState {
        case .unavailable:
            return "Unlock unavailable"
        case .notLoaded, .loading, .loaded:
            switch storeManager.purchaseState {
            case .loading, .purchasing, .restoring:
                return "Please wait"
            case .success:
                return "Pro unlocked"
            case .idle, .failed:
                if storeManager.product == nil {
                    return "Unlock unavailable"
                }
                return "Unlock forever — \(storeManager.displayPrice)"
            }
        }
    }

    private var purchaseSystemImage: String {
        switch storeManager.purchaseState {
        case .success:
            return "checkmark"
        case .loading, .purchasing, .restoring:
            return "hourglass"
        default:
            return "arrow.right"
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

    private func benefitRow(color: Color, systemImage: String, title: String, detail: String) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(ClubhouseTheme.onPrimary)
                .frame(width: 36, height: 36)
                .background(color, in: Circle())
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
