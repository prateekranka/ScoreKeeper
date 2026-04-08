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
        case .small: return .system(size: 14, weight: .bold, design: .rounded)
        case .medium: return .system(size: 18, weight: .bold, design: .rounded)
        case .large: return .system(size: 28, weight: .bold, design: .rounded)
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
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
