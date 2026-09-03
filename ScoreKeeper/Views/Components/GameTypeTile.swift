import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void
    var accessibilityID: String? = nil

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                GamePickerArtwork(gameType: gameType)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gameType.displayName)
                            .font(AppFonts.tileTitle)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text(gameType.subtitle)
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(gameType.minPlayers)–\(gameType.maxPlayers)")
                        .font(AppFonts.columnHeader)
                        .monospacedDigit()
                        .foregroundStyle(ClubhouseTheme.ink)
                        .padding(.bottom, 2)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(ClubhouseTheme.paperCard)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(gameType.color)
                    .frame(height: 4)
            }
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(accessibilityID ?? "")
        .accessibilityLabel("\(gameType.displayName). \(gameType.subtitle). \(gameType.minPlayers) to \(gameType.maxPlayers) players.")
    }
}

/// Image-backed artwork used only by the Games picker. Other screens keep the
/// adaptive vector `GameTypeArtwork` below.
private struct GamePickerArtwork: View {
    let gameType: GameType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pipCountPageIsExiting) private var pageIsExiting
    @State private var appeared = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || isFrozenForVerification)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate

                switch gameType {
                case .generic:
                    ScoreboardTileArt(
                        size: proxy.size,
                        time: time,
                        active: isActive,
                        reduceMotion: reduceMotion
                    )
                case .phase10:
                    Phase10TileArt(
                        size: proxy.size,
                        time: time,
                        active: isActive,
                        reduceMotion: reduceMotion
                    )
                case .whatsForDinner:
                    DinnerTileArt(
                        size: proxy.size,
                        time: time,
                        active: isActive,
                        reduceMotion: reduceMotion
                    )
                }
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
        .onDisappear { appeared = false }
        .accessibilityHidden(true)
    }

    private var isActive: Bool {
        appeared && !pageIsExiting
    }

    private var isFrozenForVerification: Bool {
        ProcessInfo.processInfo.arguments.contains("-tile-art-frozen")
    }
}

private struct ScoreboardTileArt: View {
    let size: CGSize
    let time: TimeInterval
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        let breath = TileIdleLoop.breath(
            time: time,
            delay: 0,
            reduceMotion: reduceMotion || isFrozenForVerification
        )
        let scale = TileIdleLoop.scale(breath: breath, contracted: 0.996, expanded: 1.012)

        Image("ScoreboardTileArtwork")
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(scale)
            .offset(
                x: TileIdleLoop.drift(breath: breath, peak: 3),
                y: TileIdleLoop.drift(breath: breath, peak: -3)
            )
            .opacity(active ? 1 : 0)
            .offset(active ? .zero : CGSize(width: 0, height: 28))
            .scaleEffect(active ? 1 : 0.78)
            .animation(active ? AppMotion.artEntrance : AppMotion.artExit, value: active)
    }

    private var isFrozenForVerification: Bool {
        ProcessInfo.processInfo.arguments.contains("-tile-art-frozen")
    }
}

