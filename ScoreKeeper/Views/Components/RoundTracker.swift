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
                                .fill(round < currentRound ? .green :
                                      round == currentRound ? PlayerColors.palette[3] :
                                      Color.secondary.opacity(0.3))
                                .frame(width: round == currentRound ? 14 : 10,
                                       height: round == currentRound ? 14 : 10)

                            Text("\(round)")
                                .font(.system(size: 10, weight: round == currentRound ? .bold : .regular, design: .rounded))
                                .foregroundStyle(round == currentRound ? .primary : .secondary)
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
