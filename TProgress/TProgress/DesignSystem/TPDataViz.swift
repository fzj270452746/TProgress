import SwiftUI
import UIKit
import DGCharts

// MARK: - Ring
//
// The workhorse progress control. Drawn natively so it can carry gradient,
// tick marks and a rounded cap that DGCharts has no equivalent for.

struct TPRing: View {

    var progress: Double
    var size: CGFloat = 74
    var lineWidth: CGFloat = 7
    var colors: [Color] = [.tpEmber, .tpSun]
    var trackColor: Color = .tpLine
    var showsTicks: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor.opacity(0.55), lineWidth: lineWidth)

            if showsTicks {
                ForEach(0..<28, id: \.self) { index in
                    Rectangle()
                        .fill(tickColor(index))
                        .frame(width: 1.4, height: lineWidth * 0.30)
                        .offset(y: -size / 2 + lineWidth * 0.15)
                        .rotationEffect(.degrees(Double(index) / 28 * 360))
                }
            }

            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: colors + [colors.first ?? .tpEmber]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(TPMotion.spring, value: clamped)
        }
        .frame(width: size, height: size)
    }

    private func tickColor(_ index: Int) -> Color {
        let fraction = Double(index) / 28
        return fraction <= clamped ? colors.first?.opacity(0.85) ?? .tpEmber : .tpCreamFaint.opacity(0.18)
    }
}

// MARK: - Bars

/// Horizontal meter used for habit cadence and stage completion.
struct TPMeter: View {

    var progress: Double
    var height: CGFloat = 8
    var color: Color = .tpEmber
    var trackColor: Color = .tpInkWell

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(TPGradient.accent(color))
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
                    .animation(TPMotion.spring, value: progress)
            }
        }
        .frame(height: height)
    }
}

/// Seven columns for the last week. Today is the last column and is outlined.
struct TPWeekColumns: View {

    var values: [Double]
    var labels: [String]
    var color: Color = .tpEmber
    var height: CGFloat = 56

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let isToday = index == values.count - 1
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.tpInkWell)
                            .frame(height: height)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(TPGradient.accent(color))
                            .frame(height: max(4, CGFloat(min(max(value, 0), 1)) * height))
                            .opacity(isToday ? 1 : 0.62)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(isToday ? color : Color.clear, lineWidth: 1.2)
                    )

                    Text(labels.indices.contains(index) ? labels[index] : "")
                        .font(.system(size: 9, weight: isToday ? .bold : .medium))
                        .foregroundColor(isToday ? color : .tpCreamFaint)
                }
            }
        }
    }
}

/// A streak strip: one dot per day, filled when the day was kept.
struct TPStreakDots: View {

    var total: Int
    var filled: Int
    var color: Color = .tpSun
    var dotSize: CGFloat = 7

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? color : Color.tpCreamFaint.opacity(0.22))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle().strokeBorder(
                            index == filled - 1 ? color.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                        .padding(-2.5)
                    )
            }
        }
    }
}

// MARK: - Charts (DGCharts)
//
// The three charts the stage summary needs. Styled down to hairlines so they
// read as part of the app rather than as a stock library.

/// Shared styling so every chart sits on the same ground.
private enum ChartStyle {

    static let background = UIColor.clear
    static let grid = UIColor(Color.tpLine)
    static let label = UIColor(Color.tpCreamFaint)
    static let labelFont = UIFont.systemFont(ofSize: 10, weight: .medium)

    static func prepare(_ chart: ChartViewBase) {
        chart.backgroundColor = background
        chart.chartDescription.enabled = false
        chart.legend.enabled = false
        chart.noDataText = ""
        chart.highlightPerTapEnabled = false
        chart.extraLeftOffset = 4
        chart.extraRightOffset = 4
    }

    /// Zoom and pan live on the bar/line base class, not on `ChartViewBase`.
    static func prepareBarLine(_ chart: BarLineChartViewBase) {
        prepare(chart)
        chart.setScaleEnabled(false)
        chart.dragEnabled = false
        chart.pinchZoomEnabled = false
        chart.doubleTapToZoomEnabled = false
    }
}

/// Smoothed trend line for a stage summary.
struct TPLineChart: UIViewRepresentable {

    var values: [Double]
    var labels: [String]
    var color: Color = .tpEmber
    var showsLabels: Bool = true

