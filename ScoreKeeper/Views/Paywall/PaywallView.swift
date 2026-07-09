import SwiftUI

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)?

    @State private var isCompleting = false
    @State private var showBrassConfetti = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ClubhouseTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.spacingLarge) {
                    membershipCard
                    restoreButton
                }
                .padding(AppTheme.spacingMedium)
                .padding(.top, AppTheme.spacingXLarge)
            }

            closeButton
                .padding(AppTheme.spacingMedium)

            if showBrassConfetti {
                BrassConfetti()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityIdentifier("paywall_sheet")
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

    private var membershipCard: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            VStack(spacing: AppTheme.spacingSmall) {
                Text("ScoreKeeper Pro")
                    .font(AppFonts.display)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .multilineTextAlignment(.center)

                StampBadge(text: "LIFETIME")
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                benefitLine("Unlimited games")
                benefitLine("One-time purchase, no subscription")
                benefitLine("Every future feature included")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusText

            AppActionButton(role: .primary(ClubhouseTheme.felt)) {
                Task {
                    if await storeManager.purchase() {
                        completeUnlockFlow()
                    }
                }
            } label: {
                Label("Unlock forever — \(storeManager.displayPrice)", systemImage: "checkmark.seal.fill")
            }
            .accessibilityIdentifier("paywall_unlock_button")
            .disabled(isPurchaseButtonDisabled)

            Text("Made by one person who also just wanted game night to be simpler. — Prateek")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacingLarge)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(ClubhouseTheme.ink.opacity(0.25), lineWidth: 1)
                .padding(5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(ClubhouseTheme.brass.opacity(0.8), lineWidth: 1)
                .padding(10)
        }
        .shadow(color: ClubhouseTheme.paperShadow, radius: 14, y: 6)
    }

    private var restoreButton: some View {
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
        .disabled(isPurchaseButtonDisabled)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(width: 44, height: 44)
                .background(ClubhouseTheme.paperCard, in: Circle())
                .overlay { Circle().strokeBorder(ClubhouseTheme.rule, lineWidth: 1) }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Close")
        .accessibilityIdentifier("paywall_close_button")
    }

    @ViewBuilder
    private var statusText: some View {
        switch storeManager.purchaseState {
        case .idle:
            EmptyView()
        case .loading:
            Text("Loading membership details...")
                .statusStyle()
        case .purchasing:
            Text("Unlocking...")
                .statusStyle()
        case .restoring:
            Text("Checking past purchases...")
                .statusStyle()
        case .success:
            Text("Unlocked. Starting your game...")
                .statusStyle(color: ClubhouseTheme.brass)
        case .failed(let message):
            Text(message)
                .statusStyle(color: ClubhouseTheme.lacquer)
        }
    }

    private var isPurchaseButtonDisabled: Bool {
        switch storeManager.purchaseState {
        case .loading, .purchasing, .restoring:
            return true
        case .idle, .success, .failed:
            return isCompleting
        }
    }

    private func benefitLine(_ text: String) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ClubhouseTheme.felt)
                .accessibilityHidden(true)

            Text(text)
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
        }
    }

    private func completeUnlockFlow() {
        guard storeManager.isUnlocked, !isCompleting else { return }

        isCompleting = true
        withAnimation(.easeOut(duration: 0.2)) {
            showBrassConfetti = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            dismiss()
            onUnlocked?()
        }
    }
}

private struct BrassConfetti: View {
    private let offsets: [CGSize] = [
        .init(width: -110, height: -140),
        .init(width: 80, height: -120),
        .init(width: -60, height: 30),
        .init(width: 120, height: 60),
        .init(width: 0, height: -30)
    ]

    var body: some View {
        ZStack {
            ForEach(offsets.indices, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? ClubhouseTheme.brass : ClubhouseTheme.felt)
                    .frame(width: 12, height: 12)
                    .offset(offsets[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
