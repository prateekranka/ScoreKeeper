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
                    .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1.25)
            }
            .shadow(
                color: isInteractive ? ClubhouseTheme.paperShadow : .clear,
                radius: isInteractive ? 0 : 0,
                x: isInteractive ? 3 : 0,
                y: isInteractive ? 4 : 0
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

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            if let rank {
                Text("\(rank)")
                    .font(AppFonts.columnHeader)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .frame(width: 24, alignment: .leading)
            }

            PlayerColorPip(colorIndex: player.colorIndex)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                    Text(player.name)
                        .font(AppFonts.body)
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
                .foregroundStyle(isLeader ? ClubhouseTheme.brass : ClubhouseTheme.ink)
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
        BauhausPlayerShape(colorIndex: colorIndex, size: size)
            .accessibilityHidden(true)
    }
}

struct StampBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppFonts.columnHeader)
            .tracking(1.8)
            .foregroundStyle(ClubhouseTheme.lacquer.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(ClubhouseTheme.lacquer.opacity(0.85), lineWidth: 1.5)
            }
            .rotationEffect(.degrees(-4))
            .opacity(0.92)
            .accessibilityLabel(text)
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

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            stepButton(systemImage: "minus", delta: -step, identifier: "decrement", label: "Decrease score")

            VStack(spacing: 0) {
                Text("RD")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text(roundScoreText)
                    .font(AppFonts.scoreMedium)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(ClubhouseTheme.ink)
            }
                .frame(minWidth: 60)
                .accessibilityLabel("Round score \(value)")

            stepButton(systemImage: "plus", delta: step, identifier: "increment", label: "Increase score")
        }
    }

    private func stepButton(systemImage: String, delta: Int, identifier: String, label: String) -> some View {
        Button {
            apply(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(width: 56, height: 56)
                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                }
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

    private var roundScoreText: String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

// MARK: - PipCount Geometry

struct BauhausPlayerShape: View {
    let colorIndex: Int
    var size: CGFloat

    var body: some View {
        Group {
            switch colorIndex % 4 {
            case 0:
                Circle()
                    .fill(PlayerColors.color(for: colorIndex))
                    .overlay { Circle().stroke(ClubhouseTheme.ruleStrong, lineWidth: 0.75) }
            case 1:
                Rectangle()
                    .fill(PlayerColors.color(for: colorIndex))
                    .overlay { Rectangle().stroke(ClubhouseTheme.ruleStrong, lineWidth: 0.75) }
            case 2:
                TriangleShape()
                    .fill(PlayerColors.color(for: colorIndex))
                    .overlay { TriangleShape().stroke(ClubhouseTheme.ruleStrong, lineWidth: 0.75) }
            default:
                Rectangle()
                    .fill(PlayerColors.color(for: colorIndex))
                    .overlay { Rectangle().stroke(ClubhouseTheme.ruleStrong, lineWidth: 0.75) }
                    .rotationEffect(.degrees(45))
                    .scaleEffect(0.72)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct BauhausStarburst: View {
    var color: Color = ClubhouseTheme.red
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: size, height: 1.25)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            DiamondShape()
                .fill(color)
                .frame(width: size * 0.28, height: size * 0.28)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct BauhausHalftone: View {
    var color: Color = ClubhouseTheme.ink
    var spacing: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 2
            while x < size.width {
                var y: CGFloat = 2
                while y < size.height {
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    context.fill(dot, with: .color(color.opacity(0.55)))
                    y += spacing
                }
                x += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

struct BauhausTargetArtwork: View {
    var accent: Color = ClubhouseTheme.red

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(ClubhouseTheme.blue, lineWidth: side * 0.22)
                    .rotationEffect(.degrees(90))

                Circle()
                    .stroke(ClubhouseTheme.ruleStrong, lineWidth: 1)
                    .padding(side * 0.20)
                Circle()
                    .stroke(ClubhouseTheme.ruleStrong, lineWidth: 1)
                    .padding(side * 0.32)

                Circle()
                    .fill(accent)
                    .frame(width: side * 0.24, height: side * 0.24)

                Rectangle()
                    .fill(ClubhouseTheme.ruleStrong)
                    .frame(width: 1, height: side)
                Rectangle()
                    .fill(ClubhouseTheme.ruleStrong)
                    .frame(width: side, height: 1)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

struct BauhausBlocksArtwork: View {
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width / 5, proxy.size.height / 4)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(ClubhouseTheme.yellow)
                    .frame(width: unit * 2.25, height: unit * 2.25)
                    .offset(x: -unit * 2.15, y: -unit * 0.05)

                HStack(alignment: .bottom, spacing: 0) {
                    block(height: unit * 1.15, color: ClubhouseTheme.blue)
                    block(height: unit * 1.85, color: ClubhouseTheme.red)
                    block(height: unit * 2.55, color: ClubhouseTheme.ink)
                    block(height: unit * 3.25, color: ClubhouseTheme.blue)
                    block(height: unit * 2.05, color: ClubhouseTheme.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                BauhausStarburst(color: ClubhouseTheme.red, size: compact ? 30 : 44)
                    .offset(x: -unit * 0.2, y: -unit * 2.85)
            }
        }
        .accessibilityHidden(true)
    }

    private func block(height: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(ClubhouseTheme.paper)
                    .frame(width: 8, height: 8)
            }
    }
}
