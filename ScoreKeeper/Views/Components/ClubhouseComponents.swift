import SwiftUI

struct ScorecardSurface<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium
    var isInteractive = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ClubhouseTheme.paperCard)
                    .shadow(
                        color: isInteractive ? ClubhouseTheme.paperShadow : ClubhouseTheme.ink.opacity(0.035),
                        radius: isInteractive ? 0 : 10,
                        x: isInteractive ? 3 : 0,
                        y: isInteractive ? 4 : 5
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1.35)
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
        VStack(spacing: 6) {
            HStack(spacing: AppTheme.spacingSmall) {
                stepButton(systemImage: "minus", delta: -step, identifier: "decrement", label: "Decrease score")

                VStack(spacing: 0) {
                    Text("RD")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)

                    Text(roundScoreText)
                        .font(AppFonts.scoreMedium)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(ClubhouseTheme.ink)
                }
                .frame(minWidth: 60)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifierPrefix + "score")
                .accessibilityLabel("Score \(value)")

                stepButton(systemImage: "plus", delta: step, identifier: "increment", label: "Increase score")
            }

            HStack(spacing: 6) {
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

    private func quickButton(delta: Int) -> some View {
        Button {
            apply(delta)
        } label: {
            Text("+\(delta)")
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(minWidth: 44, minHeight: 44)
                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
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

// MARK: - PipCount Geometry

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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .light {
            PipCountAssetArtwork(asset: .scoreEmblem)
        } else {
            legacyArtwork
        }
    }

    private var legacyArtwork: some View {
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .light {
            PipCountAssetArtwork(asset: .hero, contentMode: .fill)
                .clipped()
        } else {
            legacyArtwork
        }
    }

    private var legacyArtwork: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width / 5, proxy.size.height / 4)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(ClubhouseTheme.yellow)
                    .frame(width: unit * 2.25, height: unit * 2.25)
                    .offset(x: -unit * 2.15, y: -unit * 0.05)

                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(ClubhouseTheme.blue, lineWidth: unit * 0.78)
                    .rotationEffect(.degrees(90))
                    .frame(width: unit * 3.2, height: unit * 3.2)
                    .offset(x: -unit * 0.2, y: -unit * 0.65)

                HStack(alignment: .bottom, spacing: 0) {
                    block(height: unit * 1.10, color: ClubhouseTheme.blue)
                    block(height: unit * 1.75, color: ClubhouseTheme.red)
                    block(height: unit * 2.50, color: ClubhouseTheme.ink)
                    block(height: unit * 3.20, color: ClubhouseTheme.blue)
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

// MARK: - Screen-specific geometric artwork

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

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 240, proxy.size.height / 200)

            sceneArtwork
                .frame(width: 240, height: 200)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sceneArtwork: some View {
        switch scene {
        case .home:
            ZStack {
                draftingGrid
                Circle().fill(ClubhouseTheme.yellow).frame(width: 112, height: 112).offset(x: -64, y: 36)
                BauhausBars(heights: [54, 86, 128, 164, 104])
                    .frame(width: 196, height: 164)
                    .offset(x: 18, y: 18)
                BauhausStarburst(color: ClubhouseTheme.red, size: 42).offset(x: 82, y: -72)
                BauhausStarburst(color: ClubhouseTheme.blue, size: 28).offset(x: -80, y: -62)
            }
        case .homeEmpty:
            ZStack {
                draftingGrid
                Circle().fill(ClubhouseTheme.blue).frame(width: 118, height: 118).offset(x: -28, y: 18)
                Circle().fill(ClubhouseTheme.yellow).frame(width: 64, height: 64).offset(x: 64, y: -42)
                Rectangle().fill(ClubhouseTheme.red).frame(width: 54, height: 54).offset(x: 76, y: 48)
                Rectangle().fill(ClubhouseTheme.ink).frame(width: 42, height: 88).offset(x: 32, y: 54)
                BauhausPlayerShape(colorIndex: 3, size: 38).offset(x: -4, y: 70)
            }
        case .gamePicker:
            GamePickerOrbitArtwork()
        case .playerSetup:
            CrewConstellationArtwork()
        case .gameSettings:
            GameCalibrationArtwork()
        case .handwriting:
            HandwrittenNumeralArtwork()
        case .scoring:
            ZStack {
                draftingGrid
                Circle().trim(from: 0, to: 0.75).stroke(ClubhouseTheme.blue, lineWidth: 34)
                    .frame(width: 132, height: 132).offset(x: 42, y: -16)
                Circle().fill(ClubhouseTheme.red).frame(width: 42, height: 42).offset(x: 42, y: -16)
                Rectangle().fill(ClubhouseTheme.yellow).frame(width: 64, height: 80).offset(x: 70, y: 58)
                StairStepArtwork().fill(ClubhouseTheme.ink).frame(width: 112, height: 104).offset(x: 54, y: 52)
                BauhausHalftone(color: ClubhouseTheme.ink, spacing: 6).frame(width: 58, height: 74).offset(x: -76, y: 38)
            }
        case .gameOver:
            ZStack {
                draftingGrid
                QuadrantDisk().frame(width: 150, height: 150).offset(x: 42, y: -2)
                Rectangle().fill(ClubhouseTheme.ink).frame(width: 56, height: 108).offset(x: 60, y: 60)
                BauhausStarburst(color: ClubhouseTheme.blue, size: 32).offset(x: 88, y: -76)
                BauhausStarburst(color: ClubhouseTheme.yellow, size: 30).offset(x: -62, y: 58)
                BauhausStarburst(color: ClubhouseTheme.ink, size: 24).offset(x: -70, y: -20)
            }
        case .paywall:
            UnlockedGateArtwork()
        case .onboardingScore:
            ZStack {
                draftingGrid
                Circle().trim(from: 0.25, to: 0.75).stroke(ClubhouseTheme.blue, lineWidth: 34)
                    .rotationEffect(.degrees(90)).frame(width: 144, height: 144).offset(x: 64, y: 4)
                Circle().fill(ClubhouseTheme.red).frame(width: 40, height: 40).offset(x: 64, y: 4)
                BauhausHalftone(color: ClubhouseTheme.ink, spacing: 6).frame(width: 70, height: 92).offset(x: -78, y: 46)
                BauhausStarburst(color: ClubhouseTheme.blue, size: 40).offset(x: -76, y: -62)
            }
        case .onboardingSetup:
            ZStack {
                draftingGrid
                Circle().fill(ClubhouseTheme.yellow).frame(width: 110, height: 110).offset(x: -58, y: 42)
                BauhausBars(heights: [46, 80, 120, 158, 96]).frame(width: 184, height: 158).offset(x: 26, y: 20)
                HStack(spacing: 18) {
                    BauhausPlayerShape(colorIndex: 0, size: 28)
                    BauhausPlayerShape(colorIndex: 1, size: 28)
                    BauhausPlayerShape(colorIndex: 2, size: 28)
                    BauhausPlayerShape(colorIndex: 3, size: 28)
                }
                .offset(y: 78)
                BauhausStarburst(color: ClubhouseTheme.red, size: 38).offset(x: 84, y: -70)
            }
        case .onboardingHistory:
            ZStack {
                draftingGrid
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill([ClubhouseTheme.ink, ClubhouseTheme.red, ClubhouseTheme.yellow, ClubhouseTheme.blue][index])
                        .frame(width: 126, height: 144)
                        .offset(x: CGFloat(index * 10) - 2, y: CGFloat(index * -8) + 24)
                }
                RoundedRectangle(cornerRadius: 12).fill(ClubhouseTheme.paperCard).frame(width: 126, height: 144).offset(x: -18, y: -8)
                Circle().fill(ClubhouseTheme.blue).frame(width: 72, height: 72).offset(x: -74, y: 54)
                BauhausStarburst(color: ClubhouseTheme.paperCard, size: 38).offset(x: -74, y: 54)
                BauhausStarburst(color: ClubhouseTheme.red, size: 34).offset(x: 84, y: -66)
            }
        case .roster:
            ZStack {
                draftingGrid
                Circle().fill(ClubhouseTheme.blue).frame(width: 92, height: 92).offset(x: 46, y: -6)
                Circle().fill(ClubhouseTheme.yellow).frame(width: 64, height: 64).offset(x: -8, y: -42)
                StairStepArtwork().fill(ClubhouseTheme.ink).frame(width: 106, height: 100).offset(x: -42, y: 32)
                Rectangle().fill(ClubhouseTheme.red).frame(width: 48, height: 68).offset(x: -66, y: 44)
                SemiBowl().fill(ClubhouseTheme.ink).frame(width: 100, height: 54).offset(x: 56, y: 58)
                BauhausPlayerShape(colorIndex: 3, size: 28).offset(x: 88, y: -52)
            }
        }
    }

    private var draftingGrid: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 18, y: 100)); path.addLine(to: CGPoint(x: 222, y: 100))
                path.move(to: CGPoint(x: 120, y: 10)); path.addLine(to: CGPoint(x: 120, y: 190))
                path.addEllipse(in: CGRect(x: 42, y: 22, width: 156, height: 156))
            }
            .stroke(ClubhouseTheme.ruleStrong.opacity(0.62), lineWidth: 0.8)

            BauhausHalftone(color: ClubhouseTheme.ink, spacing: 7)
                .frame(width: 54, height: 68)
                .offset(x: 84, y: 48)
        }
    }
}