    func makeUIView(context: Context) -> LineChartView {
        let chart = LineChartView()
        ChartStyle.prepareBarLine(chart)
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.drawAxisLineEnabled = false
        chart.xAxis.labelTextColor = ChartStyle.label
        chart.xAxis.labelFont = ChartStyle.labelFont
        chart.xAxis.granularity = 1
        chart.xAxis.labelCount = max(2, labels.count)

        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.gridColor = ChartStyle.grid
        chart.leftAxis.gridLineDashLengths = [3, 6]
        chart.leftAxis.drawAxisLineEnabled = false
        chart.leftAxis.drawLabelsEnabled = false
        chart.rightAxis.enabled = false

        return chart
    }

    func updateUIView(_ chart: LineChartView, context: Context) {
        guard !values.isEmpty else {
            chart.data = nil
            return
        }

        let entries = values.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }
        let set = LineChartDataSet(entries: entries, label: "")
        let uiColor = UIColor(color)

        set.colors = [uiColor]
        set.lineWidth = 2.6
        set.mode = .cubicBezier
        set.drawCirclesEnabled = true
        set.circleRadius = 3.2
        set.circleColors = [uiColor]
        set.circleHoleColor = UIColor(Color.tpInk)
        set.circleHoleRadius = 1.4
        set.drawValuesEnabled = false
        set.drawFilledEnabled = true
        set.fillColor = uiColor
        set.fillAlpha = 0.16

        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: showsLabels ? labels : [])
        chart.data = LineChartData(dataSets: [set])
        chart.animate(xAxisDuration: 0.85, yAxisDuration: 0.85, easingOption: .easeOutCubic)
    }
}

/// Weekly comparison bars for stage summaries.
struct TPBarChart: UIViewRepresentable {

    var values: [Double]
    var labels: [String]
    var colors: [Color] = [.tpEmber]

    func makeUIView(context: Context) -> BarChartView {
        let chart = BarChartView()
        ChartStyle.prepareBarLine(chart)
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.drawAxisLineEnabled = false
        chart.xAxis.labelTextColor = ChartStyle.label
        chart.xAxis.labelFont = ChartStyle.labelFont
        chart.xAxis.granularity = 1

        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.gridColor = ChartStyle.grid
        chart.leftAxis.gridLineDashLengths = [3, 6]
        chart.leftAxis.drawAxisLineEnabled = false
        chart.leftAxis.drawLabelsEnabled = false
        chart.rightAxis.enabled = false

        return chart
    }

    func updateUIView(_ chart: BarChartView, context: Context) {
        guard !values.isEmpty else {
            chart.data = nil
            return
        }

        let entries = values.enumerated().map { BarChartDataEntry(x: Double($0.offset), y: $0.element) }
        let set = BarChartDataSet(entries: entries, label: "")
        set.colors = colors.map { UIColor($0) }
        set.drawValuesEnabled = false
        set.highlightAlpha = 0

        let data = BarChartData(dataSets: [set])
        data.barWidth = 0.5

        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chart.data = data
        chart.animate(yAxisDuration: 0.75, easingOption: .easeOutCubic)
    }
}

/// Donut used for "where your time went".
struct TPDonutChart: UIViewRepresentable {

    struct Slice {
        var label: String
        var value: Double
        var color: Color
    }

    var slices: [Slice]

    func makeUIView(context: Context) -> PieChartView {
        let chart = PieChartView()
        ChartStyle.prepare(chart)
        chart.holeRadiusPercent = 0.62
        chart.transparentCircleRadiusPercent = 0
        chart.rotationEnabled = false
        chart.entryLabelColor = ChartStyle.label
        chart.entryLabelFont = ChartStyle.labelFont
        chart.drawEntryLabelsEnabled = false
        return chart
    }

    func updateUIView(_ chart: PieChartView, context: Context) {
        guard !slices.isEmpty else {
            chart.data = nil
            return
        }

        let entries = slices.map { PieChartDataEntry(value: $0.value, label: $0.label) }
        let set = PieChartDataSet(entries: entries, label: "")
        set.colors = slices.map { UIColor($0.color) }
        set.sliceSpace = 3
        set.drawValuesEnabled = false

        let data = PieChartData(dataSets: [set])
        data.setDrawValues(false)

        chart.data = data
        chart.animate(xAxisDuration: 0.9, easingOption: .easeOutCubic)
    }
}
