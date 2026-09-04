import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onUnlocked: (() -> Void)?

    @State private var isCompleting = false
    @State private var contentVisible = false
    @State private var isExiting = false
    @State private var exitTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
                .pipCountPageContent()

            GeometryReader { proxy in
                ScrollView {
                    if shouldUseTabletLayout(width: proxy.size.width) {
                        tabletContent
                    } else {
                        phoneContent
                    }
                }
                .scrollIndicators(.hidden)
            }

            purchaseFooter
                .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
        }
        .appBackground()
        .opacity(isExiting ? 0 : 1)
        .scaleEffect(isExiting && !reduceMotion ? 0.985 : 1)
        .offset(y: isExiting && !reduceMotion ? 10 : 0)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.artExit, value: isExiting)
        .sensoryFeedback(.success, trigger: storeManager.isUnlocked)
        .onAppear {
            storeManager.paywallPresentedThisSession = true
            contentVisible = true
            Task { await storeManager.loadProduct() }
        }
        .onDisappear {
            exitTask?.cancel()
        }
        .onChange(of: storeManager.isUnlocked) { _, isUnlocked in
            if isUnlocked {
                completeUnlockFlow()
            }
        }
    }

    private var phoneContent: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            paywallHero
                .staggeredEntrance(visible: contentVisible, index: 0)

            benefitsPanel
                .staggeredEntrance(visible: contentVisible, index: 1)

            unlockSummary
                .staggeredEntrance(visible: contentVisible, index: 2)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.bottom, AppTheme.spacingLarge)
        .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
    }

    private var tabletContent: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingXLarge) {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                paywallHero
                    .staggeredEntrance(visible: contentVisible, index: 0)

                unlockSummary
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            benefitsPanel
                .frame(maxWidth: 460, alignment: .top)
                .padding(AppTheme.spacingMedium)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                .staggeredEntrance(visible: contentVisible, index: 1)
        }
        .padding(.horizontal, AppTheme.spacingXLarge)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, AppTheme.spacingXLarge)
        .pipCountPageContent(maxWidth: 1_100)
    }

    private var sheetHeader: some View {
        HStack(spacing: 6) {
            Text("pipcount")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)

            Text("pro")
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
        Group {
            if shouldStackHero {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    heroCopy

                    PipCountGeometricArtwork(scene: .paywall)
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 230 : 300)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingLarge) {
                    heroCopy
                        .frame(maxWidth: 420, alignment: .leading)

                    PipCountGeometricArtwork(scene: .paywall)
                        .frame(maxWidth: .infinity)
                        .frame(height: horizontalSizeClass == .regular ? 380 : 230)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("unlock\nunlimited\ngame night")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 76, height: 4)

            VStack(alignment: .leading, spacing: 0) {
                Text("more games.\nmore moments")
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text("yours forever")
                    .foregroundStyle(ClubhouseTheme.red)
            }
            .font(AppFonts.body)
        }
    }

    private var unlockSummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    priceCopy
                    decorativeUnlimitedMark
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: AppTheme.spacingMedium) {
                    priceCopy

                    Rectangle()
                        .fill(ClubhouseTheme.ruleStrong)
                        .frame(width: 1, height: 72)

                    decorativeUnlimitedMark
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var priceCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("one-time purchase")
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)

            Text(storeManager.displayPrice)
                .font(AppFonts.scoreDisplay)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
                .accessibilityLabel("\(storeManager.displayPrice), one-time purchase")

            Text("no subscription. no recurring fee")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var decorativeUnlimitedMark: some View {
        ZStack {
            Circle()
                .trim(from: 0.25, to: 0.75)
                .fill(ClubhouseTheme.blue)
                .frame(width: 74, height: 74)
                .rotationEffect(.degrees(90))

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: 40, height: 40)
                .offset(x: 34, y: 20)

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(45))
                .offset(x: 38, y: -25)
        }
        .frame(width: 110, height: 88)
        .accessibilityHidden(true)
    }

    private var benefitsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            benefitRow(
                colorIndex: 0,
                title: "25 games free",
                detail: "try every part of pipcount before you upgrade"
            )

            divider

            benefitRow(
                colorIndex: 1,
                title: "then \(storeManager.displayPrice) once",
                detail: "a single purchase unlocks the full app"
            )

            divider

            benefitRow(
                colorIndex: 2,
                title: "unlimited games forever",
                detail: "all current and future game formats"
            )

            divider

            benefitRow(
                colorIndex: 3,
                title: "no subscription",
                detail: "no monthly fees. ever"
            )
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

                Button("restore purchase") {
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

                Label("secure one-time purchase. your progress is saved", systemImage: "lock")
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
            dismissWithAnimation()
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

                Button("retry loading purchase details") {
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
                Text("loading purchase details…")
                    .statusStyle()
            case .purchasing:
                Text("unlocking pipcount pro…")
                    .statusStyle()
            case .restoring:
                Text("checking past purchases…")
                    .statusStyle()
            case .success:
                Text("unlocked. starting your game…")
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
            Label("unlock unavailable", systemImage: "exclamationmark.triangle")

        case .notLoaded, .loading, .loaded:
            switch storeManager.purchaseState {
            case .loading, .purchasing, .restoring:
                HStack(spacing: AppTheme.spacingSmall) {
                    ProgressView()
                        .tint(ClubhouseTheme.onFelt)
                    Text("please wait")
                }
            case .success:
                Label("pro unlocked", systemImage: "checkmark.seal.fill")
            case .idle, .failed:
                if storeManager.product == nil {
                    Label("unlock unavailable", systemImage: "exclamationmark.triangle")
                } else {
                    Label("unlock forever — \(storeManager.displayPrice)", systemImage: "arrow.right.circle.fill")
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

    private var shouldStackHero: Bool {
        dynamicTypeSize.isAccessibilitySize || horizontalSizeClass != .regular
    }

    private func shouldUseTabletLayout(width: CGFloat) -> Bool {
        width >= 820 && horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
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
        dismissWithAnimation {
            onUnlocked?()
        }
    }

    private func dismissWithAnimation(completion: (() -> Void)? = nil) {
        guard !isExiting else { return }
        exitTask?.cancel()

        if reduceMotion {
            dismiss()
            completion?()
            return
        }

        isExiting = true
        exitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            dismiss()
            completion?()
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
