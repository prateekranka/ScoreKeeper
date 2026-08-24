import SwiftUI

// MARK: - Paper surfaces

struct ScorecardSurface<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium
    var isInteractive = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ClubhouseTheme.paperShadow.opacity(isInteractive ? 0.74 : 0.42))
                        .offset(x: isInteractive ? 4 : 2, y: isInteractive ? 7 : 4)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ClubhouseTheme.paperCard)
                        .shadow(
                            color: ClubhouseTheme.ink.opacity(isInteractive ? 0.095 : 0.055),
                            radius: isInteractive ? 18 : 11,
                            x: 0,
                            y: isInteractive ? 9 : 5
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ruleStrong.opacity(0.42), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: max(cornerRadius - 3, 0), style: .continuous)
                    .trim(from: 0.53, to: 0.78)
                    .stroke(ClubhouseTheme.warmHighlight.opacity(0.64), lineWidth: 1)
                    .padding(2)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func scorecardSurface(
        cornerRadius: CGFloat = AppTheme.cornerRadiusMedium,
        isInteractive: Bool = false
    ) -> some View {
        ScorecardSurface(cornerRadius: cornerRadius, isInteractive: isInteractive) {
            self
        }
    }
}

// MARK: - Score rows and geometric player marks

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

            PlayerColorPip(colorIndex: player.colorIndex, size: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
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
                    .fill(PlayerColors.lightColor(for: player.colorIndex))
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule.opacity(0.72))
                .frame(height: 0.75)
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
            .tracking(1.4)
            .foregroundStyle(ClubhouseTheme.lacquer)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ClubhouseTheme.lacquer.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ClubhouseTheme.lacquer.opacity(0.78), lineWidth: 1.4)
            }
            .rotationEffect(.degrees(-3))
            .accessibilityLabel(text)
    }
}

struct BrassCrown: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.caption2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(ClubhouseTheme.brass)
            .accessibilityLabel("Leader")
    }
}

