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
            ZStack {
                Circle()
                    .fill(PlayerColors.color(for: colorIndex))
                    .frame(width: size.diameter, height: size.diameter)

                Text(initial)
                    .font(size.font)
                    .foregroundStyle(.white)
            }

            if showName {
                Text(name)
                    .font(size.nameFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
