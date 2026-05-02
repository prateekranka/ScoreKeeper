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
                Button("Decrease", systemImage: "minus.circle.fill") {
                    let newValue = value - step
                    if newValue >= range.lowerBound {
                        value = newValue
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(identifierPrefix + "decrement")
                .accessibilityLabel("Decrease score")

                Text("\(value)")
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .frame(minWidth: 56)
                    .accessibilityLabel("Score \(value)")

                Button("Increase", systemImage: "plus.circle.fill") {
                    let newValue = value + step
                    if newValue <= range.upperBound {
                        value = newValue
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(identifierPrefix + "increment")
                .accessibilityLabel("Increase score")
            }

            HStack(spacing: 6) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button("+\(amount)") {
                        apply(amount)
                    }
                    .font(AppFonts.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 30)
                    .background(.regularMaterial, in: Capsule())
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