struct PaperChip<Content: View>: View {
    var isSelected = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(AppFonts.caption.weight(.semibold))
            .foregroundStyle(isSelected ? ClubhouseTheme.onFelt : ClubhouseTheme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background {
                Capsule()
                    .fill(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.paperCard)
                    .shadow(color: ClubhouseTheme.ink.opacity(isSelected ? 0.12 : 0.05), radius: 7, y: 3)
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.rule.opacity(0.72), lineWidth: 1)
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
            HStack(spacing: AppTheme.spacingSmall) {
                stepButton(systemImage: "minus", delta: -step, identifier: "decrement", label: "Decrease score")

                VStack(spacing: 2) {
                    Text("THIS ROUND")
                        .font(AppFonts.columnHeader)
                        .foregroundStyle(ClubhouseTheme.inkMuted)

                    Text(roundScoreText)
                        .font(AppFonts.scoreMedium)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(ClubhouseTheme.ink)
                }
                .frame(minWidth: 76)
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

    private func stepButton(
        systemImage: String,
        delta: Int,
        identifier: String,
        label: String
    ) -> some View {
        Button {
            apply(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(width: 58, height: 58)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .fill(ClubhouseTheme.paperCard)
                        .shadow(color: ClubhouseTheme.ink.opacity(0.08), radius: 8, y: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(ClubhouseTheme.rule.opacity(0.75), lineWidth: 1)
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
                .background(ClubhouseTheme.blue.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(ClubhouseTheme.blue.opacity(0.24), lineWidth: 1)
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

// MARK: - Compatibility asset family

/// Existing call sites can keep the old API, but the implementation is now
/// entirely native SwiftUI geometry. No raster illustration is required.
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
        PipCountGeometricArtwork(scene: scene)
            .aspectRatio(contentMode: contentMode)
    }

    private var scene: PipCountArtworkScene {
        switch asset {
        case .hero: return .home
        case .emptyState: return .homeEmpty
        case .scoreEmblem: return .scoring
        case .crewEmblem: return .playerSetup
        case .unlimitedEmblem: return .paywall
        case .celebrationEmblem: return .gameOver
        }
    }
}

// MARK: - Foundational Bauhaus shapes

struct BauhausPlayerShape: View {
    let colorIndex: Int
    var size: CGFloat

    private var color: Color {
        PlayerColors.color(for: colorIndex)
    }

    var body: some View {
        shape
            .frame(width: size, height: size)
            .shadow(color: ClubhouseTheme.artShadow.opacity(0.32), radius: max(1, size * 0.06), y: max(1, size * 0.035))
    }

    @ViewBuilder
    private var shape: some View {
        switch colorIndex % 4 {
        case 0:
            Circle()
                .fill(color)
                .overlay { Circle().stroke(ClubhouseTheme.ink.opacity(0.42), lineWidth: 0.8) }
        case 1:
            Rectangle()
                .fill(color)
                .overlay { Rectangle().stroke(ClubhouseTheme.ink.opacity(0.42), lineWidth: 0.8) }
        case 2:
            TriangleShape()
                .fill(color)
                .overlay { TriangleShape().stroke(ClubhouseTheme.ink.opacity(0.42), lineWidth: 0.8) }
        default:
            Rectangle()
                .fill(color)
                .overlay { Rectangle().stroke(ClubhouseTheme.ink.opacity(0.42), lineWidth: 0.8) }
                .rotationEffect(.degrees(45))
                .scaleEffect(0.72)
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

private struct BauhausArcShape: Shape {
    let start: CGFloat
    let end: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
            .trimmedPath(from: start, to: end)
    }
}

struct BauhausStarburst: View {
    var color: Color = ClubhouseTheme.red
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: size, height: max(size * 0.035, 1.1))
                    .rotationEffect(.degrees(Double(index) * 22.5))
            }

            Circle()
                .fill(ClubhouseTheme.paperCard)
                .frame(width: size * 0.15, height: size * 0.15)
                .overlay { Circle().stroke(color, lineWidth: max(1, size * 0.035)) }
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
            var x: CGFloat = 2
            var column = 0
            while x < size.width {
                var y: CGFloat = column.isMultiple(of: 2) ? 2 : spacing / 2
                while y < size.height {
                    let dotSize = max(spacing * 0.18, 1.25)
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize))
                    context.fill(dot, with: .color(color.opacity(0.34)))
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
        PipCountGeometricArtwork(scene: .scoring)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(accent)
                    .frame(width: 14, height: 14)
                    .padding(8)
            }
    }
}

struct BauhausBlocksArtwork: View {
    var compact = false

    var body: some View {
        PipCountGeometricArtwork(scene: compact ? .homeEmpty : .home)
    }
}

// MARK: - Kinetic screen artwork

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

private enum BauhausComposition {
    case skyline
    case sparseSkyline
    case orbit
    case hub
    case calibration
    case score
    case celebration
    case unlimited
}

struct PipCountGeometricArtwork: View {
    let scene: PipCountArtworkScene
    var ambientMotion = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pipCountPageIsExiting) private var pageIsExiting
    @State private var appeared = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !ambientMotion)) { timeline in
            GeometryReader { proxy in
                KineticBauhausComposition(
                    composition: composition,
                    scene: scene,
                    size: proxy.size,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    active: appeared && !pageIsExiting,
                    reduceMotion: reduceMotion
                )
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(AppMotion.artEntrance) {
                    appeared = true
                }
            }
        }
        .onDisappear {
            appeared = false
        }
        .accessibilityHidden(true)
    }

    private var composition: BauhausComposition {
        switch scene {
        case .home, .onboardingHistory:
            return .skyline
        case .homeEmpty:
            return .sparseSkyline
        case .gamePicker:
            return .orbit
        case .playerSetup, .roster, .onboardingSetup:
            return .hub
        case .gameSettings:
            return .calibration
        case .handwriting, .scoring, .onboardingScore:
            return .score
        case .gameOver:
            return .celebration
        case .paywall:
            return .unlimited
        }
    }
}

