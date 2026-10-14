import SwiftUI

// MARK: - Chart card
//
// The shell every statistic sits in: a small label, a display-weight title, a
// sentence explaining what is being shown, then the chart. It started life
// private to the recap page; the dashboard and the year review draw the same
// card, so the shape lives here where all three can reach it.

struct TPChartCard<Content: View>: View {

    let label: String
    let title: String
    var caption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text.tpLabel(label)

                Text(title)
                    .font(TPFont.display(19, .bold))
                    .foregroundColor(.tpCream)

                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }
}
