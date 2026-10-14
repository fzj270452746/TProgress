import SwiftUI

// MARK: - Milestone celebration
//
// The one loud moment in an app that is otherwise quiet on purpose. It fires
// when a streak crosses a rung, and it is also where a freeze card gets handed
// over — the reward and its reason arrive together.

struct MilestoneCelebration: View {

    let value: Int
    let freezeCards: Int
    let onDismiss: () -> Void

    @State private var risen = false
    @State private var rays = false

    var body: some View {
        ZStack {
            Color.tpInk.opacity(0.94)
                .ignoresSafeArea()

            TPHalo(color: .tpSun, diameter: 460)
                .opacity(risen ? 1 : 0)

            VStack(spacing: 22) {
                Spacer(minLength: 0)

                emblem

                VStack(spacing: 8) {
                    Text.tpLabel(eyebrow, size: 10.5, tracking: 2.4, color: .tpSun)

                    Text("\(value) days")
                        .font(TPFont.display(46, .heavy))
                        .foregroundColor(.tpCream)

                    Text(message)
                        .font(TPFont.ui(13.5))
                        .foregroundColor(.tpCreamDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 34)
                }

                if freezeCards > 0 {
                    freezeNote
                }

                Spacer(minLength: 0)

                TPPrimaryButton(title: "Keep going", symbol: "flame.fill") {
                    onDismiss()
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(TPMotion.gentle.delay(0.05)) { risen = true }
            withAnimation(TPMotion.spring.delay(0.1)) { rays = true }
        }
    }

    // MARK: Parts

    private var emblem: some View {
        ZStack {
            // Rays, drawn outward from the same centre as the disc.
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(TPGradient.accent(.tpSun))
                        .frame(width: 3, height: rays ? 26 : 6)
                        .offset(y: -78)
                        .rotationEffect(.degrees(Double(index) * 30))
                }
            }
            .opacity(rays ? 0.85 : 0)
            .scaleEffect(risen ? 1 : 0.5)

            Circle()
                .fill(TPGradient.accent(.tpSun))
                .frame(width: 118, height: 118)
                .tpEmberGlow(.tpSun, strength: 0.7)
                .scaleEffect(risen ? 1 : 0.4)

            Circle()
                .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                .frame(width: 118, height: 118)
                .scaleEffect(risen ? 1 : 0.4)

            Image(systemName: "flame.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundColor(.tpInk.opacity(0.82))
                .scaleEffect(risen ? 1 : 0.4)
        }
        .frame(height: 190)
    }

    private var freezeNote: some View {
        HStack(spacing: 9) {
            Image(systemName: "snowflake")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.tpSky)

            Text("\(freezeCards) freeze card\(freezeCards == 1 ? "" : "s") earned")
                .font(TPFont.ui(12.5, .semibold))
                .foregroundColor(.tpCream)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.tpSky.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.tpSky.opacity(0.34), lineWidth: 1)
        )
    }

    // MARK: Copy

    private var eyebrow: String {
        switch value {
        case ..<7:   return "First mark"
        case 7:      return "One week"
        case 30:     return "One month"
        case 100:    return "One hundred"
        case 365:    return "One year"
        default:     return "Milestone"
        }
    }

    private var message: String {
        switch value {
        case ..<7:   return "The hard part is behind you. This is where it starts to hold."
        case 7:      return "A whole week without a gap. Most people never get here."
        case 30:     return "A month of returning to the same small thing."
        case 100:    return "A hundred days. This is no longer a habit you are trying on."
        case 365:    return "A year. Whatever else changed, this did not."
        default:     return "The streak is holding. Keep the log honest and it will keep counting."
        }
    }
}