private struct KineticBauhausComposition: View {
    let composition: BauhausComposition
    let scene: PipCountArtworkScene
    let size: CGSize
    let time: TimeInterval
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            faintConstructionLines

            switch composition {
            case .skyline:
                skyline(sparse: false)
            case .sparseSkyline:
                skyline(sparse: true)
            case .orbit:
                orbit
            case .hub:
                hub
            case .calibration:
                calibration
            case .score:
                score
            case .celebration:
                celebration
            case .unlimited:
                unlimited
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .drawingGroup()
    }

    private var faintConstructionLines: some View {
        ZStack {
            Circle()
                .stroke(ClubhouseTheme.ink.opacity(0.18), lineWidth: 1)
                .frame(width: min(size.width, size.height) * 0.74)
                .position(x: size.width * 0.50, y: size.height * 0.52)
                .artElement(active: active, index: 0, entry: CGSize(width: 0, height: 14), scale: 0.86)

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.66))
                path.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.66))
                path.move(to: CGPoint(x: size.width * 0.51, y: size.height * 0.12))
                path.addLine(to: CGPoint(x: size.width * 0.51, y: size.height * 0.90))
            }
            .stroke(ClubhouseTheme.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
            .artElement(active: active, index: 0, entry: CGSize(width: 0, height: 8), scale: 0.94)
        }
    }

    @ViewBuilder
    private func skyline(sparse: Bool) -> some View {
        let drift = wave(phase: 0.2, amplitude: 4)

        ZStack {
            BauhausArcShape(start: 0.50, end: 0.83)
                .stroke(ClubhouseTheme.blue, style: StrokeStyle(lineWidth: max(18, size.width * 0.075), lineCap: .butt))
                .frame(width: size.width * 0.62, height: size.width * 0.62)
                .position(x: size.width * 0.27, y: size.height * 0.72)
                .rotationEffect(.degrees(-12))
                .artElement(active: active, index: 1, entry: CGSize(width: -38, height: 25), rotation: -18, scale: 0.72)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * (sparse ? 0.23 : 0.27))
                .position(x: size.width * 0.62, y: size.height * 0.36 + drift)
                .artElement(active: active, index: 2, entry: CGSize(width: 0, height: -34), scale: 0.54)

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: size.width * 0.15, height: size.height * (sparse ? 0.36 : 0.53))
                .position(x: size.width * 0.51, y: size.height * 0.61)
                .artElement(active: active, index: 3, entry: CGSize(width: 0, height: 48), scale: 0.72)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.14, height: size.height * 0.29)
                .position(x: size.width * 0.67, y: size.height * 0.71)
                .artElement(active: active, index: 4, entry: CGSize(width: 0, height: 50), scale: 0.72)

            if !sparse {
                Rectangle()
                    .fill(ClubhouseTheme.ink)
                    .frame(width: size.width * 0.15, height: size.height * 0.43)
                    .position(x: size.width * 0.80, y: size.height * 0.64)
                    .artElement(active: active, index: 5, entry: CGSize(width: 0, height: 56), scale: 0.68)
            }

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: size.width * 0.10, height: size.width * 0.10)
                .rotationEffect(.degrees(45 + wave(phase: 1.1, amplitude: 2)))
                .position(x: size.width * 0.82, y: size.height * 0.78)
                .artElement(active: active, index: 6, entry: CGSize(width: 28, height: 20), rotation: 24, scale: 0.42)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.58, height: max(8, size.height * 0.055))
                .position(x: size.width * 0.67, y: size.height * 0.69)
                .artElement(active: active, index: 7, entry: CGSize(width: 34, height: 0), scale: 0.60)

            BauhausStarburst(color: ClubhouseTheme.blue, size: min(size.width, size.height) * 0.14)
                .position(x: size.width * 0.30, y: size.height * 0.27)
                .rotationEffect(.degrees(wave(phase: 0.8, amplitude: 8)))
                .artElement(active: active, index: 8, entry: CGSize(width: -18, height: -18), rotation: -20, scale: 0.35)

            if !sparse {
                BauhausStarburst(color: ClubhouseTheme.red, size: min(size.width, size.height) * 0.13)
                    .position(x: size.width * 0.83, y: size.height * 0.24)
                    .rotationEffect(.degrees(-wave(phase: 2.1, amplitude: 8)))
                    .artElement(active: active, index: 9, entry: CGSize(width: 22, height: -20), rotation: 20, scale: 0.35)
            }

            BauhausHalftone(color: ClubhouseTheme.ink, spacing: 9)
                .frame(width: size.width * 0.20, height: size.height * 0.20)
                .position(x: size.width * 0.27, y: size.height * 0.77)
                .artElement(active: active, index: 9, entry: CGSize(width: -18, height: 8), scale: 0.70)
        }
    }

    private var orbit: some View {
        ZStack {
            BauhausArcShape(start: 0.12, end: 0.86)
                .stroke(ClubhouseTheme.blue, style: StrokeStyle(lineWidth: max(22, size.width * 0.09), lineCap: .butt))
                .frame(width: size.width * 0.58, height: size.width * 0.58)
                .rotationEffect(.degrees(-24 + wave(phase: 0.1, amplitude: 4)))
                .position(x: size.width * 0.44, y: size.height * 0.53)
                .artElement(active: active, index: 1, entry: CGSize(width: -35, height: 0), rotation: -34, scale: 0.65)

            Rectangle()
                .fill(ClubhouseTheme.ink)
                .frame(width: max(10, size.width * 0.055), height: size.height * 0.58)
                .rotationEffect(.degrees(-35 + wave(phase: 0.5, amplitude: 1.5)))
                .position(x: size.width * 0.56, y: size.height * 0.48)
                .artElement(active: active, index: 2, entry: CGSize(width: 0, height: -42), rotation: -18, scale: 0.62)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * 0.24)
                .position(x: size.width * 0.72, y: size.height * 0.31 + wave(phase: 0.9, amplitude: 5))
                .artElement(active: active, index: 3, entry: CGSize(width: 30, height: -28), scale: 0.45)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.19, height: size.width * 0.19)
                .rotationEffect(.degrees(45 + wave(phase: 1.6, amplitude: 3)))
                .position(x: size.width * 0.70, y: size.height * 0.68)
                .artElement(active: active, index: 4, entry: CGSize(width: 28, height: 26), rotation: 28, scale: 0.42)

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: size.width * 0.095, height: size.width * 0.095)
                .rotationEffect(.degrees(45 - wave(phase: 2.3, amplitude: 4)))
                .position(x: size.width * 0.38, y: size.height * 0.22)
                .artElement(active: active, index: 5, entry: CGSize(width: -20, height: -24), rotation: -28, scale: 0.36)

            BauhausStarburst(color: ClubhouseTheme.red, size: min(size.width, size.height) * 0.12)
                .position(x: size.width * 0.29, y: size.height * 0.74)
                .rotationEffect(.degrees(wave(phase: 1.3, amplitude: 8)))
                .artElement(active: active, index: 6, entry: CGSize(width: -24, height: 18), rotation: -20, scale: 0.30)
        }
    }

    private var hub: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                let angle = Double(index) * .pi / 2 - .pi / 4
                let radiusX = size.width * 0.27
                let radiusY = size.height * 0.27
                let x = size.width * 0.50 + CGFloat(cos(angle)) * radiusX
                let y = size.height * 0.51 + CGFloat(sin(angle)) * radiusY

                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.51))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                .stroke(index.isMultiple(of: 2) ? ClubhouseTheme.blue : ClubhouseTheme.red, lineWidth: max(4, size.width * 0.018))
                .artElement(active: active, index: index + 1, entry: .zero, scale: 0.25)
            }

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * 0.31)
                .overlay {
                    BauhausStarburst(color: ClubhouseTheme.paperCard, size: size.width * 0.18)
                }
                .overlay {
                    Circle().stroke(ClubhouseTheme.ink, lineWidth: max(4, size.width * 0.018))
                }
                .position(x: size.width * 0.50, y: size.height * 0.51 + wave(phase: 0.4, amplitude: 3))
                .artElement(active: active, index: 5, entry: CGSize(width: 0, height: 28), scale: 0.42)

            Circle()
                .fill(ClubhouseTheme.blue)
                .frame(width: size.width * 0.15)
                .position(x: size.width * 0.24, y: size.height * 0.25 + wave(phase: 0.8, amplitude: 4))
                .artElement(active: active, index: 2, entry: CGSize(width: -28, height: -24), scale: 0.30)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.15, height: size.width * 0.15)
                .position(x: size.width * 0.76, y: size.height * 0.25 + wave(phase: 1.4, amplitude: 4))
                .artElement(active: active, index: 3, entry: CGSize(width: 28, height: -24), rotation: 12, scale: 0.30)

            TriangleShape()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * 0.16, height: size.width * 0.15)
                .position(x: size.width * 0.25, y: size.height * 0.76 + wave(phase: 2.0, amplitude: 4))
                .artElement(active: active, index: 4, entry: CGSize(width: -26, height: 26), rotation: -10, scale: 0.30)

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: size.width * 0.12, height: size.width * 0.12)
                .rotationEffect(.degrees(45 + wave(phase: 2.7, amplitude: 3)))
                .position(x: size.width * 0.76, y: size.height * 0.76)
                .artElement(active: active, index: 5, entry: CGSize(width: 26, height: 26), rotation: 24, scale: 0.30)
        }
    }

    private var calibration: some View {
        ZStack {
            BauhausArcShape(start: 0.0, end: 0.52)
                .stroke(ClubhouseTheme.blue, style: StrokeStyle(lineWidth: max(20, size.width * 0.085)))
                .frame(width: size.width * 0.56, height: size.width * 0.56)
                .rotationEffect(.degrees(92))
                .position(x: size.width * 0.77, y: size.height * 0.24)
                .artElement(active: active, index: 1, entry: CGSize(width: 32, height: -28), rotation: 28, scale: 0.54)

            VStack(spacing: size.height * 0.085) {
                calibrationLine(color: ClubhouseTheme.blue, value: 0.78, phase: 0.2)
                calibrationLine(color: ClubhouseTheme.red, value: 0.52, phase: 1.1)
                calibrationLine(color: ClubhouseTheme.green, value: 0.68, phase: 2.2)
            }
            .frame(width: size.width * 0.70)
            .position(x: size.width * 0.46, y: size.height * 0.64)
            .artElement(active: active, index: 2, entry: CGSize(width: -24, height: 24), scale: 0.76)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * 0.21)
                .position(x: size.width * 0.62, y: size.height * 0.29 + wave(phase: 0.7, amplitude: 4))
                .artElement(active: active, index: 3, entry: CGSize(width: 0, height: -30), scale: 0.40)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.20, height: size.width * 0.20)
                .rotationEffect(.degrees(wave(phase: 1.6, amplitude: 2)))
                .position(x: size.width * 0.80, y: size.height * 0.24)
                .artElement(active: active, index: 4, entry: CGSize(width: 24, height: -24), rotation: 12, scale: 0.38)

            BauhausStarburst(color: ClubhouseTheme.red, size: min(size.width, size.height) * 0.12)
                .position(x: size.width * 0.29, y: size.height * 0.23)
                .artElement(active: active, index: 5, entry: CGSize(width: -22, height: -18), rotation: -16, scale: 0.32)
        }
    }

    private func calibrationLine(color: Color, value: CGFloat, phase: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(ClubhouseTheme.ink.opacity(0.17))
                    .frame(height: 2)

                Rectangle()
                    .fill(color)
                    .frame(width: proxy.size.width * value, height: 6)

                Circle()
                    .fill(ClubhouseTheme.paperCard)
                    .overlay { Circle().stroke(ClubhouseTheme.ink, lineWidth: 2) }
                    .frame(width: 22, height: 22)
                    .offset(x: proxy.size.width * value - 11 + wave(phase: phase, amplitude: 2))
            }
        }
        .frame(height: 24)
    }

    private var score: some View {
        ZStack {
            BauhausArcShape(start: 0.50, end: 0.76)
                .stroke(ClubhouseTheme.blue, style: StrokeStyle(lineWidth: max(18, size.width * 0.072), lineCap: .butt))
                .frame(width: size.width * 0.67, height: size.width * 0.67)
                .position(x: size.width * 0.25, y: size.height * 0.68)
                .rotationEffect(.degrees(-10))
                .artElement(active: active, index: 1, entry: CGSize(width: -36, height: 20), rotation: -22, scale: 0.64)

            HStack(alignment: .bottom, spacing: size.width * 0.035) {
                scoreBar(color: ClubhouseTheme.blue, height: 0.37, index: 2)
                scoreBar(color: ClubhouseTheme.red, height: 0.53, index: 3)
                scoreBar(color: ClubhouseTheme.ink, height: 0.70, index: 4)
                scoreBar(color: ClubhouseTheme.blue, height: 0.86, index: 5)
                scoreBar(color: ClubhouseTheme.green, height: 0.61, index: 6)
            }
            .frame(width: size.width * 0.64, height: size.height * 0.68, alignment: .bottom)
            .position(x: size.width * 0.60, y: size.height * 0.59)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * 0.25)
                .position(x: size.width * 0.35, y: size.height * 0.34 + wave(phase: 0.7, amplitude: 4))
                .artElement(active: active, index: 2, entry: CGSize(width: -22, height: -28), scale: 0.42)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.68, height: max(8, size.height * 0.052))
                .position(x: size.width * 0.59, y: size.height * 0.67)
                .artElement(active: active, index: 7, entry: CGSize(width: 34, height: 0), scale: 0.62)

            BauhausStarburst(color: ClubhouseTheme.blue, size: min(size.width, size.height) * 0.13)
                .position(x: size.width * 0.27, y: size.height * 0.18)
                .rotationEffect(.degrees(wave(phase: 1.1, amplitude: 8)))
                .artElement(active: active, index: 8, entry: CGSize(width: -20, height: -18), rotation: -18, scale: 0.32)
        }
    }

    private func scoreBar(color: Color, height: CGFloat, index: Int) -> some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: size.height * height)
            .artElement(active: active, index: index, entry: CGSize(width: 0, height: 52), scale: 0.54)
    }

    private var celebration: some View {
    ZStack {
        skyline(sparse: false)
            .scaleEffect(0.88)
            .offset(y: size.height * 0.06)

        ForEach(0..<8, id: \.self) { index in
            celebrationConfetti(index: index)
        }
    }
}