private struct GamePickerOrbitArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(ClubhouseTheme.blue, lineWidth: 30)
                .frame(width: 146, height: 146)
                .offset(x: -34, y: 12)

            Rectangle()
                .fill(ClubhouseTheme.paper)
                .frame(width: 54, height: 188)
                .offset(x: -2, y: 4)

            Rectangle()
                .fill(ClubhouseTheme.ink)
                .frame(width: 18, height: 176)
                .rotationEffect(.degrees(-34))
                .offset(x: 18, y: -2)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: 78, height: 78)
                .offset(x: 62, y: -42)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(45))
                .offset(x: 66, y: 48)

            BauhausPlayerShape(colorIndex: 3, size: 30)
                .offset(x: -76, y: -68)
        }
    }
}

private struct CrewConstellationArtwork: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 176, height: 5)
                .rotationEffect(.degrees(28))

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 176, height: 5)
                .rotationEffect(.degrees(-28))

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: 94, height: 94)
                .overlay { Circle().stroke(ClubhouseTheme.ink, lineWidth: 5) }

            BauhausPlayerShape(colorIndex: 0, size: 42).offset(x: -72, y: -54)
            BauhausPlayerShape(colorIndex: 1, size: 42).offset(x: 72, y: -54)
            BauhausPlayerShape(colorIndex: 2, size: 42).offset(x: -72, y: 56)
            BauhausPlayerShape(colorIndex: 3, size: 42).offset(x: 72, y: 56)

            BauhausStarburst(color: ClubhouseTheme.paperCard, size: 42)
        }
    }
}

