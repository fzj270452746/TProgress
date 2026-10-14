import SwiftUI

// MARK: - Challenge card
//
// The shared goal, at a glance. One bar the whole circle fills. There is no
// per-person score on the card on purpose — the number belongs to the group.

struct ChallengeCard: View {

    let challenge: CDChallenge
    var onTap: (() -> Void)?

    private var accent: Color { challenge.accent }

    var body: some View {
        Button {
            TPHaptic.tap()
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                header
                TPMeter(progress: challenge.progress, height: 9, color: accent)
                footer
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(accent.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(accent.opacity(0.26), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(TPGradient.accent(accent))
                    .frame(width: 32, height: 32)

                Image(systemName: challenge.kind == .relay21 ? "arrow.triangle.2.circlepath" : "person.3.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.tpInk.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text.tpLabel(challenge.kind.label, size: 8.5, tracking: 1.3, color: accent)

                Text(challenge.heading)
                    .font(TPFont.ui(14.5, .semibold))
                    .foregroundColor(.tpCream)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if challenge.daysRemaining > 0 {
                Text("\(challenge.daysRemaining)d left")
                    .font(TPFont.figure(11, .bold))
                    .foregroundColor(.tpCreamFaint)
            } else {
                Text("closed")
                    .font(TPFont.ui(11, .semibold))
                    .foregroundColor(.tpCreamFaint)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(challenge.progressLabel)
                .font(TPFont.figure(11.5, .bold))
                .foregroundColor(.tpCreamDim)

            Spacer(minLength: 4)

            Text("\(Int((challenge.progress * 100).rounded()))%")
                .font(TPFont.figure(11.5, .bold))
                .foregroundColor(accent)
        }
    }
}
