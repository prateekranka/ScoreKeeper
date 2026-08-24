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
                        .fill(ClubhouseTheme.paperShadow.opacity(isInteractive ? 0.78 : 0.44))
                        .offset(x: isInteractive ? 4 : 2, y: isInteractive ? 7 : 4)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ClubhouseTheme.paperCard)
                        .shadow(
                            color: ClubhouseTheme.ink.opacity(isInteractive ? 0.10 : 0.06),
                            radius: isInteractive ? 18 : 12,
                            x: 0,
                            y: isInteractive ? 9 : 6
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ruleStrong.opacity(0.42), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(cornerRadius - 3, 0), style: .continuous)
                    .inset(by: 3)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
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

// MARK: - Score rows and game-night pieces

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
                        .font(AppFonts.body.weight(.medium))
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
            .background(ClubhouseTheme.lacquer.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(ClubhouseTheme.lacquer.opacity(0.72), style: StrokeStyle(lineWidth: 1.5, dash: [5, 2]))
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
            .font(AppFonts.caption)
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
                .font(.title3.weight(.semibold))
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

// MARK: - Illustrated asset family

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

// The original public type name remains for feature compatibility, but these
// now read as friendly tabletop pieces rather than strict Bauhaus primitives.
struct BauhausPlayerShape: View {
    let colorIndex: Int
    var size: CGFloat

    private var color: Color {
        PlayerColors.color(for: colorIndex)
    }

    var body: some View {
        ZStack {
            switch colorIndex % 4 {
            case 0:
                PokerChipShape()
                    .fill(color)
                    .overlay {
                        PokerChipShape()
                            .stroke(ClubhouseTheme.ruleStrong.opacity(0.68), lineWidth: max(size * 0.045, 0.75))
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.62), lineWidth: max(size * 0.075, 1))
                            .padding(size * 0.22)
                    }
            case 1:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(color)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(ClubhouseTheme.ruleStrong.opacity(0.68), lineWidth: max(size * 0.045, 0.75))
                    }
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(0.82))
                            .frame(width: size * 0.24, height: size * 0.24)
                    }
            case 2:
                PawnPieceShape()
                    .fill(color)
                    .overlay {
                        PawnPieceShape()
                            .stroke(ClubhouseTheme.ruleStrong.opacity(0.68), lineWidth: max(size * 0.045, 0.75))
                    }
            default:
                TicketPieceShape()
                    .fill(color)
                    .overlay {
                        TicketPieceShape()
                            .stroke(ClubhouseTheme.ruleStrong.opacity(0.68), lineWidth: max(size * 0.045, 0.75))
                    }
                    .rotationEffect(.degrees(-8))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: ClubhouseTheme.ink.opacity(0.10), radius: size * 0.08, y: size * 0.05)
    }
}

private struct PokerChipShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

private struct PawnPieceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let headRadius = rect.width * 0.23
        path.addEllipse(in: CGRect(
            x: rect.midX - headRadius,
            y: rect.minY,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.14, y: rect.minY + rect.height * 0.38))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.34, y: rect.maxY * 0.82),
            control: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY * 0.63)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.midX - rect.width * 0.31, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.34, y: rect.maxY * 0.82),
            control: CGPoint(x: rect.midX + rect.width * 0.31, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.14, y: rect.minY + rect.height * 0.38),
            control: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY * 0.63)
        )
        path.closeSubpath()
        return path
    }
}

private struct TicketPieceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: rect.width * 0.24)
        let notch = rect.width * 0.16
        path.addEllipse(in: CGRect(x: rect.minX - notch / 2, y: rect.midY - notch / 2, width: notch, height: notch))
        path.addEllipse(in: CGRect(x: rect.maxX - notch / 2, y: rect.midY - notch / 2, width: notch, height: notch))
        return path
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
                    .frame(width: size, height: max(size * 0.05, 1.25))
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            Circle()
                .fill(color)
                .frame(width: size * 0.22, height: size * 0.22)
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
        PipCountAssetArtwork(asset: .scoreEmblem)
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
        PipCountAssetArtwork(asset: .hero, contentMode: compact ? .fit : .fill)
            .clipped()
    }
}

