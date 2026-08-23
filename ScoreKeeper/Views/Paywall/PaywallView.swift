import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)?

    @State private var isCompleting = false
    @State private var heroVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    paywallHero
                    benefitsPanel
                        .staggeredEntrance(visible: heroVisible, index: 1)
                    unlockSummary
                        .staggeredEntrance(visible: heroVisible, index: 2)
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
            withAnimation(reduceMotion ? AppMotion.fade : AppMotion.criticallyDamped) {
                heroVisible = true
            }
            Task { await storeManager.loadProduct() }
        }
        .onChange(of: storeManager.isUnlocked) { _, isUnlocked in
            if isUnlocked {
                completeUnlockFlow()
            }
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: 6) {
            Text("PipCount")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)
            Text("Pro")
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.red)
                .accessibilityIdentifier("paywall_title")

            Spacer()
            closeButton
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
    }

    private var paywallHero: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingMedium))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: AppTheme.spacingSmall))

        return layout {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Unlock\nunlimited\ngame night.")
                    .font(AppFonts.hero)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(ClubhouseTheme.blue)
                    .frame(width: 76, height: 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text("More games.\nMore moments.")
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                    Text("Yours forever.")
                        .foregroundStyle(ClubhouseTheme.red)
                }
                .font(AppFonts.body)
            }
            .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 0 : 190, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)

            if !dynamicTypeSize.isAccessibilitySize {
                PipCountGeometricArtwork(scene: .paywall)
                    .frame(width: 148, height: 212)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scaleEffect(heroVisible || reduceMotion ? 1 : 0.97)
        .opacity(heroVisible ? 1 : 0)
    }

    private var unlockSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingMedium))
            : AnyLayout(HStackLayout(spacing: AppTheme.spacingMedium))

        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text("One-time purchase")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(storeManager.displayPrice)
                    .font(AppFonts.scoreDisplay)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .accessibilityLabel("\(storeManager.displayPrice), one-time purchase")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(ClubhouseTheme.ruleStrong)
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 1,
                    minHeight: dynamicTypeSize.isAccessibilitySize ? 1 : 72,
                    maxHeight: dynamicTypeSize.isAccessibilitySize ? 1 : 72
                )

            ZStack {
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .fill(ClubhouseTheme.blue)
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(90))
                Circle()
                    .fill(ClubhouseTheme.yellow)
                    .frame(width: 38, height: 38)
                    .offset(x: 32, y: 20)
                BauhausPlayerShape(colorIndex: 3, size: 22)
                    .offset(x: 38, y: -24)
            }
            .frame(width: 104, height: 80)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .trailing)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var benefitsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                benefitRow(
                    colorIndex: 0,
                    title: "25 games free",
                    detail: "Try before you upgrade"
                )
                divider
                benefitRow(
                    colorIndex: 1,
                    title: "Then \(storeManager.displayPrice) once",
                    detail: "Pay once. That's it"
                )
                divider
                benefitRow(
                    colorIndex: 2,
                    title: "Unlimited games forever",
                    detail: "All current and future games"
                )
                divider
                benefitRow(
                    colorIndex: 3,
                    title: "No subscription",
                    detail: "No monthly fees. Ever"
                )
            }
        }
        .padding(.horizontal, 2)
    }

    private var divider: some View {
        Rectangle()
            .fill(ClubhouseTheme.rule)
            .frame(height: 1)
            .padding(.leading, 54)
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

                Label("Secure one-time purchase. Your progress is saved.", systemImage: "lock")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
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
                    Label("Unlock forever — \(storeManager.displayPrice)", systemImage: "arrow.right.circle.fill")
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

    private func benefitRow(colorIndex: Int, title: String, detail: String) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            BauhausPlayerShape(colorIndex: colorIndex, size: 46)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(detail)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func completeUnlockFlow() {
        guard storeManager.isUnlocked, !isCompleting else { return }

        isCompleting = true

        dismiss()
        onUnlocked?()
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