struct GameTypeArtwork: View {
    let gameType: GameType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pipCountPageIsExiting) private var pageIsExiting
    @State private var appeared = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    constructionGrid

                    switch gameType {
                    case .generic:
                        scoreboardComposition(size: proxy.size, time: time)
                    case .phase10:
                        phaseComposition(size: proxy.size, time: time)
                    case .whatsForDinner:
                        decisionComposition(size: proxy.size, time: time)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
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
        .onDisappear { appeared = false }
        .accessibilityHidden(true)
    }

    private var isActive: Bool {
        appeared && !pageIsExiting
    }

    private var constructionGrid: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width * 0.12, y: proxy.size.height * 0.52))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.88, y: proxy.size.height * 0.52))
                    path.move(to: CGPoint(x: proxy.size.width * 0.50, y: proxy.size.height * 0.10))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.50, y: proxy.size.height * 0.90))
                }
                .stroke(ClubhouseTheme.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))

                Circle()
                    .stroke(ClubhouseTheme.ink.opacity(0.17), lineWidth: 1)
                    .frame(width: min(proxy.size.width, proxy.size.height) * 0.72)
            }
        }
        .opacity(isActive ? 1 : 0)
        .animation(AppMotion.fade, value: isActive)
    }

    @ViewBuilder
    private func scoreboardComposition(size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: size.width * 0.38, height: size.height * 0.72)
                .position(x: size.width * 0.46, y: size.height * 0.50)
                .tileArtMotion(active: isActive, index: 1, entry: CGSize(width: 0, height: 34), scale: 0.60)

            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: min(size.width, size.height) * 0.42)
                .position(x: size.width * 0.62, y: size.height * 0.62 + wave(time, phase: 0.5, amplitude: 4))
                .tileArtMotion(active: isActive, index: 2, entry: CGSize(width: 24, height: 24), scale: 0.42)

            Rectangle()
                .fill(ClubhouseTheme.ink)
                .frame(width: max(10, size.width * 0.045), height: size.height * 0.88)
                .rotationEffect(.degrees(43 + wave(time, phase: 1.2, amplitude: 1.6)))
                .position(x: size.width * 0.52, y: size.height * 0.49)
                .tileArtMotion(active: isActive, index: 3, entry: CGSize(width: 0, height: -36), rotation: 18, scale: 0.62)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.48, height: max(7, size.height * 0.055))
                .position(x: size.width * 0.55, y: size.height * 0.31)
                .tileArtMotion(active: isActive, index: 4, entry: CGSize(width: -32, height: 0), scale: 0.58)

            BauhausStarburst(color: ClubhouseTheme.paperCard, size: min(size.width, size.height) * 0.20)
                .position(x: size.width * 0.40, y: size.height * 0.35)
                .rotationEffect(.degrees(wave(time, phase: 2.0, amplitude: 8)))
                .tileArtMotion(active: isActive, index: 5, entry: CGSize(width: -18, height: -18), rotation: -20, scale: 0.28)
        }
    }

    @ViewBuilder
    private func phaseComposition(size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.55, height: size.height * 0.72)
                .position(x: size.width * 0.50, y: size.height * 0.51)
                .tileArtMotion(active: isActive, index: 1, entry: CGSize(width: 0, height: 34), scale: 0.56)

            HStack(spacing: size.width * 0.025) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(index < 2 ? ClubhouseTheme.yellow : ClubhouseTheme.paperCard)
                        .frame(width: size.width * 0.07, height: size.width * 0.07)
                        .tileArtMotion(active: isActive, index: index + 2, entry: CGSize(width: 0, height: 24), scale: 0.24)
                }
            }
            .position(x: size.width * 0.50, y: size.height * 0.51)

            Text("10")
                .font(.system(size: min(size.width, size.height) * 0.34, weight: .black, design: .default))
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
                .position(x: size.width * 0.50, y: size.height * 0.51 + wave(time, phase: 0.7, amplitude: 3))
                .tileArtMotion(active: isActive, index: 4, entry: CGSize(width: 0, height: -24), scale: 0.44)

            Rectangle()
                .fill(ClubhouseTheme.ink)
                .frame(width: max(9, size.width * 0.038), height: size.height * 0.82)
                .rotationEffect(.degrees(-44 + wave(time, phase: 1.5, amplitude: 1.5)))
                .position(x: size.width * 0.50, y: size.height * 0.50)
                .tileArtMotion(active: isActive, index: 6, entry: CGSize(width: 0, height: -34), rotation: -18, scale: 0.64)

            Circle()
                .fill(ClubhouseTheme.blue)
                .frame(width: min(size.width, size.height) * 0.20)
                .position(x: size.width * 0.29, y: size.height * 0.24 + wave(time, phase: 2.1, amplitude: 4))
                .tileArtMotion(active: isActive, index: 7, entry: CGSize(width: -22, height: -20), scale: 0.30)
        }
    }

    @ViewBuilder
    private func decisionComposition(size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: min(size.width, size.height) * 0.52)
                .position(x: size.width * 0.48, y: size.height * 0.48 + wave(time, phase: 0.2, amplitude: 4))
                .tileArtMotion(active: isActive, index: 1, entry: CGSize(width: 0, height: 30), scale: 0.46)

            Circle()
                .fill(ClubhouseTheme.blue)
                .frame(width: min(size.width, size.height) * 0.31)
                .position(x: size.width * 0.34, y: size.height * 0.32 + wave(time, phase: 1.0, amplitude: 4))
                .tileArtMotion(active: isActive, index: 2, entry: CGSize(width: -26, height: -24), scale: 0.34)

            TriangleShape()
                .fill(ClubhouseTheme.green)
                .frame(width: size.width * 0.28, height: size.height * 0.36)
                .position(x: size.width * 0.63, y: size.height * 0.66)
                .tileArtMotion(active: isActive, index: 3, entry: CGSize(width: 24, height: 26), rotation: 14, scale: 0.38)

            Rectangle()
                .fill(ClubhouseTheme.ink)
                .frame(width: max(10, size.width * 0.045), height: size.height * 0.82)
                .rotationEffect(.degrees(32 + wave(time, phase: 1.8, amplitude: 1.5)))
                .position(x: size.width * 0.53, y: size.height * 0.49)
                .tileArtMotion(active: isActive, index: 4, entry: CGSize(width: 0, height: -34), rotation: 18, scale: 0.60)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: size.width * 0.18, height: size.width * 0.18)
                .rotationEffect(.degrees(45 + wave(time, phase: 2.6, amplitude: 3)))
                .position(x: size.width * 0.72, y: size.height * 0.30)
                .tileArtMotion(active: isActive, index: 5, entry: CGSize(width: 24, height: -22), rotation: 22, scale: 0.32)
        }
    }

    private func wave(_ time: TimeInterval, phase: Double, amplitude: CGFloat) -> CGFloat {
        guard !reduceMotion else { return 0 }
        return CGFloat(sin(time * 0.72 + phase)) * amplitude
    }
}

