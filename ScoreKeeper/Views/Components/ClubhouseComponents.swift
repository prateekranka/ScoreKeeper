import SwiftUI

// MARK: - Shared paper surfaces

struct ScorecardSurface<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium
    var isInteractive = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ClubhouseTheme.paperCard)
                    .overlay {
                        PaperSpeckleOverlay()
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .opacity(0.22)
                    }
                    .shadow(
                        color: ClubhouseTheme.paperShadow.opacity(isInteractive ? 1 : 0.66),
                        radius: isInteractive ? 13 : 8,
                        x: 0,
                        y: isInteractive ? 8 : 5
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ClubhouseTheme.panelBorder.opacity(0.88), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .trim(from: 0.50, to: 0.76)
                    .stroke(ClubhouseTheme.warmHighlight.opacity(0.68), lineWidth: 1)
                    .padding(1)
            }
    }
}

extension View {
    func scorecardSurface(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium, isInteractive: Bool = false) -> some View {
        ScorecardSurface(cornerRadius: cornerRadius, isInteractive: isInteractive) {
            self
        }
    }
}

private struct PaperSpeckleOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 6
            var row = 0
            while y < size.height {
                var x: CGFloat = 6
                var column = 0
                while x < size.width {
                    let seed = CGFloat((row * 13 + column * 7) % 17)
                    let dotSize: CGFloat = seed.truncatingRemainder(dividingBy: 4) == 0 ? 0.9 : 0.45
                    let dot = CGRect(
                        x: x + seed.truncatingRemainder(dividingBy: 3.2),
                        y: y + seed.truncatingRemainder(dividingBy: 2.6),
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: dot), with: .color(ClubhouseTheme.ink.opacity(0.11)))
                    column += 1
                    x += 14
                }
                row += 1
                y += 14
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Ledger pieces

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

            PlayerColorPip(colorIndex: player.colorIndex, size: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                    Text(player.name)
                        .font(AppFonts.body.weight(.medium))
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
        .padding(.vertical, 11)
        .padding(.horizontal, AppTheme.spacingSmall)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PlayerColors.lightColor(for: player.colorIndex).opacity(0.86))
            }
        }
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
    var size: CGFloat = 16

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
            .tracking(1.4)
            .foregroundStyle(ClubhouseTheme.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ClubhouseTheme.red.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(ClubhouseTheme.red.opacity(0.72), lineWidth: 1.4)
            }
            .rotationEffect(.degrees(-3))
            .accessibilityLabel(text)
    }
}

struct BrassCrown: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.caption2)
            .foregroundStyle(ClubhouseTheme.brass)
            .shadow(color: ClubhouseTheme.yellow.opacity(0.24), radius: 4)
            .accessibilityLabel("Leader")
    }
}

struct PaperChip<Content: View>: View {
    var isSelected = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(AppFonts.caption.weight(.medium))
            .foregroundStyle(isSelected ? ClubhouseTheme.onFelt : ClubhouseTheme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background {
                Capsule()
                    .fill(isSelected ? ClubhouseTheme.blue : ClubhouseTheme.paperCard)
                    .shadow(color: ClubhouseTheme.paperShadow.opacity(0.45), radius: 5, y: 3)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? ClubhouseTheme.warmHighlight.opacity(0.28) : ClubhouseTheme.panelBorder,
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - Score controls

struct PipStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = -9999...9999
    var step = 1
    var identifierPrefix = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                stepButton(systemImage: "minus", delta: -step, identifier: "decrement", label: "Decrease score")

                VStack(spacing: 1) {
                    Text("THIS ROUND")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(ClubhouseTheme.inkMuted)

                    Text(roundScoreText)
                        .font(AppFonts.scoreMedium)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(ClubhouseTheme.ink)
                }
                .frame(minWidth: 70)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifierPrefix + "score")
                .accessibilityLabel("Score \(value)")

                stepButton(systemImage: "plus", delta: step, identifier: "increment", label: "Increase score")
            }

