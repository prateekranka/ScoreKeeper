import SwiftUI

// MARK: - Player geometric identity

struct PlayerShapeIcon: View {
    let colorIndex: Int
    var size: CGFloat = 28

    var body: some View {
        let color = PlayerColors.color(for: colorIndex)
        let shape = PlayerColors.shape(for: colorIndex)

        Group {
            switch shape {
            case .circle:
                Circle().fill(color)
            case .square:
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .fill(color)
            case .triangle:
                Image(systemName: "triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(size * 0.08)
            case .diamond:
                Image(systemName: "diamond.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(size * 0.1)
            case .star:
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(size * 0.08)
            case .plus:
                ZStack {
                    Circle().fill(color)
                    Image(systemName: "plus")
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(.white)
                }
            case .capsule:
                Capsule().fill(color)
            case .hexagon:
                Image(systemName: "hexagon.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(size * 0.06)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Status badges

struct StatusPill: View {
    enum Kind {
        case inProgress
        case completed
        case custom(String, Color)

        var label: String {
            switch self {
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .custom(let text, _): return text
            }
        }

        var color: Color {
            switch self {
            case .inProgress: return ClubhouseTheme.bauhausBlue
            case .completed: return ClubhouseTheme.bauhausGreen
            case .custom(_, let color): return color
            }
        }
    }

    let kind: Kind

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(kind.color)
                .frame(width: 7, height: 7)
            Text(kind.label)
                .font(AppFonts.caption.weight(.semibold))
                .foregroundStyle(kind.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(kind.color.opacity(0.10), in: Capsule())
        .overlay {
            Capsule().strokeBorder(kind.color.opacity(0.22), lineWidth: 1)
        }
        .accessibilityLabel(kind.label)
    }
}

// MARK: - Halftone texture

struct HalftoneStrip: View {
    var color: Color = ClubhouseTheme.bauhausBlue
    var intensity: Double = 0.35

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 5
            var y: CGFloat = 0
            while y < size.height + spacing {
                var x: CGFloat = 0
                let progress = y / max(size.height, 1)
                let radius = 0.6 + progress * 1.6
                while x < size.width + spacing {
                    let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(intensity * (0.25 + progress * 0.75))))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

struct BauhausCornerTexture: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HalftoneStrip(color: ClubhouseTheme.bauhausRed, intensity: 0.18)
                    .frame(width: 120, height: 90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .offset(x: -20, y: 10)

                HalftoneStrip(color: ClubhouseTheme.bauhausBlue, intensity: 0.16)
                    .frame(width: 130, height: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 24, y: 16)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

// MARK: - Geometric hero compositions

enum BauhausHeroStyle {
    case home
    case chooseGame
    case addPlayers
    case scoring
    case gameOver
    case players
}

struct BauhausHeroArt: View {
    var style: BauhausHeroStyle = .home
    var height: CGFloat = 120

    var body: some View {
        ZStack {
            switch style {
            case .home:
                homeComposition
            case .chooseGame:
                chooseGameComposition
            case .addPlayers:
                addPlayersComposition
            case .scoring:
                scoringComposition
            case .gameOver:
                gameOverComposition
            case .players:
                playersComposition
            }
        }
        .frame(width: 150, height: height)
        .accessibilityHidden(true)
    }

    private var homeComposition: some View {
        ZStack {
            BauhausGridLines()
            steppedBlocks
                .offset(x: 18, y: 8)
            Circle()
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 46, height: 46)
                .overlay { HalftoneStrip(color: .black, intensity: 0.25).clipShape(Circle()) }
                .offset(x: 48, y: -28)
            BauhausStar(color: ClubhouseTheme.bauhausBlue)
                .frame(width: 22, height: 22)
                .offset(x: -18, y: -36)
            Rectangle()
                .fill(ClubhouseTheme.bauhausRed)
                .frame(width: 14, height: 72)
                .offset(x: -42, y: 6)
        }
    }

    private var chooseGameComposition: some View {
        ZStack {
            BauhausGridLines()
            steppedBlocks
            Circle()
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 58, height: 58)
                .offset(x: 36, y: -8)
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(ClubhouseTheme.bauhausBlue)
                .frame(width: 44, height: 44)
                .offset(x: -28, y: 18)
            BauhausStar(color: ClubhouseTheme.bauhausBlue)
                .frame(width: 18, height: 18)
                .offset(x: 8, y: -42)
        }
    }

    private var addPlayersComposition: some View {
        ZStack {
            BauhausGridLines()
            steppedBlocks
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 54, height: 54)
                .offset(x: 40, y: 10)
            BauhausStar(color: ClubhouseTheme.bauhausBlue)
                .frame(width: 20, height: 20)
                .offset(x: -8, y: -34)
            BauhausStar(color: ClubhouseTheme.bauhausRed, points: 8)
                .frame(width: 26, height: 26)
                .offset(x: 52, y: -28)
        }
    }

    private var scoringComposition: some View {
        ZStack {
            Circle()
                .stroke(ClubhouseTheme.ink.opacity(0.15), lineWidth: 1)
                .frame(width: 88, height: 88)
            Circle()
                .stroke(ClubhouseTheme.ink.opacity(0.2), lineWidth: 1)
                .frame(width: 58, height: 58)
            BauhausStar(color: ClubhouseTheme.bauhausRed)
                .frame(width: 34, height: 34)
                .offset(x: 36, y: -18)
            Circle()
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 36, height: 36)
                .overlay { HalftoneStrip(color: .black, intensity: 0.3).clipShape(Circle()) }
                .offset(x: 44, y: 28)
            RoundedRectangle(cornerRadius: 4)
                .fill(ClubhouseTheme.bauhausBlue)
                .frame(width: 28, height: 48)
                .offset(x: -40, y: 8)
            RoundedRectangle(cornerRadius: 4)
                .fill(ClubhouseTheme.ink)
                .frame(width: 18, height: 34)
                .offset(x: -58, y: 18)
        }
    }

    private var gameOverComposition: some View {
        ZStack {
            BauhausStar(color: ClubhouseTheme.bauhausBlue)
                .frame(width: 28, height: 28)
                .offset(x: -36, y: -28)
            BauhausStar(color: ClubhouseTheme.bauhausRed)
                .frame(width: 18, height: 18)
                .offset(x: 44, y: -34)
            BauhausStar(color: ClubhouseTheme.ink)
                .frame(width: 14, height: 14)
                .offset(x: 18, y: 36)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(ClubhouseTheme.bauhausRed)
                .frame(width: 50, height: 50)
                .offset(x: -18, y: 8)
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(ClubhouseTheme.bauhausBlue)
                .frame(width: 50, height: 50)
                .offset(x: 18, y: 8)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 36, height: 36)
                .offset(x: 40, y: -6)
            RoundedRectangle(cornerRadius: 2)
                .stroke(ClubhouseTheme.ink.opacity(0.35), lineWidth: 1)
                .background {
                    GridPatternFill()
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .frame(width: 34, height: 34)
                .offset(x: -46, y: 28)
        }
    }

    private var playersComposition: some View {
        ZStack {
            BauhausGridLines()
            Circle()
                .fill(ClubhouseTheme.bauhausBlue)
                .frame(width: 42, height: 42)
                .offset(x: -30, y: -10)
            RoundedRectangle(cornerRadius: 4)
                .fill(ClubhouseTheme.bauhausYellow)
                .frame(width: 36, height: 36)
                .offset(x: 10, y: -24)
            RoundedRectangle(cornerRadius: 4)
                .fill(ClubhouseTheme.bauhausRed)
                .frame(width: 22, height: 54)
                .offset(x: 42, y: 8)
            Circle()
                .fill(ClubhouseTheme.bauhausGreen)
                .frame(width: 28, height: 28)
                .offset(x: -8, y: 30)
        }
    }

    private var steppedBlocks: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Rectangle().fill(ClubhouseTheme.bauhausBlue).frame(width: 28, height: 28)
            Rectangle().fill(ClubhouseTheme.ink).frame(width: 28, height: 48)
            Rectangle().fill(ClubhouseTheme.bauhausRed).frame(width: 28, height: 68)
        }
        .overlay {
            HalftoneStrip(color: .black, intensity: 0.18)
                .blendMode(.multiply)
                .clipped()
        }
    }
}

struct BauhausStar: View {
    var color: Color
    var points: Int = 4

    var body: some View {
        Image(systemName: points > 4 ? "sparkle" : "seal.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .rotationEffect(.degrees(points == 4 ? 20 : 0))
    }
}

struct BauhausGridLines: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 14
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(ClubhouseTheme.ink.opacity(0.06)), lineWidth: 0.5)
        }
    }
}

