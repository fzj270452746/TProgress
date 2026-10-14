import SwiftUI

// MARK: - Heatmap
//
// A year of showing up, one cell a day. There is no component for this in the
// design system and no `Grid` before iOS 16, so the columns are built out of an
// HStack of VStacks — which is also what keeps it cheap: the grid only ever
// lays out numbers, never views that read Core Data.
//
// Intensity comes from how many circles were logged that day, so it reads the
// same whether a circle measures itself in pages, kilometres or minutes.

struct TPHeatmap: View {

    /// One entry per week, oldest first, each holding seven day values.
    /// `-1` marks a day that has not happened yet.
    let columns: [[Double]]

    var weekdayLabels: [String] = []
    var monthLabels: [Int: String] = [:]
    var accent: Color = .tpEmber
    var cellSize: CGFloat = 10

    /// Tightened for the year card, which has to fit 53 columns across a phone.
    var spacing: CGFloat = 3

    private var labelColumn: CGFloat { weekdayLabels.isEmpty ? 0 : cellSize + 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                if !weekdayLabels.isEmpty { weekdayColumn }

                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: spacing) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, value in
                                cell(value)
                            }
                        }
                    }
                }
            }

            if !monthLabels.isEmpty { monthRow }
        }
    }

    // MARK: Parts

    private var weekdayColumn: some View {
        VStack(spacing: spacing) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                // Every other row, or the labels collide at this cell size.
                Text(index % 2 == 0 ? label : " ")
                    .font(TPFont.ui(8, .semibold))
                    .foregroundColor(.tpCreamFaint)
                    .frame(width: cellSize + 6, height: cellSize, alignment: .trailing)
            }
        }
    }

    private var monthRow: some View {
        HStack(spacing: spacing) {
            if labelColumn > 0 {
                Color.clear.frame(width: labelColumn - 6, height: 1)
            }

            ForEach(Array(columns.indices), id: \.self) { index in
                // `fixedSize` has to come before the frame, or the label is laid
                // out inside a cell-width box and breaks one letter to a line.
                Text(monthLabels[index] ?? "")
                    .font(TPFont.ui(8.5, .semibold))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize()
                    .frame(width: cellSize, alignment: .leading)
            }
        }
    }

    private func cell(_ value: Double) -> some View {
        RoundedRectangle(cornerRadius: cellSize * 0.24, style: .continuous)
            .fill(fill(for: value))
            .frame(width: cellSize, height: cellSize)
    }

    private func fill(for value: Double) -> Color {
        if value < 0 { return .clear }
        if value == 0 { return Color.tpInkWell }
        return accent.opacity(max(0.34, value))
    }
}

// MARK: - Legend

/// The four-step key that sits under a heatmap.
struct TPHeatmapLegend: View {

    var accent: Color = .tpEmber
    var cellSize: CGFloat = 10
    var leading: String = "Less"
    var trailing: String = "More"

    var body: some View {
        HStack(spacing: 6) {
            Text(leading)
                .font(TPFont.ui(9.5))
                .foregroundColor(.tpCreamFaint)

            ForEach([0.0, 0.34, 0.62, 1.0], id: \.self) { step in
                RoundedRectangle(cornerRadius: cellSize * 0.24, style: .continuous)
                    .fill(step == 0 ? Color.tpInkWell : accent.opacity(max(0.34, step)))
                    .frame(width: cellSize, height: cellSize)
            }

            Text(trailing)
                .font(TPFont.ui(9.5))
                .foregroundColor(.tpCreamFaint)
        }
    }
}