private func celebrationConfetti(index: Int) -> some View {
    let colors: [Color] = [
        ClubhouseTheme.red,
        ClubhouseTheme.blue,
        ClubhouseTheme.yellow,
        ClubhouseTheme.green
    ]
    let xPosition = size.width * (0.12 + CGFloat(index) * 0.105)
    let baseY = size.height * (0.12 + CGFloat(index % 3) * 0.08)
    let yPosition = baseY + wave(phase: Double(index) * 0.7, amplitude: 7)
    let pieceWidth = max(5, size.width * 0.018)
    let pieceHeight = max(12, size.height * 0.055)
    let pieceRotation = Double(index * 24) + wave(phase: Double(index), amplitude: 8)
    let entryRotation = Double(index * 12)
    let color = colors[index % colors.count]

    return Rectangle()
        .fill(color)
        .frame(width: pieceWidth, height: pieceHeight)
        .rotationEffect(.degrees(pieceRotation))
        .position(x: xPosition, y: yPosition)
        .artElement(
            active: active,
            index: index + 2,
            entry: CGSize(width: 0, height: -28),
            rotation: entryRotation,
            scale: 0.22
        )
}

private var unlimited: some View {
        ZStack {
            BauhausArcShape(start: 0.06, end: 0.94)
                .stroke(ClubhouseTheme.blue, style: StrokeStyle(lineWidth: max(20, size.width * 0.075), lineCap: .butt))
                .frame(width: size.width * 0.48, height: size.height * 0.50)
                .rotationEffect(.degrees(-42 + wave(phase: 0.3, amplitude: 3)))
                .position(x: size.width * 0.37, y: size.height * 0.51)
                .artElement(active: active, index: 1, entry: CGSize(width: -32, height: 0), rotation: -30, scale: 0.56)

            BauhausArcShape(start: 0.06, end: 0.94)
                .stroke(ClubhouseTheme.red, style: StrokeStyle(lineWidth: max(20, size.width * 0.075), lineCap: .butt))
                .frame(width: size.width * 0.48, height: size.height * 0.50)
                .rotationEffect(.degrees(138 - wave(phase: 1.2, amplitude: 3)))
                .position(x: size.width * 0.63, y: size.height * 0.51)
                .artElement(active: active, index: 2, entry: CGSize(width: 32, height: 0), rotation: 30, scale: 0.56)

            Rectangle()
                .fill(ClubhouseTheme.ink)
                .frame(width: size.width * 0.12, height: size.height * 0.58)
                .position(x: size.width * 0.50, y: size.height * 0.51)
                .artElement(active: active, index: 3, entry: CGSize(width: 0, height: 38), scale: 0.62)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: size.width * 0.21)
                .position(x: size.width * 0.72, y: size.height * 0.28 + wave(phase: 0.8, amplitude: 4))
                .artElement(active: active, index: 4, entry: CGSize(width: 24, height: -24), scale: 0.36)

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: size.width * 0.10, height: size.width * 0.10)
                .rotationEffect(.degrees(45 + wave(phase: 2.0, amplitude: 4)))
                .position(x: size.width * 0.78, y: size.height * 0.76)
                .artElement(active: active, index: 5, entry: CGSize(width: 24, height: 20), rotation: 25, scale: 0.32)

            BauhausStarburst(color: ClubhouseTheme.paperCard, size: min(size.width, size.height) * 0.13)
                .position(x: size.width * 0.50, y: size.height * 0.32)
                .rotationEffect(.degrees(wave(phase: 1.7, amplitude: 9)))
                .artElement(active: active, index: 6, entry: CGSize(width: 0, height: -18), rotation: -18, scale: 0.30)
        }
    }

    private func wave(phase: Double, amplitude: CGFloat) -> CGFloat {
        guard !reduceMotion else { return 0 }
        return CGFloat(sin(time * 0.72 + phase)) * amplitude
    }
}

private struct ArtElementModifier: ViewModifier {
    let active: Bool
    let index: Int
    let entry: CGSize
    let rotation: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .offset(active ? .zero : entry)
            .rotationEffect(.degrees(active ? 0 : rotation))
            .scaleEffect(active ? 1 : scale)
            .blur(radius: active ? 0 : 1.8)
            .animation(
                active
                    ? AppMotion.artEntrance.delay(min(Double(index) * 0.045, 0.34))
                    : AppMotion.artExit,
                value: active
            )
    }
}

private extension View {
    func artElement(
        active: Bool,
        index: Int,
        entry: CGSize,
        rotation: Double = 0,
        scale: CGFloat = 0.76
    ) -> some View {
        modifier(
            ArtElementModifier(
                active: active,
                index: index,
                entry: entry,
                rotation: rotation,
                scale: scale
            )
        )
    }
}