            HStack(spacing: 7) {
                quickButton(delta: 1)
                quickButton(delta: 5)
                quickButton(delta: 10)
            }
        }
    }

    private func stepButton(systemImage: String, delta: Int, identifier: String, label: String) -> some View {
        Button {
            apply(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(width: 58, height: 58)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ClubhouseTheme.paperCard)
                        .shadow(color: ClubhouseTheme.paperShadow.opacity(0.52), radius: 7, y: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
                }
        }
        .buttonStyle(ClubhousePressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + identifier)
        .accessibilityLabel(label)
    }

    private func quickButton(delta: Int) -> some View {
        Button {
            apply(delta)
        } label: {
            Text("+\(delta)")
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(minWidth: 48, minHeight: 42)
                .background(ClubhouseTheme.blue.opacity(0.075), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(ClubhouseTheme.blue.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(ClubhousePressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + "quick_\(delta)")
        .accessibilityLabel("Add \(delta) points")
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

// MARK: - Illustration assets

enum PipCountIllustrationAsset: String {
    case hero = "PipCountHeroArtwork"
    case emptyState = "PipCountEmptyStateArtwork"
    case scoreEmblem = "PipCountScoreEmblem"
    case crewEmblem = "PipCountCrewEmblem"
    case unlimitedEmblem = "PipCountUnlimitedEmblem"
    case celebrationEmblem = "PipCountCelebrationEmblem"
}

struct PipCountAssetArtwork: View {
    let asset: PipCountIllustrationAsset
    var contentMode: ContentMode = .fit

    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .accessibilityHidden(true)
    }
}

// The old name is retained for source compatibility, but the shapes now read
// as small tactile game tokens rather than strict Bauhaus primitives.
struct BauhausPlayerShape: View {
    let colorIndex: Int
    var size: CGFloat

    var body: some View {
        tokenShape
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.48))
                    .frame(width: size * 0.22, height: size * 0.16)
                    .blur(radius: 0.4)
                    .offset(x: size * 0.20, y: size * 0.18)
            }
            .shadow(color: ClubhouseTheme.paperShadow.opacity(0.58), radius: max(1.5, size * 0.10), y: max(1, size * 0.07))
    }

    @ViewBuilder
    private var tokenShape: some View {
        switch colorIndex % 4 {
        case 0:
            Circle()
                .fill(PlayerColors.color(for: colorIndex))
                .overlay { Circle().stroke(ClubhouseTheme.ink.opacity(0.48), lineWidth: 0.8) }
        case 1:
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(PlayerColors.color(for: colorIndex))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(ClubhouseTheme.ink.opacity(0.48), lineWidth: 0.8)
                }
        case 2:
            SoftTriangleShape()
                .fill(PlayerColors.color(for: colorIndex))
                .overlay { SoftTriangleShape().stroke(ClubhouseTheme.ink.opacity(0.48), lineWidth: 0.8) }
        default:
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(PlayerColors.color(for: colorIndex))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(ClubhouseTheme.ink.opacity(0.48), lineWidth: 0.8)
                }
                .rotationEffect(.degrees(45))
                .scaleEffect(0.76)
        }
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

private struct SoftTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.04))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.maxY - rect.height * 0.07),
            control: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.height * 0.68)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.maxY - rect.height * 0.07),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.04),
            control: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.height * 0.68)
        )
        path.closeSubpath()
        return path
    }
}

