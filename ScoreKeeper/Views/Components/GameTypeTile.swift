import SwiftUI

struct GameTypeTile: View {
    let gameType: GameType
    let action: () -> Void
    var accessibilityID: String? = nil

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text(gameType.displayName == "Scoreboard" ? "ANY GAME" : "GAME NIGHT")
                        .font(AppFonts.columnHeader)
                        .tracking(0.9)
                        .foregroundStyle(gameType.color)

                    Spacer()

                    Label("\(gameType.minPlayers)–\(gameType.maxPlayers)", systemImage: "person.2.fill")
                        .font(AppFonts.caption.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .labelStyle(.titleAndIcon)
                }

                GameTypeArtwork(gameType: gameType)
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gameType.displayName)
                            .font(AppFonts.tileTitle)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text(gameType.subtitle)
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ClubhouseTheme.onPrimary)
                        .frame(width: 42, height: 42)
                        .background(gameType.color, in: Circle())
                        .shadow(color: ClubhouseTheme.ink.opacity(0.12), radius: 7, y: 4)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(ClubhouseTheme.paperCard)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(gameType.color)
                    .frame(width: 72, height: 5)
                    .padding(.top, 8)
            }
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
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
            let scale = min(proxy.size.width / 260, proxy.size.height / 180)

            artwork
                .frame(width: 260, height: 180)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch gameType {
        case .generic:
            ScorePadArtwork(accent: gameType.color)
        case .phase10:
            CardHandArtwork(accent: gameType.color)
        case .whatsForDinner:
            DinnerVoteArtwork(accent: gameType.color)
        }
    }
}

private struct ScorePadArtwork: View {
    let accent: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(ClubhouseTheme.paperShadow.opacity(0.58))
                .frame(width: 224, height: 38)
                .offset(y: 68)

            scoreSlip
                .rotationEffect(.degrees(-5))
                .offset(x: -12, y: 3)

            die
                .rotationEffect(.degrees(9))
                .offset(x: -84, y: 49)

            pencil
                .rotationEffect(.degrees(-36))
                .offset(x: 69, y: 18)

            BauhausStarburst(color: ClubhouseTheme.yellow, size: 24)
                .offset(x: 93, y: -60)
        }
    }

    private var scoreSlip: some View {
        VStack(spacing: 9) {
            ForEach(Array([12, 8, 15].enumerated()), id: \.offset) { index, score in
                HStack(spacing: 8) {
                    BauhausPlayerShape(colorIndex: index, size: 14)
                    Capsule()
                        .fill(ClubhouseTheme.rule)
                        .frame(height: 2)
                    Text("\(score)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(index == 0 ? accent : ClubhouseTheme.ink)
                }
            }
        }
        .padding(18)
        .frame(width: 154, height: 146)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(ClubhouseTheme.ruleStrong.opacity(0.48), lineWidth: 1.5)
        }
        .shadow(color: ClubhouseTheme.ink.opacity(0.13), radius: 9, y: 7)
    }

    private var die: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ClubhouseTheme.lacquer)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 8, height: 8)
                    .offset(pipOffset(index))
            }
        }
        .frame(width: 56, height: 56)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ClubhouseTheme.ink.opacity(0.72), lineWidth: 2)
        }
        .shadow(color: ClubhouseTheme.ink.opacity(0.12), radius: 5, y: 4)
    }

    private var pencil: some View {
        VStack(spacing: 0) {
            Capsule().fill(ClubhouseTheme.lacquer).frame(width: 24, height: 28)
            Rectangle().fill(ClubhouseTheme.yellow).frame(width: 24, height: 104)
            TriangleShape().fill(Color(red: 0.86, green: 0.72, blue: 0.55)).frame(width: 24, height: 34)
        }
        .overlay(alignment: .bottom) {
            TriangleShape()
                .fill(ClubhouseTheme.ink)
                .frame(width: 8, height: 12)
                .offset(y: -1)
        }
        .overlay {
            Capsule()
                .strokeBorder(ClubhouseTheme.ink.opacity(0.66), lineWidth: 2)
        }
    }

    private func pipOffset(_ index: Int) -> CGSize {
        switch index {
        case 0: return CGSize(width: -15, height: -15)
        case 1: return CGSize(width: 15, height: -15)
        case 2: return .zero
        case 3: return CGSize(width: -15, height: 15)
        default: return CGSize(width: 15, height: 15)
        }
    }
}