private struct GameCalibrationArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.08, to: 0.86)
                .stroke(ClubhouseTheme.ink, lineWidth: 16)
                .frame(width: 148, height: 148)
                .rotationEffect(.degrees(-38))

            HStack(spacing: 34) {
                sliderRail(color: ClubhouseTheme.blue, knobOffset: -42)
                sliderRail(color: ClubhouseTheme.red, knobOffset: 20)
                sliderRail(color: ClubhouseTheme.yellow, knobOffset: -6)
            }

            Circle()
                .fill(ClubhouseTheme.paperCard)
                .frame(width: 62, height: 62)
                .overlay { Circle().stroke(ClubhouseTheme.ink, lineWidth: 4) }

            BauhausStarburst(color: ClubhouseTheme.blue, size: 34)
            Rectangle().fill(ClubhouseTheme.red).frame(width: 70, height: 6).offset(x: 72, y: 66)
        }
    }

    private func sliderRail(color: Color, knobOffset: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(ClubhouseTheme.ruleStrong).frame(width: 5, height: 150)
            Rectangle().fill(color).frame(width: 30, height: 30).offset(y: knobOffset)
        }
    }
}

private struct HandwrittenNumeralArtwork: View {
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle().fill(ClubhouseTheme.rule).frame(width: 210, height: 1)
                }
            }

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: 122, height: 122)
                .offset(x: -44, y: 4)

            Text("12")
                .font(.system(size: 104, weight: .black, design: .rounded))
                .foregroundStyle(ClubhouseTheme.ink)
                .rotationEffect(.degrees(-7))
                .offset(x: 18, y: -4)

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 150, height: 12)
                .rotationEffect(.degrees(-7))
                .offset(x: 20, y: 70)

            BauhausStarburst(color: ClubhouseTheme.red, size: 32)
                .offset(x: 86, y: -66)
        }
    }
}

private struct UnlockedGateArtwork: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: 108, height: 108)
                .offset(y: -44)

            HStack(alignment: .bottom, spacing: 28) {
                Rectangle().fill(ClubhouseTheme.blue).frame(width: 62, height: 174)
                Rectangle().fill(ClubhouseTheme.ink).frame(width: 62, height: 136)
            }

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 196, height: 18)
                .offset(y: -78)

            BauhausStarburst(color: ClubhouseTheme.paperCard, size: 34)
                .offset(x: -45, y: -116)

            BauhausPlayerShape(colorIndex: 3, size: 34)
                .offset(x: 74, y: -16)
        }
    }
}

private struct BauhausBars: View {
    let heights: [CGFloat]
    private let colors = [ClubhouseTheme.blue, ClubhouseTheme.red, ClubhouseTheme.ink, ClubhouseTheme.blue, ClubhouseTheme.ink]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Rectangle().fill(colors[index % colors.count]).frame(maxWidth: .infinity).frame(height: height)
            }
        }
    }
}

private struct StairStepArtwork: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.maxY * 0.44))
        path.addLine(to: CGPoint(x: rect.width * 0.58, y: rect.maxY * 0.44))
        path.addLine(to: CGPoint(x: rect.width * 0.58, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct BauhausStackedSteps: View {
    var body: some View {
        ZStack {
            StairStepArtwork().fill(ClubhouseTheme.blue).offset(x: -24, y: -18)
            StairStepArtwork().fill(ClubhouseTheme.ink).offset(x: 0, y: 0)
            StairStepArtwork().fill(ClubhouseTheme.red).offset(x: 24, y: 18)
            StairStepArtwork().fill(ClubhouseTheme.yellow).offset(x: 48, y: 36)
        }
    }
}

private struct QuadrantDisk: View {
    var body: some View {
        ZStack {
            Circle().fill(ClubhouseTheme.red)
            Circle().trim(from: 0, to: 0.25).fill(ClubhouseTheme.yellow).rotationEffect(.degrees(-90))
            Circle().trim(from: 0.25, to: 0.5).fill(ClubhouseTheme.blue).rotationEffect(.degrees(-90))
            Circle().trim(from: 0.5, to: 0.75).fill(ClubhouseTheme.ink).rotationEffect(.degrees(-90))
            Circle().fill(ClubhouseTheme.paperCard).frame(width: 72, height: 72)
        }
    }
}

private struct SemiBowl: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.8))
        path.closeSubpath()
        return path
    }
}
