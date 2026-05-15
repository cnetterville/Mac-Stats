//
//  SparklineView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Charts

// Single-series sparkline using Swift Charts.
struct SparklineView: View {
    let data: [Double]
    let lineColor: Color
    let lineWidth: CGFloat
    var fixedMin: Double? = nil
    var fixedMax: Double? = nil

    init(data: [Double], lineColor: Color = .blue, lineWidth: CGFloat = 2.0,
         fixedMin: Double? = nil, fixedMax: Double? = nil) {
        self.data = data
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.fixedMin = fixedMin
        self.fixedMax = fixedMax
    }

    private var yDomain: ClosedRange<Double> {
        let lo = fixedMin ?? data.min() ?? 0
        let hi = fixedMax ?? data.max() ?? 1
        return lo == hi ? lo...(lo + 1) : lo...hi
    }

    var body: some View {
        if data.count < 2 {
            Rectangle().fill(Color.clear)
        } else {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    AreaMark(
                        x: .value("i", index),
                        y: .value("v", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.45), lineColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("i", index),
                        y: .value("v", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }

                if let last = data.last {
                    PointMark(
                        x: .value("i", data.count - 1),
                        y: .value("v", last)
                    )
                    .foregroundStyle(lineColor)
                    .symbolSize(20)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...(data.count - 1))
            .chartYScale(domain: yDomain)
            .chartPlotStyle { $0.background(Color.clear) }
        }
    }
}

// Multi-series sparkline using Swift Charts.
struct MultiSeriesSparklineView: View {
    let series: [(data: [Double], color: Color)]
    let lineWidth: CGFloat

    init(series: [(data: [Double], color: Color)], lineWidth: CGFloat = 2.0) {
        self.series = series
        self.lineWidth = lineWidth
    }

    private var allValues: [Double] { series.flatMap { $0.data } }

    private var yDomain: ClosedRange<Double> {
        let lo = allValues.min() ?? 0
        let hi = allValues.max() ?? 1
        return lo == hi ? lo...(lo + 1) : lo...hi
    }

    private var maxSamples: Int {
        series.map { $0.data.count }.max() ?? 0
    }

    var body: some View {
        if allValues.count < 2 {
            Rectangle().fill(Color.clear)
        } else {
            Chart {
                ForEach(Array(series.enumerated()), id: \.offset) { seriesIndex, seriesData in
                    ForEach(Array(seriesData.data.enumerated()), id: \.offset) { i, value in
                        LineMark(
                            x: .value("i", i),
                            y: .value("v", value),
                            series: .value("s", seriesIndex)
                        )
                        .foregroundStyle(seriesData.color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth))
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...max(1, maxSamples - 1))
            .chartYScale(domain: yDomain)
            .chartPlotStyle { $0.background(Color.clear) }
        }
    }
}

#if DEBUG
// Preview for SparklineView
struct SparklineView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Single series sparkline
            SparklineView(
                data: [10, 20, 15, 30, 25, 40, 35, 50, 45, 60],
                lineColor: .blue,
                lineWidth: 2
            )
            .frame(height: 40)
            .padding()
            
            // Multi-series sparkline
            MultiSeriesSparklineView(
                series: [
                    (data: [10, 15, 20, 25, 30, 35, 40], color: .red),
                    (data: [5, 10, 15, 20, 15, 10, 5], color: .blue)
                ],
                lineWidth: 2
            )
            .frame(height: 40)
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif