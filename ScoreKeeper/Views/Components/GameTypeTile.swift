import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void
    var accessibilityID: String? = nil

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PIPCOUNT / \(gameType.displayName.uppercased())")
                        .font(AppFonts.caption.weight(.bold))
                        .tracking(1.2)
                    Spacer()
                    Text("\(gameType.minPlayers)—\(gameType.maxPlayers)")
                        .font(AppFonts.caption.monospacedDigit().weight(.bold))
                }
                .foregroundStyle(ClubhouseTheme.ink)

                GameTypeArtwork(gameType: gameType)
                    .frame(maxWidth: .infinity)
                    .frame(height: 126)

                VStack(alignment: .leading, spacing: 6) {
                    Text(gameType.displayName)
                        .font(AppFonts.tileTitle)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text(gameType.subtitle)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.leading)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingMedium)
            .background {
                Rectangle()
                    .fill(ClubhouseTheme.paperCard)
                    .shadow(color: ClubhouseTheme.paperShadow, radius: 0, x: 3, y: 4)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(gameType.color, lineWidth: 2)
            }
            .overlay {
                Rectangle()
                    .inset(by: 4)
                    .strokeBorder(ClubhouseTheme.rule, lineWidth: 0.75)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(accessibilityID ?? "")
        .accessibilityLabel("\(gameType.displayName). \(gameType.subtitle). \(gameType.minPlayers) to \(gameType.maxPlayers) players.")
    }
}

struct GameTypeArtwork: View {
    let gameType: GameType

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 150, proxy.size.height / 132)

            artwork
                .frame(width: 150, height: 132)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch gameType {
        case .generic:
            ZStack {
                Rectangle().fill(ClubhouseTheme.blue).frame(width: 108, height: 108)
                Circle().fill(ClubhouseTheme.yellow).frame(width: 68, height: 68).offset(x: 22, y: 18)
                Rectangle().fill(ClubhouseTheme.ink).frame(width: 5, height: 132).rotationEffect(.degrees(45))
            }
        case .phase10:
            ZStack {
                Rectangle().fill(ClubhouseTheme.red).frame(width: 108, height: 108)
                ForEach(0..<5, id: \.self) { index in
                    Rectangle().fill(index < 3 ? ClubhouseTheme.yellow : ClubhouseTheme.paperCard)
                        .frame(width: 14, height: 14).offset(x: CGFloat(index - 2) * 22)
                }
                Text("10").font(AppFonts.scoreMedium).foregroundStyle(ClubhouseTheme.ink)
            }
            .padding(22)
        case .whatsForDinner:
            ZStack {
                Rectangle().fill(ClubhouseTheme.yellow).frame(width: 108, height: 108)
                Circle().fill(ClubhouseTheme.blue).frame(width: 52, height: 52).offset(x: -22, y: -18)
                TriangleShape().fill(ClubhouseTheme.green).frame(width: 52, height: 52).offset(x: 26, y: 22)
                Rectangle().fill(ClubhouseTheme.ink).frame(width: 86, height: 5).rotationEffect(.degrees(-25))
            }
        }
    }
}

private struct ScoreSheetArtwork: View {
    let gameType: GameType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(ClubhouseTheme.paperCard)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                }

            sheetContent
                .padding(7)
        }
        .frame(width: 62, height: 46)
    }

    @ViewBuilder
    private var sheetContent: some View {
        switch gameType {
        case .generic:
            VStack(spacing: 5) {
                ledgerLine(colorIndex: 0, score: "12")
                ledgerLine(colorIndex: 1, score: "7")
                ledgerLine(colorIndex: 2, score: "24")
            }
        case .whatsForDinner:
            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(gameType.color)
                VStack(spacing: 5) {
                    ledgerLine(colorIndex: 3, score: "3")
                    ledgerLine(colorIndex: 4, score: "9")
                }
            }
        case .phase10:
            VStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(row * 5 + column < 3 ? gameType.color : ClubhouseTheme.paperSunken)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 0.75)
                                }
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
    }

    private func ledgerLine(colorIndex: Int, score: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(PlayerColors.color(for: colorIndex))
                .frame(width: 5, height: 5)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            Text(score)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.ink)
        }
    }
}
