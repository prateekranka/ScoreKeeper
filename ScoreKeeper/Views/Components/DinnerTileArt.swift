import SwiftUI

/// Bitmap replacement for the What's for Dinner tile thumbnail: the bundled
/// Bauhaus plate artwork with a subtle idle breathing motion. The parent
/// supplies the TimelineView time, drives `active`, and clips the surrounding tile.
struct DinnerTileArt: View {
    let size: CGSize
    let time: TimeInterval
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        // Rest state for Reduce Motion and the "-tile-art-frozen" pixel-diff runs.
        let breath = TileIdleLoop.breath(
            time: time,
            delay: 0,
            reduceMotion: reduceMotion || isFrozenForVerification
        )
        let scale = TileIdleLoop.scale(breath: breath, contracted: 0.996, expanded: 1.012)

        Image("WhatsForDinnerTileArtwork")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(scale)
            .offset(
                x: TileIdleLoop.drift(breath: breath, peak: 2.5),
                y: TileIdleLoop.drift(breath: breath, peak: -2.5)
            )
            .modifier(TileArtEntranceModifier(active: active, entry: CGSize(width: 0, height: 28), scale: 0.78))
    }

    private var isFrozenForVerification: Bool {
        ProcessInfo.processInfo.arguments.contains("-tile-art-frozen")
    }
}

/// Copy of the private `TileArtMotionModifier` in GameTypeTile.swift for this
/// view's index-0 artwork (no stagger delay), minus rotation (the bitmap must
/// never rotate). Applied outside the breathing scale/offset so the two
/// motions don't fight.
private struct TileArtEntranceModifier: ViewModifier {
    let active: Bool
    let entry: CGSize
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .offset(active ? .zero : entry)
            .scaleEffect(active ? 1 : scale)
            .blur(radius: active ? 0 : 1.5)
            .animation(
                active ? AppMotion.artEntrance : AppMotion.artExit,
                value: active
            )
    }
}
