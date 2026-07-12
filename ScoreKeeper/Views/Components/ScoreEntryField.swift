import SwiftUI

struct ScoreEntryField: View {
    @Binding var value: Int
    var label: String = ""
    var range: ClosedRange<Int> = -9999...9999
    var step: Int = 1
    var identifierPrefix: String = ""

    var body: some View {
        VStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppTheme.spacingMedium) {
                PipStepper(value: $value, range: range, step: step, identifierPrefix: identifierPrefix)
            }

            HStack(spacing: 6) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button("+\(amount)") {
                        apply(amount)
                    }
                    .font(AppFonts.caption)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 30)
                    .background(ClubhouseTheme.paperSunken, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(identifierPrefix + "quick_\(amount)")
                    .accessibilityLabel("Add \(amount) points")
                }
            }
        }
    }

    private var quickAmounts: [Int] {
        Array(Set([step, step * 5, step * 10])).sorted()
    }

    private func apply(_ delta: Int) {
        let newValue = value + delta
        if range.contains(newValue) {
            value = newValue
        }
    }
}