/// Shared 3.2s idle loop for the bitmap game-tile thumbnails.
/// Sinusoidal easeInOut, no spring.
struct TileIdleLoop {
    static let duration: TimeInterval = 3.2
    static let restHold: TimeInterval = 0.45

    /// 0 at rest, +1 at peak, −1 at counter-sway.
    static func breath(time: TimeInterval, delay: TimeInterval, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion else { return 0 }
        var local = (time - delay).truncatingRemainder(dividingBy: duration)
        if local < 0 { local += duration }
        return sample(local)
    }

    static func scale(breath: CGFloat, contracted: CGFloat, expanded: CGFloat) -> CGFloat {
        if breath >= 0 {
            return 1 + (expanded - 1) * breath
        }
        return 1 + (1 - contracted) * breath
    }

    static func drift(breath: CGFloat, peak: CGFloat) -> CGFloat {
        breath * peak
    }

    static func sample(_ t: TimeInterval) -> CGFloat {
        let keys: [(TimeInterval, Double)] = [
            (0.00, 0),
            (0.45, 0),
            (0.55, 0.18),
            (1.05, 1.00),
            (1.55, 0.22),
            (2.25, -1.00),
            (3.20, 0)
        ]

        for index in 0..<(keys.count - 1) {
            let start = keys[index]
            let end = keys[index + 1]
            if t <= end.0 || index == keys.count - 2 {
                let span = max(end.0 - start.0, 0.0001)
                let u = min(max((t - start.0) / span, 0), 1)
                let eased = 0.5 - 0.5 * cos(.pi * u)
                return CGFloat(start.1 + (end.1 - start.1) * eased)
            }
        }

        return 0
    }
}

private struct TileArtMotionModifier: ViewModifier {
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
            .blur(radius: active ? 0 : 1.5)
            .animation(
                active
                    ? AppMotion.artEntrance.delay(min(Double(index) * 0.045, 0.28))
                    : AppMotion.artExit,
                value: active
            )
    }
}

private extension View {
    func tileArtMotion(
        active: Bool,
        index: Int,
        entry: CGSize,
        rotation: Double = 0,
        scale: CGFloat = 0.72
    ) -> some View {
        modifier(
            TileArtMotionModifier(
                active: active,
                index: index,
                entry: entry,
                rotation: rotation,
                scale: scale
            )
        )
    }
}
