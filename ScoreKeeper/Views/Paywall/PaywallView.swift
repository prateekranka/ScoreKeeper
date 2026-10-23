import SwiftUI

struct PaywallView: View {
    let route: PaywallRoute
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPlan: ProProduct = .yearly

    private var plan: ProProduct { route == .gift ? .gift : selectedPlan }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    storeManager.closePaywall()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("paywall_close_button")
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    if route == .gift {
                        Image(systemName: "gift")
                            .font(.largeTitle)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .accessibilityHidden(true)
                    }
                    Text(route == .gift ? "50% off" : "PipCount Pro")
                        .font(AppFonts.hero)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("paywall_title")

                    if route == .main {
                        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                            benefit("Unlimited games", symbol: "infinity")
                            benefit("All three formats", symbol: "square.grid.2x2")
                            benefit("Stats & history", symbol: "chart.bar")
                        }
                        planButton(.yearly, title: "Yearly", identifier: "paywall_plan_yearly")
                        planButton(.lifetime, title: "Lifetime", identifier: "paywall_plan_lifetime")
                    } else {
                        Text("PipCount Pro · \(priceText(for: .gift))")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)
                    }

                    if case .unavailable(let message) = storeManager.productState {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(ClubhouseTheme.ink)
                    }
                    if storeManager.products[plan] == nil && storeManager.productState != .loading {
                        Button("Retry") {
                            Task { await storeManager.loadProducts(forceRetry: true) }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("paywall_retry_button")
                    }
                    if case .failed(let message) = storeManager.purchaseState {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("paywall_purchase_status")
                    }
                }
                .padding(AppTheme.spacingMedium)
                .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
            }
            .accessibilityIdentifier("paywall_content_scroll")

            VStack(spacing: AppTheme.spacingSmall) {
                AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                    Task { await storeManager.purchase(plan) }
                } label: {
                    Text(storeManager.isBusy ? "Please wait" : primaryTitle)
                }
                .disabled(!storeManager.canPurchase(plan))
                .accessibilityIdentifier("paywall_primary_button")

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        if let legalText {
                            Text(legalText)
                                .font(.subheadline)
                                .foregroundStyle(ClubhouseTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("paywall_legal_text")
                        }
                        legalLinks
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 110)
                .accessibilityIdentifier("paywall_legal_scroll")
            }
            .padding(AppTheme.spacingMedium)
            .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
        }
        .appBackground()
        .tint(ClubhouseTheme.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(route == .main ? "paywall_main" : "paywall_gift")
        .interactiveDismissDisabled()
        .task { await storeManager.loadProducts() }
    }

    private func benefit(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(AppFonts.body)
            .foregroundStyle(ClubhouseTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func planButton(_ option: ProProduct, title: String, identifier: String) -> some View {
        Button {
            selectedPlan = option
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Label("\(title) · \(priceText(for: option))", systemImage: selectedPlan == option ? "checkmark.circle.fill" : "circle")
                    .font(AppFonts.headline)
                if let period = storeManager.trialPeriodText(for: option) {
                    Text("\(period) free")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(ClubhouseTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(AppTheme.spacingMedium)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .strokeBorder(selectedPlan == option ? ClubhouseTheme.ink : ClubhouseTheme.ruleStrong, lineWidth: selectedPlan == option ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedPlan == option ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func priceText(for plan: ProProduct) -> String {
        guard let product = storeManager.products[plan] else { return "Price unavailable" }
        return plan == .lifetime ? product.displayPrice : "\(product.displayPrice)/year"
    }

    private var legalText: String? {
        guard let product = storeManager.products[plan] else { return nil }
        if plan == .lifetime { return "\(product.displayPrice) once. Lifetime access." }
        if let period = storeManager.trialPeriodText(for: plan) {
            return "\(period) free, then \(product.displayPrice)/year. Cancel anytime."
        }
        return "\(product.displayPrice)/year. Cancel anytime."
    }

    private var primaryTitle: String {
        if plan == .lifetime { return "Buy Lifetime" }
        return storeManager.trialPeriodText(for: plan) == nil ? "Subscribe" : "Start free trial"
    }

    private var legalLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.spacingMedium) { linkControls }
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) { linkControls }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ClubhouseTheme.ink)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var linkControls: some View {
        Button("Restore") { Task { await storeManager.restore() } }
            .disabled(storeManager.isBusy)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("paywall_restore_button")
        Link("Terms", destination: LegalSupportLinks.terms)
            .frame(minWidth: 44, minHeight: 44)
        Link("Privacy", destination: LegalSupportLinks.privacyPolicy)
            .frame(minWidth: 44, minHeight: 44)
    }
}