struct GridPatternFill: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 5
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                        with: .color(ClubhouseTheme.ink.opacity(0.35))
                    )
                    x += step
                }
                y += step
            }
        }
    }
}

// MARK: - Primary CTA with halftone accent

struct BauhausPrimaryButton: View {
    let title: String
    var systemImage: String? = "arrow.right"
    var fill: Color = ClubhouseTheme.bauhausBlue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.bold))
                        .foregroundStyle(fill)
                        .frame(width: 28, height: 28)
                        .background(ClubhouseTheme.onPrimary, in: Circle())
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.onPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                ZStack(alignment: .trailing) {
                    fill
                    HalftoneStrip(color: ClubhouseTheme.onPrimary, intensity: 0.22)
                        .frame(width: 88)
                        .mask(
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: fill.opacity(0.28), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct BauhausNewGameButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Game")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text("Start a fresh scoreboard.")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.ink.opacity(0.7))
                }

                Spacer(minLength: 0)

                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .trim(from: 0.5, to: 1)
                        .fill(ClubhouseTheme.ink)
                        .frame(width: 64, height: 64)
                        .offset(x: 18, y: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ClubhouseTheme.bauhausRed)
                        .overlay { HalftoneStrip(color: .black, intensity: 0.35).clipped() }
                        .frame(width: 28, height: 40)
                        .offset(x: 8, y: 6)
                }
                .frame(width: 56, height: 56)
                .clipped()
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(ClubhouseTheme.bauhausYellow, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: ClubhouseTheme.bauhausYellow.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("new_game_button")
        .accessibilityLabel("New Game")
    }
}

