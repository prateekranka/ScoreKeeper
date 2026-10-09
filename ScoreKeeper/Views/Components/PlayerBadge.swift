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
        case .small: return .caption.bold()
        case .medium: return .subheadline.bold()
        case .large: return .title3.bold()
        }
    }

    var nameFont: Font {
        switch self {
        case .small: return AppFonts.caption
        case .medium: return AppFonts.body
        case .large: return AppFonts.headline
        }
    }
}

struct PlayerBadge: View {
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
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

struct PlayerGlyph: View {
    let colorIndex: Int
    var font: Font = AppFonts.caption

    var body: some View {
        Text(PlayerColors.glyph(for: colorIndex))
            .font(font)
            .foregroundStyle(PlayerColors.color(for: colorIndex))
            .accessibilityHidden(true)
    }
}