struct BauhausStarburst: View {
    var color: Color = ClubhouseTheme.red
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(index.isMultiple(of: 2) ? 1 : 0.72))
                    .frame(width: size, height: max(1, size * 0.045))
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            Circle()
                .fill(ClubhouseTheme.paperCard)
                .frame(width: size * 0.18, height: size * 0.18)
                .overlay { Circle().stroke(color, lineWidth: 1) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct BauhausHalftone: View {
    var color: Color = ClubhouseTheme.ink
    var spacing: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            var column = 0
            var x: CGFloat = 2
            while x < size.width {
                var row = 0
                var y: CGFloat = 2
                while y < size.height {
                    let offset = CGFloat((column * 5 + row * 3) % 4)
                    let diameter: CGFloat = offset == 0 ? 2.0 : 1.25
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter))
                    context.fill(dot, with: .color(color.opacity(offset == 0 ? 0.42 : 0.24)))
                    row += 1
                    y += spacing
                }
                column += 1
                x += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

struct BauhausTargetArtwork: View {
    var accent: Color = ClubhouseTheme.red

    var body: some View {
        PipCountAssetArtwork(asset: .scoreEmblem)
            .padding(4)
            .shadow(color: ClubhouseTheme.paperShadow.opacity(0.42), radius: 10, y: 7)
            .overlay(alignment: .topTrailing) {
                BauhausStarburst(color: accent, size: 26)
                    .offset(x: -6, y: 2)
            }
    }
}

struct BauhausBlocksArtwork: View {
    var compact = false

    var body: some View {
        PipCountAssetArtwork(asset: .hero, contentMode: compact ? .fit : .fill)
            .clipped()
            .shadow(color: ClubhouseTheme.paperShadow.opacity(0.38), radius: compact ? 6 : 12, y: compact ? 4 : 8)
    }
}

// MARK: - Screen artwork

enum PipCountArtworkScene {
    case home
    case homeEmpty
    case gamePicker
    case playerSetup
    case gameSettings
    case handwriting
    case scoring
    case gameOver
    case paywall
    case onboardingScore
    case onboardingSetup
    case onboardingHistory
    case roster
}

struct PipCountGeometricArtwork: View {
    let scene: PipCountArtworkScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 260, proxy.size.height / 210)

            sceneArtwork
                .frame(width: 260, height: 210)
                .scaleEffect(scale)
                .scaleEffect(isVisible || reduceMotion ? 1 : 0.94)
                .rotationEffect(.degrees(isVisible || reduceMotion ? 0 : -1.5))
                .opacity(isVisible ? 1 : 0)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            withAnimation(reduceMotion ? AppMotion.fade : AppMotion.page) {
                isVisible = true
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sceneArtwork: some View {
        switch scene {
        case .home:
            EditorialAssetScene(asset: .hero, rotation: -1.4, accent: ClubhouseTheme.red)
        case .homeEmpty:
            EditorialAssetScene(asset: .emptyState, rotation: 1.2, accent: ClubhouseTheme.green)
        case .gamePicker:
            TabletopGamePickerArtwork()
        case .playerSetup, .roster, .onboardingSetup:
            EditorialAssetScene(asset: .crewEmblem, rotation: -1.2, accent: ClubhouseTheme.yellow)
        case .gameSettings:
            RulesDialArtwork()
        case .handwriting:
            HandwritingScoreArtwork()
        case .scoring, .onboardingScore:
            EditorialAssetScene(asset: .scoreEmblem, rotation: 1.1, accent: ClubhouseTheme.blue)
        case .gameOver, .onboardingHistory:
            EditorialAssetScene(asset: .celebrationEmblem, rotation: -1.0, accent: ClubhouseTheme.yellow)
        case .paywall:
            EditorialAssetScene(asset: .unlimitedEmblem, rotation: 1.0, accent: ClubhouseTheme.green)
        }
    }
}

private struct EditorialAssetScene: View {
    let asset: PipCountIllustrationAsset
    var rotation: Double = 0
    var accent: Color = ClubhouseTheme.red

    var body: some View {
        ZStack {
            SoftBlob()
                .fill(accent.opacity(0.10))
                .frame(width: 188, height: 154)
                .rotationEffect(.degrees(-8))
                .offset(x: -12, y: 8)

            PipCountAssetArtwork(asset: asset)
                .padding(8)
                .rotationEffect(.degrees(rotation))
                .shadow(color: ClubhouseTheme.paperShadow.opacity(0.44), radius: 12, y: 8)

            BauhausStarburst(color: accent, size: 28)
                .offset(x: 92, y: -72)

            BauhausHalftone(color: ClubhouseTheme.inkMuted, spacing: 7)
                .frame(width: 44, height: 58)
                .offset(x: -100, y: 62)
                .opacity(0.55)
        }
    }
}

private struct SoftBlob: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.34))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.06),
            control1: CGPoint(x: rect.width * 0.24, y: rect.height * 0.04),
            control2: CGPoint(x: rect.width * 0.48, y: rect.height * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.58),
            control1: CGPoint(x: rect.width * 0.88, y: rect.height * 0.10),
            control2: CGPoint(x: rect.width * 0.99, y: rect.height * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.96),
            control1: CGPoint(x: rect.width * 0.88, y: rect.height * 0.92),
            control2: CGPoint(x: rect.width * 0.66, y: rect.height * 0.98)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.34),
            control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.98),
            control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.58)
        )
        path.closeSubpath()
        return path
    }
}

private struct TabletopGamePickerArtwork: View {
    var body: some View {
        ZStack {
            SoftBlob()
                .fill(ClubhouseTheme.sky.opacity(0.48))
                .frame(width: 210, height: 170)
                .rotationEffect(.degrees(8))

            miniCard(color: ClubhouseTheme.blue, icon: "pencil.and.list.clipboard", rotation: -9)
                .offset(x: -62, y: 14)
            miniCard(color: ClubhouseTheme.red, icon: "rectangle.stack.fill", rotation: 5)
                .offset(x: 4, y: -18)
            miniCard(color: ClubhouseTheme.yellow, icon: "fork.knife", rotation: 10)
                .offset(x: 68, y: 18)

            DicePairArtwork()
                .frame(width: 74, height: 54)
                .offset(x: 18, y: 72)

            BauhausStarburst(color: ClubhouseTheme.green, size: 28)
                .offset(x: -92, y: -68)
        }
    }

    private func miniCard(color: Color, icon: String, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(ClubhouseTheme.paperCard)
            .frame(width: 92, height: 116)
            .overlay {
                VStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.16))
                        .frame(width: 58, height: 58)
                        .overlay {
                            Image(systemName: icon)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(color)
                        }
                    Capsule()
                        .fill(ClubhouseTheme.ruleStrong.opacity(0.48))
                        .frame(width: 48, height: 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
            }
            .shadow(color: ClubhouseTheme.paperShadow.opacity(0.48), radius: 8, y: 6)
            .rotationEffect(.degrees(rotation))
    }
}

