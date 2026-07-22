import SwiftUI

enum LegalSupportLinks {
    static let privacyPolicy = URL(string: "https://privacy.contenthelper.in")!
    static let support = URL(string: "https://support.contenthelper.in")!
}

struct LegalSupportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                BauhausScreenHeader(
                    title: "Legal & Support",
                    subtitle: "Privacy details and help while game night keeps moving.",
                    heroStyle: .home
                )

                VStack(alignment: .leading, spacing: 0) {
                    Link(destination: LegalSupportLinks.privacyPolicy) {
                        LegalSupportLink(
                            title: "Privacy Policy",
                            subtitle: "How PipCount handles your information",
                            systemImage: "hand.raised",
                            accent: ClubhouseTheme.bauhausBlue
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("PipCount Privacy Policy")
                    .accessibilityHint("Open PipCount's privacy policy")
                    .accessibilityIdentifier("privacy_policy_link")

                    Divider()
                        .overlay(ClubhouseTheme.rule)

                    Link(destination: LegalSupportLinks.support) {
                        LegalSupportLink(
                            title: "Support",
                            subtitle: "Get help or contact the PipCount team",
                            systemImage: "questionmark.bubble",
                            accent: ClubhouseTheme.bauhausYellow
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
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
    let accent: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.onPrimary)
                .frame(width: 36, height: 36)
                .background(accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
