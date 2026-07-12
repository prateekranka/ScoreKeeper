import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion ? AppMotion.fade : configuration.isPressed ? AppMotion.pressIn : AppMotion.pressOut,
                value: configuration.isPressed
            )
    }
}

struct ClubhousePressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? ClubhouseTheme.felt.opacity(0.14) : Color.clear)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(
                reduceMotion ? AppMotion.fade : configuration.isPressed ? AppMotion.pressIn : AppMotion.pressOut,
                value: configuration.isPressed
            )
    }
}