// MARK: - Round progress dots

struct BauhausRoundDots: View {
    let current: Int
    let total: Int
    var activeColor: Color = ClubhouseTheme.bauhausBlue

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(total, 1), id: \.self) { index in
                let isFilled = index <= current
                Circle()
                    .fill(isFilled ? activeColor : Color.clear)
                    .overlay {
                        Circle()
                            .strokeBorder(isFilled ? activeColor : ClubhouseTheme.panelBorder, lineWidth: 1.5)
                    }
                    .frame(width: 10, height: 10)
                    .scaleEffect(isFilled ? 1 : 0.92)
                    .animation(AppMotion.state, value: current)
            }
        }
        .accessibilityLabel("Round \(current) of \(total)")
    }
}

// MARK: - Floating tab bar chrome

enum PipCountTab: String, CaseIterable, Identifiable {
    case home
    case games
    case players
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .games: return "Games"
        case .players: return "Players"
        case .more: return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .games: return "square.grid.2x2"
        case .players: return "person.2"
        case .more: return "ellipsis"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .home: return "house.fill"
        case .games: return "square.grid.2x2.fill"
        case .players: return "person.2.fill"
        case .more: return "ellipsis"
        }
    }
}

struct PipCountTabBar: View {
    var selected: PipCountTab
    var onSelect: (PipCountTab) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PipCountTab.allCases) { tab in
                let isSelected = selected == tab
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                            .symbolEffect(.bounce, value: isSelected && !reduceMotion)
                            .contentTransition(.symbolEffect(.replace))
                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundStyle(isSelected ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier("tab_\(tab.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(ClubhouseTheme.panelBorder.opacity(0.7), lineWidth: 1)
                }
                .shadow(color: ClubhouseTheme.ink.opacity(0.10), radius: 18, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Screen header

struct BauhausScreenHeader: View {
    let title: String
    var subtitle: String?
    var heroStyle: BauhausHeroStyle = .home
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let subtitle {
                    Text(subtitle)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.ink.opacity(0.75))
                }
            }

            Spacer(minLength: 0)

            ZStack(alignment: .topTrailing) {
                BauhausHeroArt(style: heroStyle, height: 110)
                if let trailing {
                    trailing
                }
            }
        }
        .padding(.top, 8)
    }
}