// MARK: - Screen artwork router

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
    @State private var isPresented = false

    var body: some View {
        ZStack {
            PipCountAssetArtwork(asset: asset)
                .scaleEffect(isPresented || reduceMotion ? 1 : 0.94)
                .rotationEffect(.degrees(isPresented || reduceMotion ? restingRotation : enteringRotation))
                .offset(y: isPresented || reduceMotion ? 0 : 8)

            sceneAccent
        }
        .padding(scenePadding)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.celebration, value: isPresented)
        .onAppear { isPresented = true }
        .accessibilityHidden(true)
    }

    private var asset: PipCountIllustrationAsset {
        switch scene {
        case .home:
            return .hero
        case .homeEmpty:
            return .emptyState
        case .gamePicker:
            return .hero
        case .playerSetup, .roster, .onboardingSetup:
            return .crewEmblem
        case .gameSettings, .handwriting, .scoring, .onboardingScore:
            return .scoreEmblem
        case .gameOver, .onboardingHistory:
            return .celebrationEmblem
        case .paywall:
            return .unlimitedEmblem
        }
    }

    private var restingRotation: Double {
        switch scene {
        case .gamePicker: return -1.4
        case .playerSetup, .roster: return 1.2
        case .gameOver: return -0.8
        default: return 0
        }
    }

    private var enteringRotation: Double {
        restingRotation + (restingRotation >= 0 ? 3.5 : -3.5)
    }

    private var scenePadding: CGFloat {
        switch scene {
        case .home, .homeEmpty: return 2
        case .paywall: return 4
        default: return 8
        }
    }

    @ViewBuilder
    private var sceneAccent: some View {
        switch scene {
        case .gamePicker:
            HStack(spacing: 7) {
                MiniGameCard(color: ClubhouseTheme.blue, symbol: "number")
                MiniGameCard(color: ClubhouseTheme.lacquer, symbol: "dice.fill")
                MiniGameCard(color: ClubhouseTheme.green, symbol: "fork.knife")
            }
            .scaleEffect(0.58)
            .offset(x: 56, y: 65)
        case .gameSettings:
            VStack(spacing: 7) {
                SettingTick(color: ClubhouseTheme.blue, value: 0.70)
                SettingTick(color: ClubhouseTheme.lacquer, value: 0.45)
                SettingTick(color: ClubhouseTheme.green, value: 0.82)
            }
            .frame(width: 92)
            .offset(x: 60, y: 54)
        case .handwriting:
            Text("12")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(ClubhouseTheme.ink)
                .rotationEffect(.degrees(-7))
                .offset(x: 48, y: 26)
        case .scoring:
            HStack(spacing: 6) {
                BauhausPlayerShape(colorIndex: 0, size: 22)
                BauhausPlayerShape(colorIndex: 1, size: 22)
                BauhausPlayerShape(colorIndex: 2, size: 22)
            }
            .offset(x: -48, y: 72)
        case .gameOver:
            BauhausStarburst(color: ClubhouseTheme.blue, size: 30)
                .offset(x: 77, y: -63)
        case .paywall:
            Image(systemName: "infinity")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(ClubhouseTheme.onPrimary)
                .padding(14)
                .background(ClubhouseTheme.blue, in: Circle())
                .offset(x: 74, y: 64)
        default:
            EmptyView()
        }
    }
}

private struct MiniGameCard: View {
    let color: Color
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 54, height: 68)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ink.opacity(0.65), lineWidth: 2)
            }
            .shadow(color: ClubhouseTheme.ink.opacity(0.12), radius: 4, y: 3)
    }
}

private struct SettingTick: View {
    let color: Color
    let value: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ClubhouseTheme.paperSunken)
                Capsule().fill(color).frame(width: proxy.size.width * value)
                Circle()
                    .fill(ClubhouseTheme.paperCard)
                    .overlay { Circle().stroke(ClubhouseTheme.ink.opacity(0.42), lineWidth: 1) }
                    .frame(width: proxy.size.height, height: proxy.size.height)
                    .offset(x: max(proxy.size.width * value - proxy.size.height, 0))
            }
        }
        .frame(height: 13)
    }
}
