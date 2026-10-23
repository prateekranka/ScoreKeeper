import SwiftUI

struct PaywallView: View {
    let route: PaywallRoute
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pipCountRailInset) private var railInset
    @State private var selectedPlan: ProProduct?

    private var availablePlans: [ProProduct] {
        (route == .gift ? [.gift] : [.yearly, .lifetime]).filter { storeManager.products[$0] != nil }
    }

    private var plan: ProProduct? {
        if let selectedPlan, availablePlans.contains(selectedPlan) { return selectedPlan }
        return availablePlans.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    storeManager.closePaywall()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("paywall_close_button")
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.trailing, railInset)
            .frame(height: max(48, railInset * 2), alignment: .top)
            .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: route == .gift ? .center : .leading, spacing: AppTheme.spacingMedium) {
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
                            ForEach(availablePlans, id: \.self) { option in
                                planButton(option, title: option == .yearly ? "Yearly" : "Lifetime", identifier: option == .yearly ? "paywall_plan_yearly" : "paywall_plan_lifetime")
                            }
                        } else if let plan, let price = priceText(for: plan) {
                            Text("PipCount Pro · \(price)")
                                .font(AppFonts.title)
                                .foregroundStyle(ClubhouseTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if case .unavailable(let message) = storeManager.productState {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(ClubhouseTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if case .failed(let message) = storeManager.purchaseState {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(ClubhouseTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("paywall_purchase_status")
                        }

                        purchaseAction

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
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("paywall_legal_scroll")
                    }
                    .padding(AppTheme.spacingMedium)
                    .frame(minHeight: route == .gift ? proxy.size.height : 0)
                    .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
                }
                .accessibilityIdentifier("paywall_content_scroll")
            }
        }
        .appBackground()
        .tint(ClubhouseTheme.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(route == .main ? "paywall_main" : "paywall_gift")
        .interactiveDismissDisabled()
        .task(id: route) { await storeManager.loadProducts() }
    }

    @ViewBuilder
    private var purchaseAction: some View {
        if let plan {
            AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                Task { await storeManager.purchase(plan) }
            } label: {
                Text(storeManager.isBusy ? "Please wait" : primaryTitle(for: plan))
            }
            .disabled(!storeManager.canPurchase(plan))
            .accessibilityIdentifier("paywall_primary_button")
        } else {
            AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                Task { await storeManager.loadProducts(forceRetry: true) }
            } label: {
                Text(storeManager.productState == .loading ? "Please wait" : "Retry")
            }
            .disabled(storeManager.productState == .loading)
            .accessibilityIdentifier("paywall_retry_button")
        }
    }

    private func benefit(_ title: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingSmall) {
            Image(systemName: symbol)
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AppFonts.body)
        .foregroundStyle(ClubhouseTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func planButton(_ option: ProProduct, title: String, identifier: String) -> some View {
        Button {
            selectedPlan = option
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Label("\(title) · \(priceText(for: option) ?? "")", systemImage: plan == option ? "checkmark.circle.fill" : "circle")
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
                    .strokeBorder(plan == option ? ClubhouseTheme.ink : ClubhouseTheme.ruleStrong, lineWidth: plan == option ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(plan == option ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func priceText(for plan: ProProduct) -> String? {
        guard let product = storeManager.products[plan] else { return nil }
        return plan == .lifetime ? product.displayPrice : "\(product.displayPrice)/year"
    }

    private var legalText: String? {
        guard let plan, let product = storeManager.products[plan] else { return nil }
        if plan == .lifetime { return "\(product.displayPrice) once. Lifetime access." }
        if let period = storeManager.trialPeriodText(for: plan) {
            return "\(period) free, then \(product.displayPrice)/year. Cancel anytime."
        }
        return "\(product.displayPrice)/year. Cancel anytime."
    }

    private func primaryTitle(for plan: ProProduct) -> String {
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
