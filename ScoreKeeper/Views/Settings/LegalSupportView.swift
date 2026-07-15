import SwiftUI

enum LegalSupportLinks {
    static let privacyPolicy = URL(string: "https://privacy.contenthelper.in")!
    static let support = URL(string: "https://support.contenthelper.in")!
}

struct LegalSupportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Label("PipCount", systemImage: "checkmark.seal")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text("Find the privacy details and support you need while keeping game night moving.")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Link(destination: LegalSupportLinks.privacyPolicy) {
                        LegalSupportLink(
                            title: "Privacy Policy",
                            subtitle: "How PipCount handles your information",
                            systemImage: "hand.raised"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("PipCount Privacy Policy")
                    .accessibilityHint("Open PipCount's privacy policy")
                    .accessibilityIdentifier("privacy_policy_link")

                    Divider()
                        .overlay(ClubhouseTheme.rule)

                    Link(destination: LegalSupportLinks.support) {
                        LegalSupportLink(
                            title: "Support",
                            subtitle: "Get help or contact the PipCount team",
                            systemImage: "questionmark.bubble"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("PipCount Support")
                    .accessibilityHint("Open PipCount support")
                    .accessibilityIdentifier("support_link")
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)

                Text("These links open in your default browser.")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .accessibilityLabel("Privacy and support links open in your default browser.")
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Legal & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalSupportLink: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ClubhouseTheme.felt)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        LegalSupportView()
    }
}
