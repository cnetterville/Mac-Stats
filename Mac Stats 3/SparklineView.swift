//
//  SparklineView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

// Simple sparkline view for single data series
struct SparklineView: View {
    let data: [Double]
    let lineColor: Color
    let lineWidth: CGFloat
    
    init(data: [Double], lineColor: Color = .blue, lineWidth: CGFloat = 2.0) {
        self.data = data
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            if data.count < 2 {
                // Not enough data to draw a line
                Rectangle()
                    .fill(Color.clear)
            } else {
                Path { path in
                    let maxValue = data.max() ?? 1
                    let minValue = data.min() ?? 0
                    let range = maxValue - minValue
                    let effectiveRange = range > 0 ? range : 1
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(data.count - 1)
                    
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue = (value - minValue) / effectiveRange
                        let y = height * (1 - normalizedValue) // Invert Y to have higher values at top
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, lineWidth: lineWidth)
            }
        }
    }
}

// Multi-series sparkline view for multiple data series
struct MultiSeriesSparklineView: View {
    let series: [(data: [Double], color: Color)]
    let lineWidth: CGFloat
    
    init(series: [(data: [Double], color: Color)], lineWidth: CGFloat = 2.0) {
        self.series = series
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Find global min/max across all series for consistent scaling
            let allValues = series.flatMap { $0.data }
            
            if allValues.count < 2 {
                Rectangle()
                    .fill(Color.clear)
            } else {
                let maxValue = allValues.max() ?? 1
                let minValue = allValues.min() ?? 0
                let range = maxValue - minValue
                let effectiveRange = range > 0 ? range : 1
                
                ZStack {
                    ForEach(Array(series.enumerated()), id: \.offset) { index, seriesData in
                        if seriesData.data.count >= 2 {
                            Path { path in
                                let width = geometry.size.width
                                let height = geometry.size.height
                                let stepX = width / CGFloat(seriesData.data.count - 1)
                                
                                for (dataIndex, value) in seriesData.data.enumerated() {
                                    let x = CGFloat(dataIndex) * stepX
                                    let normalizedValue = (value - minValue) / effectiveRange
                                    let y = height * (1 - normalizedValue) // Invert Y
                                    
                                    if dataIndex == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(seriesData.color, lineWidth: lineWidth)
                        }
                    }
                }
            }
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