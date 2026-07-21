//
//  PipTuning.swift
//  PipCount — DEBUG spacing / placement tuning kit (Fable round-2 review)
//
//  Drop this file into the app target. Everything is #if DEBUG gated.
//
//  Usage:
//    1. Add `.tuningPanel()` to your root view (e.g. in ScoreKeeperApp.swift):
//         ContentView().tuningPanel()
//    2. Replace the hardcoded values at the listed call sites with
//       `PipTuning.shared.<token>` while tuning.
//    3. Nudge sliders on-device/simulator; values persist via @AppStorage.
//    4. When the human says "done tuning", copy the export (Copy button in
//       the panel) into `PipSpacing` below, switch call sites to
//       `PipSpacing.<token>`, and delete/ignore the panel.
//

import SwiftUI

#if DEBUG

// MARK: - Live-tunable tokens (persisted across launches)

@MainActor
final class PipTuning: ObservableObject {
    static let shared = PipTuning()

    // Scoring
    /// Extra bottom content inset on the scoring scroll view so the last
    /// player card + quick-add chips clear the Submit/Undo bar.
    @AppStorage("tun.scoringBottomInset") var scoringBottomInset: Double = 180
    /// Gap between Submit bar and bottom safe-area edge.
    @AppStorage("tun.submitBarBottomGap") var submitBarBottomGap: Double = 12
    /// ACTIVE badge (horizontal capsule) — size and offset from name baseline.
    @AppStorage("tun.activeBadgeHeight") var activeBadgeHeight: Double = 22
    @AppStorage("tun.activeBadgeMinWidth") var activeBadgeMinWidth: Double = 64
    @AppStorage("tun.activeBadgeOffsetX") var activeBadgeOffsetX: Double = 8
    @AppStorage("tun.activeBadgeOffsetY") var activeBadgeOffsetY: Double = 0

    // Timer sheet
    /// Vertical offset of the hero icon below the sheet's nav title row.
    @AppStorage("tun.timerHeroOffsetY") var timerHeroOffsetY: Double = 24
    /// Hero icon scale (1.0 = 96pt circle).
    @AppStorage("tun.timerHeroScale") var timerHeroScale: Double = 1.0
    /// Gap between hero icon and "Keep turns moving" title.
    @AppStorage("tun.timerTitleGap") var timerTitleGap: Double = 20

    // Home
    /// Clearance between the Game Night Tools row and the floating tab bar.
    @AppStorage("tun.homeToolsBottomClearance") var homeToolsBottomClearance: Double = 96
    /// Floating tab bar inset from screen edges.
    @AppStorage("tun.tabBarInset") var tabBarInset: Double = 20
    /// Opaque mask height under the status bar to stop scroll-bleed.
    @AppStorage("tun.homeHeaderTopMask") var homeHeaderTopMask: Double = 56

    // Player Setup
    /// Minimum gap kept between Start Game CTA and the top of the keyboard.
    @AppStorage("tun.setupCTAKeyboardGap") var setupCTAKeyboardGap: Double = 12

    // Game Over
    /// Brand-art cluster placement + scale.
    @AppStorage("tun.gameOverArtOffsetX") var gameOverArtOffsetX: Double = 0
    @AppStorage("tun.gameOverArtOffsetY") var gameOverArtOffsetY: Double = 0
    @AppStorage("tun.gameOverArtScale") var gameOverArtScale: Double = 1.0
    /// Spacing between the winner identity marks (blue circle / red square).
    @AppStorage("tun.identityMarkSpacing") var identityMarkSpacing: Double = 24

    // Paywall
    /// Close X offset so it stops overlapping the yellow halftone circle.
    @AppStorage("tun.paywallCloseOffsetX") var paywallCloseOffsetX: Double = 4
    @AppStorage("tun.paywallCloseOffsetY") var paywallCloseOffsetY: Double = -4
    @AppStorage("tun.paywallArtOffsetX") var paywallArtOffsetX: Double = 0
    @AppStorage("tun.paywallArtOffsetY") var paywallArtOffsetY: Double = 0

