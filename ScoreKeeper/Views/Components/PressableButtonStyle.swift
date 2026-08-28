import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1.5 : 0)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .opacity(configuration.isPressed ? 0.94 : 1)
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(
                reduceMotion ? AppMotion.fade : configuration.isPressed ? AppMotion.pressIn : AppMotion.pressOut,
                value: configuration.isPressed
            )
    }
}
