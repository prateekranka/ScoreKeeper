import SwiftUI

struct CupMascotView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 96, size.height / 80)
            let xOffset = (size.width - 96 * scale) / 2
            let yOffset = (size.height - 80 * scale) / 2

            func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> Path {
                Path(CGRect(
                    x: xOffset + x * scale,
                    y: yOffset + y * scale,
                    width: width * scale,
                    height: height * scale
                ))
            }

            let bodyFill = Color(light: 0x33383D, dark: 0xE9A63A)
            let cutoutFill = ClubhouseTheme.paper
            let shineFill = Color(light: 0x4A5058, dark: 0xF2C94C)

            [
                rect(16, 8, 64, 8),
                rect(16, 16, 64, 32),
                rect(0, 16, 16, 8),
                rect(0, 24, 8, 8),
                rect(80, 16, 16, 8),
                rect(88, 24, 8, 8),
                rect(40, 48, 16, 8),
                rect(32, 56, 32, 8),
                rect(24, 64, 48, 8),
            ].forEach { path in
                context.fill(path, with: .color(bodyFill))
            }

            if colorScheme == .light {
                context.fill(rect(40, 8, 16, 8), with: .color(Color(light: 0xA93226, dark: 0xA93226)))
            }

            context.fill(rect(22, 20, 8, 12), with: .color(shineFill))

            [
                rect(30, 24, 8, 8),
                rect(58, 24, 8, 8),
                rect(38, 38, 20, 6),
            ].forEach { path in
                context.fill(path, with: .color(cutoutFill))
            }
        }
        .aspectRatio(96 / 80, contentMode: .fit)
        .accessibilityLabel("Cup the trophy mascot")
    }
}