    var exportText: String {
        """
        enum PipSpacing {
            static let scoringBottomInset: CGFloat = \(Int(scoringBottomInset))
            static let submitBarBottomGap: CGFloat = \(Int(submitBarBottomGap))
            static let activeBadgeHeight: CGFloat = \(Int(activeBadgeHeight))
            static let activeBadgeMinWidth: CGFloat = \(Int(activeBadgeMinWidth))
            static let activeBadgeOffset = CGSize(width: \(Int(activeBadgeOffsetX)), height: \(Int(activeBadgeOffsetY)))
            static let timerHeroOffsetY: CGFloat = \(Int(timerHeroOffsetY))
            static let timerHeroScale: CGFloat = \(String(format: "%.2f", timerHeroScale))
            static let timerTitleGap: CGFloat = \(Int(timerTitleGap))
            static let homeToolsBottomClearance: CGFloat = \(Int(homeToolsBottomClearance))
            static let tabBarInset: CGFloat = \(Int(tabBarInset))
            static let homeHeaderTopMask: CGFloat = \(Int(homeHeaderTopMask))
            static let setupCTAKeyboardGap: CGFloat = \(Int(setupCTAKeyboardGap))
            static let gameOverArtOffset = CGSize(width: \(Int(gameOverArtOffsetX)), height: \(Int(gameOverArtOffsetY)))
            static let gameOverArtScale: CGFloat = \(String(format: "%.2f", gameOverArtScale))
            static let identityMarkSpacing: CGFloat = \(Int(identityMarkSpacing))
            static let paywallCloseOffset = CGSize(width: \(Int(paywallCloseOffsetX)), height: \(Int(paywallCloseOffsetY)))
            static let paywallArtOffset = CGSize(width: \(Int(paywallArtOffsetX)), height: \(Int(paywallArtOffsetY)))
        }
        """
    }

    func publish() {
        objectWillChange.send()
    }
}

// MARK: - Floating tuning panel

struct TuningPanel: View {
    @ObservedObject var t = PipTuning.shared
    @State private var collapsed = true
    @State private var copied = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button(collapsed ? "Tune" : "Close") { collapsed.toggle() }
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())

            if !collapsed {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        group("Scoring") {
                            knob("Bottom inset", $t.scoringBottomInset, 0...320)
                            knob("Submit bar gap", $t.submitBarBottomGap, 0...48)
                            knob("Badge height", $t.activeBadgeHeight, 16...44)
                            knob("Badge min width", $t.activeBadgeMinWidth, 40...120)
                            knob("Badge X", $t.activeBadgeOffsetX, -40...40)
                            knob("Badge Y", $t.activeBadgeOffsetY, -20...20)
                        }
                        group("Timer sheet") {
                            knob("Hero Y offset", $t.timerHeroOffsetY, 0...120)
                            knob("Hero scale", $t.timerHeroScale, 0.5...1.6)
                            knob("Title gap", $t.timerTitleGap, 0...64)
                        }
                        group("Home") {
                            knob("Tools↔tab clearance", $t.homeToolsBottomClearance, 0...160)
                            knob("Tab bar inset", $t.tabBarInset, 0...40)
                            knob("Top mask height", $t.homeHeaderTopMask, 0...120)
                        }
                        group("Player Setup") {
                            knob("CTA↔keyboard gap", $t.setupCTAKeyboardGap, 0...64)
                        }
                        group("Game Over") {
                            knob("Art X", $t.gameOverArtOffsetX, -80...80)
                            knob("Art Y", $t.gameOverArtOffsetY, -80...80)
                            knob("Art scale", $t.gameOverArtScale, 0.5...1.6)
                            knob("Mark spacing", $t.identityMarkSpacing, 4...64)
                        }
                        group("Paywall") {
                            knob("Close X", $t.paywallCloseOffsetX, -60...60)
                            knob("Close Y", $t.paywallCloseOffsetY, -60...60)
                            knob("Art X", $t.paywallArtOffsetX, -80...80)
                            knob("Art Y", $t.paywallArtOffsetY, -80...80)
                        }
                        Button(copied ? "Copied PipSpacing" : "Copy as PipSpacing") {
                            UIPasteboard.general.string = t.exportText
                            copied = true
                        }
                        .font(.caption.bold())
                        .padding(.top, 8)
                    }
                    .padding(12)
                }
                .frame(width: 280, height: 420)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.trailing, 8)
        .padding(.top, 52)
    }

    @ViewBuilder private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary).padding(.top, 6)
        content()
    }

    private func knob(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).font(.caption2)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: {
                        value.wrappedValue = $0
                        t.publish()
                    }
                ),
                in: range
            )
        }
    }
}

extension View {
    /// Attach to the root view in DEBUG builds.
    func tuningPanel() -> some View {
        overlay(alignment: .topTrailing) {
            TuningPanel()
                .allowsHitTesting(true)
        }
    }
}

#else

extension View {
    func tuningPanel() -> some View { self }
}

#endif

// MARK: - Final form (filled in after the human locks values)
//
// enum PipSpacing {
//     // ← paste the "Copy as PipSpacing" export here, then switch all
//     //   PipTuning.shared.* call sites to PipSpacing.* and remove the panel.
// }