private struct DicePairArtwork: View {
    var body: some View {
        ZStack {
            die(color: ClubhouseTheme.coral, pips: [0, 4])
                .rotationEffect(.degrees(-10))
                .offset(x: -18, y: 3)
            die(color: ClubhouseTheme.blue, pips: [0, 2, 4])
                .rotationEffect(.degrees(8))
                .offset(x: 19, y: -2)
        }
    }

    private func die(color: Color, pips: [Int]) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color)
            .frame(width: 44, height: 44)
            .overlay {
                GeometryReader { proxy in
                    ForEach(pips, id: \.self) { pip in
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 6, height: 6)
                            .position(position(for: pip, in: proxy.size))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ink.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: ClubhouseTheme.paperShadow.opacity(0.55), radius: 5, y: 4)
    }

    private func position(for pip: Int, in size: CGSize) -> CGPoint {
        let points = [
            CGPoint(x: size.width * 0.50, y: size.height * 0.50),
            CGPoint(x: size.width * 0.28, y: size.height * 0.28),
            CGPoint(x: size.width * 0.72, y: size.height * 0.28),
            CGPoint(x: size.width * 0.28, y: size.height * 0.72),
            CGPoint(x: size.width * 0.72, y: size.height * 0.72)
        ]
        return points[min(max(pip, 0), points.count - 1)]
    }
}

private struct RulesDialArtwork: View {
    var body: some View {
        ZStack {
            SoftBlob()
                .fill(ClubhouseTheme.yellow.opacity(0.18))
                .frame(width: 206, height: 166)
                .rotationEffect(.degrees(-5))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ClubhouseTheme.paperCard)
                .frame(width: 184, height: 136)
                .overlay {
                    HStack(spacing: 22) {
                        dial(color: ClubhouseTheme.blue, value: -22)
                        dial(color: ClubhouseTheme.red, value: 18)
                        dial(color: ClubhouseTheme.green, value: -4)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
                }
                .shadow(color: ClubhouseTheme.paperShadow.opacity(0.45), radius: 10, y: 7)
                .rotationEffect(.degrees(1.5))

            BauhausStarburst(color: ClubhouseTheme.red, size: 26)
                .offset(x: 98, y: -66)
        }
    }

    private func dial(color: Color, value: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(ClubhouseTheme.rule)
                .frame(width: 6, height: 88)
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay { Circle().stroke(Color.white.opacity(0.58), lineWidth: 1) }
                .offset(y: value)
                .shadow(color: ClubhouseTheme.paperShadow.opacity(0.35), radius: 4, y: 2)
        }
    }
}

private struct HandwritingScoreArtwork: View {
    var body: some View {
        ZStack {
            SoftBlob()
                .fill(ClubhouseTheme.lilac.opacity(0.17))
                .frame(width: 204, height: 168)
                .rotationEffect(.degrees(6))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ClubhouseTheme.paperCard)
                .frame(width: 176, height: 142)
                .overlay {
                    VStack(spacing: 22) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(ClubhouseTheme.sky.opacity(0.82))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .overlay {
                    Text("12")
                        .font(.system(size: 78, weight: .bold, design: .rounded))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .rotationEffect(.degrees(-7))
                }
                .overlay(alignment: .bottomTrailing) {
                    PencilArtwork()
                        .frame(width: 118, height: 30)
                        .rotationEffect(.degrees(-18))
                        .offset(x: 26, y: 18)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
                }
                .shadow(color: ClubhouseTheme.paperShadow.opacity(0.48), radius: 10, y: 7)
                .rotationEffect(.degrees(-1.8))
        }
    }
}

private struct PencilArtwork: View {
    var body: some View {
        HStack(spacing: 0) {
            TriangleShape()
                .fill(ClubhouseTheme.woodgrain)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(-90))
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(ClubhouseTheme.ink)
                        .frame(width: 5, height: 5)
                        .offset(x: -1)
                }
            Rectangle()
                .fill(ClubhouseTheme.yellow)
                .frame(height: 22)
            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 15, height: 22)
            Capsule()
                .fill(ClubhouseTheme.coral.opacity(0.70))
                .frame(width: 18, height: 22)
                .offset(x: -4)
        }
        .clipShape(Capsule())
        .overlay { Capsule().stroke(ClubhouseTheme.ink.opacity(0.32), lineWidth: 1) }
        .shadow(color: ClubhouseTheme.paperShadow.opacity(0.35), radius: 3, y: 2)
    }
}
