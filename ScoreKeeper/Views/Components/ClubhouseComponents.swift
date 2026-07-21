import SwiftUI

struct ScorecardSurface<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium
    var isInteractive = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
            }
            .shadow(
                color: ClubhouseTheme.paperShadow,
                radius: isInteractive ? 12 : 6,
                y: isInteractive ? 4 : 2
            )
    }
}

extension View {
    func scorecardSurface(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium, isInteractive: Bool = false) -> some View {
        ScorecardSurface(cornerRadius: cornerRadius, isInteractive: isInteractive) {
            self
        }
    }
}

struct LedgerRow: View {
    let player: Player
    let score: Int
    var rank: Int?
    var subtitle: String?
    var isLeader = false
    var isHighlighted = false
    var trailingLabel: String?
    var scoreColor: Color? = nil

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            if let rank {
                Text("\(rank)")
                    .font(AppFonts.columnHeader)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .frame(width: 24, alignment: .leading)
            }

            PlayerShapeIcon(colorIndex: player.colorIndex, size: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(player.name)
                        .font(AppFonts.body.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if isLeader {
                        BrassCrown()
                            .fixedSize()
                    }
                }
                .layoutPriority(1)

                if let subtitle {
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: AppTheme.spacingSmall)

            if let trailingLabel {
                Text(trailingLabel)
                    .columnHeaderStyle()
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text("\(score)")
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(score)))
                .foregroundStyle(scoreColor ?? (isLeader ? ClubhouseTheme.brass : PlayerColors.color(for: player.colorIndex)))
                .frame(minWidth: 48, alignment: .trailing)
        }
        .padding(.vertical, AppTheme.spacingSmall)
        .padding(.horizontal, AppTheme.spacingSmall)
        .background(isHighlighted ? PlayerColors.lightColor(for: player.colorIndex) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PlayerColorPip: View {
    let colorIndex: Int
    var size: CGFloat = 14

    var body: some View {
        PlayerShapeIcon(colorIndex: colorIndex, size: size)
    }
}

struct StampBadge: View {
    let text: String

    var body: some View {
        StatusPill(kind: .custom(text.uppercased(), ClubhouseTheme.bauhausGreen))
    }
}

struct BrassCrown: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.caption2)
            .foregroundStyle(ClubhouseTheme.brass)
            .accessibilityLabel("Leader")
    }
}

struct PaperChip<Content: View>: View {
    var isSelected = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(AppFonts.caption)
            .foregroundStyle(isSelected ? ClubhouseTheme.onFelt : ClubhouseTheme.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.paperCard, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.rule, lineWidth: 1)
            }
    }
}

struct PipStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = -9999...9999
    var step = 1
    var identifierPrefix = ""
    var accentColor: Color = ClubhouseTheme.bauhausBlue

    var body: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            stepButton(
                systemImage: "minus",
                fill: ClubhouseTheme.bauhausRed,
                delta: -step,
                identifier: "decrement",
                label: "Decrease score"
            )

            VStack(spacing: 2) {
                Text("\(value)")
                    .font(AppFonts.scoreMedium)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(ClubhouseTheme.ink)
                Text("POINTS")
                    .font(AppFonts.columnHeader)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
            }
            .accessibilityLabel("Round score \(value)")

            stepButton(
                systemImage: "plus",
                fill: accentColor,
                delta: step,
                identifier: "increment",
                label: "Increase score"
            )
        }
    }

    private func stepButton(systemImage: String, fill: Color, delta: Int, identifier: String, label: String) -> some View {
        Button {
            apply(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(fill, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(ClubhousePressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + identifier)
        .accessibilityLabel(label)
    }

    private func apply(_ delta: Int) {
        let newValue = value + delta
        if range.contains(newValue) {
            value = newValue
        }
    }
}
