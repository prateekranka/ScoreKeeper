import SwiftUI

struct ScoreEntryField: View {
    @Binding var value: Int
    var label: String = ""
    var range: ClosedRange<Int> = -9999...9999
    var step: Int = 1

    var body: some View {
        VStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppTheme.spacingMedium) {
                Button {
                    let newValue = value - step
                    if newValue >= range.lowerBound {
                        value = newValue
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(value)")
                    .font(AppFonts.scoreSmall)
                    .frame(minWidth: 50)
                    .contentTransition(.numericText())

                Button {
                    let newValue = value + step
                    if newValue <= range.upperBound {
                        value = newValue
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
