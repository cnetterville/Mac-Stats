//
//  CompactStatsCard.swift
//  Mac Stats
//
//  Created by Mac Stats on Current Date
//

import SwiftUI

struct CompactStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?
    
    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(value)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                }
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}