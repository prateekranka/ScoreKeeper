import SwiftUI

struct RoundTracker: View {
    let totalRounds: Int
    let currentRound: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(1...max(totalRounds, currentRound), id: \.self) { round in
                        VStack(spacing: 2) {
                            Circle()
                                .fill(round < currentRound ? ClubhouseTheme.felt :
                                      round == currentRound ? ClubhouseTheme.brass :
                                      ClubhouseTheme.paperSunken)
                                .frame(width: round == currentRound ? 14 : 10,
                                       height: round == currentRound ? 14 : 10)
                                .overlay {
                                    Circle().stroke(ClubhouseTheme.rule, lineWidth: 1)
                                }

                            Text("\(round)")
                                .font(round == currentRound ? AppFonts.caption.bold() : AppFonts.caption)
                                .foregroundStyle(round == currentRound ? ClubhouseTheme.ink : ClubhouseTheme.inkMuted)
                        }
                        .id(round)
                    }
                }
                .padding(.horizontal, AppTheme.spacingMedium)
            }
            .onChange(of: currentRound) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}