private struct CardHandArtwork: View {
    let accent: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(ClubhouseTheme.paperShadow.opacity(0.55))
                .frame(width: 224, height: 36)
                .offset(y: 70)

            gameCard(number: "2", color: ClubhouseTheme.blue)
                .rotationEffect(.degrees(-16))
                .offset(x: -67, y: 8)

            gameCard(number: "6", color: ClubhouseTheme.green)
                .rotationEffect(.degrees(-6))
                .offset(x: -23, y: -2)

            gameCard(number: "9", color: ClubhouseTheme.yellow)
                .rotationEffect(.degrees(6))
                .offset(x: 26, y: -2)

            gameCard(number: "10", color: accent)
                .rotationEffect(.degrees(16))
                .offset(x: 70, y: 8)

            phaseRibbon
                .offset(y: 61)
        }
    }

    private func gameCard(number: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(number)
                .font(.system(size: 23, weight: .black, design: .rounded))
            Spacer(minLength: 0)
            Circle()
                .fill(color)
                .frame(width: 42, height: 42)
                .overlay {
                    Text(number)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(ClubhouseTheme.onPrimary)
                }
            Spacer(minLength: 0)
            Text(number)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .rotationEffect(.degrees(180))
        }
        .foregroundStyle(color == ClubhouseTheme.yellow ? ClubhouseTheme.ink : color)
        .padding(10)
        .frame(width: 78, height: 130)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ClubhouseTheme.ink.opacity(0.58), lineWidth: 1.5)
        }
        .shadow(color: ClubhouseTheme.ink.opacity(0.12), radius: 6, y: 5)
    }

    private var phaseRibbon: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < 3 ? accent : ClubhouseTheme.paperSunken)
                    .frame(width: 13, height: 13)
                    .overlay { Circle().stroke(ClubhouseTheme.ink.opacity(0.30), lineWidth: 1) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ClubhouseTheme.paperCard, in: Capsule())
        .overlay { Capsule().stroke(ClubhouseTheme.ink.opacity(0.38), lineWidth: 1) }
        .shadow(color: ClubhouseTheme.ink.opacity(0.10), radius: 5, y: 3)
    }
}

private struct DinnerVoteArtwork: View {
    let accent: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(ClubhouseTheme.paperShadow.opacity(0.56))
                .frame(width: 218, height: 39)
                .offset(y: 69)

            plate

            choiceCard(symbol: "leaf.fill", color: ClubhouseTheme.green)
                .rotationEffect(.degrees(-9))
                .offset(x: -82, y: 42)

            choiceCard(symbol: "takeoutbag.and.cup.and.straw.fill", color: ClubhouseTheme.lacquer)
                .rotationEffect(.degrees(8))
                .offset(x: 83, y: 38)

            fork.offset(x: -93)
            knife.offset(x: 94)

            Circle()
                .fill(accent)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(ClubhouseTheme.onPrimary)
                }
                .offset(y: -6)
        }
    }

    private var plate: some View {
        ZStack {
            Circle()
                .fill(ClubhouseTheme.paperCard)
                .frame(width: 142, height: 142)
                .shadow(color: ClubhouseTheme.ink.opacity(0.12), radius: 9, y: 6)
            Circle()
                .stroke(ClubhouseTheme.ruleStrong.opacity(0.42), lineWidth: 2)
                .frame(width: 142, height: 142)
            Circle()
                .stroke(ClubhouseTheme.rule.opacity(0.78), lineWidth: 2)
                .frame(width: 104, height: 104)
        }
    }

    private func choiceCard(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 58, height: 68)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ink.opacity(0.58), lineWidth: 1.5)
            }
            .shadow(color: ClubhouseTheme.ink.opacity(0.11), radius: 5, y: 4)
    }

    private var fork: some View {
        Image(systemName: "fork.knife")
            .font(.system(size: 40, weight: .regular))
            .foregroundStyle(ClubhouseTheme.ink)
            .rotationEffect(.degrees(-5))
    }

    private var knife: some View {
        Capsule()
            .fill(ClubhouseTheme.ink)
            .frame(width: 8, height: 112)
            .rotationEffect(.degrees(5))
    }
}
