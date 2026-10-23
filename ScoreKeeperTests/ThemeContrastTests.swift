import SwiftUI
import Testing
import UIKit
@testable import ScoreKeeper

@MainActor
struct ThemeContrastTests {
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func themeTextMeetsAA(appearance: UIUserInterfaceStyle) {
        let traits = UITraitCollection(userInterfaceStyle: appearance)
        let foregrounds: [(String, Color)] = [
            ("ink", ClubhouseTheme.ink), ("muted", ClubhouseTheme.inkMuted),
            ("blue", ClubhouseTheme.blue), ("red", ClubhouseTheme.red),
            ("green", ClubhouseTheme.green), ("brass", ClubhouseTheme.brass)
        ]
        let surfaces: [(String, Color)] = [
            ("paper", ClubhouseTheme.paper), ("card", ClubhouseTheme.paperCard),
            ("sunken", ClubhouseTheme.paperSunken), ("elevated", ClubhouseTheme.paperElevated),
            ("sky", ClubhouseTheme.sky)
        ]
        var backgrounds = surfaces.map { ($0.0, rgba($0.1, traits: traits)) }
        let tints = PlayerColors.palette + [ClubhouseTheme.yellow, ClubhouseTheme.blue, ClubhouseTheme.red, ClubhouseTheme.green]
        for (surfaceName, surface) in surfaces.prefix(4) {
            for (index, tint) in tints.enumerated() {
                backgrounds.append(("\(surfaceName)/tint\(index)", composite(
                    rgba(tint.opacity(0.12), traits: traits), over: rgba(surface, traits: traits)
                )))
            }
        }
        for (foregroundName, foreground) in foregrounds {
            for (backgroundName, background) in backgrounds {
                let ratio = contrast(rgba(foreground, traits: traits), background)
                #expect(ratio >= 4.5, "\(appearance): \(foregroundName) on \(backgroundName) = \(ratio)")
            }
        }
        for (index, fill) in [ClubhouseTheme.blue, ClubhouseTheme.feltDeep, ClubhouseTheme.red, ClubhouseTheme.green, ClubhouseTheme.yellow, ClubhouseTheme.ink].enumerated() {
            let ratio = contrast(
                rgba(ClubhouseTheme.onButton(fill), traits: traits),
                rgba(fill, traits: traits)
            )
            #expect(ratio >= 4.5, "\(appearance): primary button \(index) = \(ratio)")
        }
        for fill in [ClubhouseTheme.felt, ClubhouseTheme.feltDeep, ClubhouseTheme.danger] {
            #expect(contrast(rgba(ClubhouseTheme.onFelt, traits: traits), rgba(fill, traits: traits)) >= 4.5)
        }
    }

    private func rgba(_ color: Color, traits: UITraitCollection) -> [Double] {
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return [Double(red), Double(green), Double(blue), Double(alpha)]
    }

    private func composite(_ foreground: [Double], over background: [Double]) -> [Double] {
        (0..<3).map { foreground[$0] * foreground[3] + background[$0] * (1 - foreground[3]) } + [1]
    }

    private func contrast(_ first: [Double], _ second: [Double]) -> Double {
        let firstLuminance = luminance(first)
        let secondLuminance = luminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func luminance(_ color: [Double]) -> Double {
        let linear = color.prefix(3).map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
