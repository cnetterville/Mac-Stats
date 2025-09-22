//
//  CardView.swift
//  Mac Stats
//
//  Created by AI Assistant on 8/29/25.
//  Backward-compatible CardView with optional liquid glass support
//

import SwiftUI

// MARK: - Backward Compatible CardView
struct CardView<Content: View>: View {
    let content: () -> Content
    let enableLiquidGlass: Bool
    
    init(enableLiquidGlass: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.enableLiquidGlass = enableLiquidGlass
    }
    
    var body: some View {
        if enableLiquidGlass {
            // Use new liquid glass design
            EnhancedCardView(content: content)
        } else {
            // Use original design for compatibility
            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Backward Compatible Card Header
struct CardHeaderView: View {
    let title: String
    let icon: String
    let color: Color
    let enableGlassEffects: Bool
    
    init(title: String, icon: String, color: Color, enableGlassEffects: Bool = true) {
        self.title = title
        self.icon = icon
        self.color = color
        self.enableGlassEffects = enableGlassEffects
    }
    
    var body: some View {
        if enableGlassEffects {
            EnhancedCardHeaderView(title: title, icon: icon, color: color)
        } else {
            // Original design
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
    }
}

// MARK: - Backward Compatible Info Row
struct InfoRowView: View {
    let label: String
    let value: String
    let valueColor: Color
    let enableGlassEffects: Bool
    
    init(
        label: String,
        value: String,
        valueColor: Color = .primary,
        enableGlassEffects: Bool = true
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.enableGlassEffects = enableGlassEffects
    }
    
    var body: some View {
        if enableGlassEffects {
            GlassInfoRowView(label: label, value: value, valueColor: valueColor)
        } else {
            // Original design
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
        }
    }
}