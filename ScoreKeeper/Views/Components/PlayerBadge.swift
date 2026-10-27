import SwiftUI

enum BadgeSize {
    case small, medium, large

    var diameter: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 64
        }
    }

    var font: Font {
        switch self {
        case .small: return .body.bold()
        case .medium: return .body.bold()
        case .large: return .title3.bold()
        }
    }

    var nameFont: Font {
        switch self {
        case .small: return AppFonts.label
        case .medium: return AppFonts.body
        case .large: return AppFonts.headline
        }
    }
}

struct PlayerBadge: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let name: String
    let colorIndex: Int
    var size: BadgeSize = .medium
    var showName: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            BauhausPlayerShape(colorIndex: colorIndex, size: size.diameter)
                .frame(minWidth: 44, minHeight: 44)

            if showName {
                Text(name)
                    .font(size.nameFont)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

struct PlayerGlyph: View {
    let colorIndex: Int
    var font: Font = AppFonts.label

    var body: some View {
        Text(PlayerColors.glyph(for: colorIndex))
            .font(font)
            .foregroundStyle(ClubhouseTheme.ink)
            .accessibilityHidden(true)
    }
}
