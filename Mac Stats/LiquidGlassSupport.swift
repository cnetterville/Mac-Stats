//
//  LiquidGlassSupport.swift
//  Mac Stats
//
//  Created by AI Assistant on 8/29/25.
//

import SwiftUI
import AppKit

// MARK: - macOS Version Detection
struct SystemVersionInfo {
    static let current = ProcessInfo.processInfo.operatingSystemVersion
    
    static var supportsMaterials: Bool {
        // macOS Big Sur (11.0) and later support advanced materials
        return current.majorVersion >= 11
    }
    
    static var supportsAdvancedBlur: Bool {
        // macOS Monterey (12.0) and later support enhanced blur effects
        return current.majorVersion >= 12
    }
    
    static var supportsUltraEffects: Bool {
        // macOS Ventura (13.0) and later support ultra-thin materials
        return current.majorVersion >= 13
    }
}

// MARK: - Material Types
enum LiquidGlassMaterial {
    case ultraThin
    case thin  
    case regular
    case thick
    case ultraThick
    case sidebar
    case menu
    case popover
    case headerView
    case sheet
    
    @available(macOS 10.15, *)
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .ultraThin:
            if SystemVersionInfo.supportsUltraEffects {
                return .underWindowBackground
            } else {
                return .underPageBackground
            }
        case .thin:
            return .underPageBackground
        case .regular:
            return .windowBackground
        case .thick:
            return .contentBackground
        case .ultraThick:
            return .headerView
        case .sidebar:
            return .sidebar
        case .menu:
            return .menu
        case .popover:
            return .popover
        case .headerView:
            return .headerView
        case .sheet:
            return .sheet
        }
    }
    
    var swiftUIBlurRadius: CGFloat {
        switch self {
        case .ultraThin:
            return 5
        case .thin:
            return 10
        case .regular:
            return 15
        case .thick:
            return 20
        case .ultraThick:
            return 25
        case .sidebar, .menu, .popover, .headerView, .sheet:
            return 12
        }
    }
    
    var opacity: Double {
        switch self {
        case .ultraThin:
            return 0.3
        case .thin:
            return 0.5
        case .regular:
            return 0.7
        case .thick:
            return 0.8
        case .ultraThick:
            return 0.9
        case .sidebar, .headerView:
            return 0.85
        case .menu, .popover, .sheet:
            return 0.95
        }
    }
}

// MARK: - Liquid Glass View Modifier
struct LiquidGlassModifier: ViewModifier {
    let material: LiquidGlassMaterial
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    let borderWidth: CGFloat
    let borderOpacity: Double
    
    init(
        material: LiquidGlassMaterial = .regular,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 10,
        shadowOpacity: Double = 0.1,
        borderWidth: CGFloat = 0.5,
        borderOpacity: Double = 0.2
    ) {
        self.material = material
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.borderWidth = borderWidth
        self.borderOpacity = borderOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassBackground(
                    material: material,
                    cornerRadius: cornerRadius,
                    borderWidth: borderWidth,
                    borderOpacity: borderOpacity
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 3
            )
    }
}

// MARK: - Liquid Glass Background
struct LiquidGlassBackground: NSViewRepresentable {
    let material: LiquidGlassMaterial
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderOpacity: Double
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        if SystemVersionInfo.supportsMaterials {
            // Use modern materials on supported systems
            view.material = material.nsMaterial
            view.blendingMode = .behindWindow
            view.state = .active
        } else {
            // Fallback for older systems
            view.material = .windowBackground
            view.blendingMode = .withinWindow
            view.state = .active
        }
        
        // Configure layer for rounded corners and border
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        
        if borderWidth > 0 {
            view.layer?.borderWidth = borderWidth
            view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(borderOpacity).cgColor
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // Update material if needed
        if SystemVersionInfo.supportsMaterials {
            nsView.material = material.nsMaterial
        }
        
        // Update corner radius
        nsView.layer?.cornerRadius = cornerRadius
        
        // Update border
        if borderWidth > 0 {
            nsView.layer?.borderWidth = borderWidth
            nsView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(borderOpacity).cgColor
        } else {
            nsView.layer?.borderWidth = 0
        }
    }
}

// MARK: - Fallback Glass Effect for Older Systems
struct FallbackGlassEffect: ViewModifier {
    let material: LiquidGlassMaterial
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.regularMaterial.opacity(material.opacity))
                    .blur(radius: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.primary.opacity(borderOpacity), lineWidth: borderWidth)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Liquid Glass Window Background
struct LiquidGlassWindow: NSViewRepresentable {
    let material: LiquidGlassMaterial
    let allowsVibrancy: Bool
    
    init(material: LiquidGlassMaterial = .sidebar, allowsVibrancy: Bool = true) {
        self.material = material
        self.allowsVibrancy = allowsVibrancy
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        if SystemVersionInfo.supportsMaterials {
            view.material = material.nsMaterial
            view.blendingMode = .behindWindow
        } else {
            view.material = .windowBackground
            view.blendingMode = .withinWindow
        }
        
        view.state = .active
        view.wantsLayer = true
        
        // Enable vibrancy for better text rendering
        if allowsVibrancy && SystemVersionInfo.supportsAdvancedBlur {
            view.layer?.allowsGroupOpacity = false
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if SystemVersionInfo.supportsMaterials {
            nsView.material = material.nsMaterial
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply liquid glass effect with automatic system detection
    func liquidGlass(
        material: LiquidGlassMaterial = .regular,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 10,
        shadowOpacity: Double = 0.1,
        borderWidth: CGFloat = 0.5,
        borderOpacity: Double = 0.2
    ) -> some View {
        if SystemVersionInfo.supportsMaterials {
            return AnyView(
                self.modifier(
                    LiquidGlassModifier(
                        material: material,
                        cornerRadius: cornerRadius,
                        shadowRadius: shadowRadius,
                        shadowOpacity: shadowOpacity,
                        borderWidth: borderWidth,
                        borderOpacity: borderOpacity
                    )
                )
            )
        } else {
            return AnyView(
                self.modifier(
                    FallbackGlassEffect(
                        material: material,
                        cornerRadius: cornerRadius,
                        borderWidth: borderWidth,
                        borderOpacity: borderOpacity
                    )
                )
            )
        }
    }
    
    /// Apply liquid glass window background
    func liquidGlassWindow(material: LiquidGlassMaterial = .sidebar, allowsVibrancy: Bool = true) -> some View {
        self.background(
            LiquidGlassWindow(material: material, allowsVibrancy: allowsVibrancy)
                .ignoresSafeArea(.all)
        )
    }
    
    /// Apply enhanced vibrancy for text over glass
    func glassTextVibrancy() -> some View {
        if SystemVersionInfo.supportsAdvancedBlur {
            return AnyView(
                self.foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            )
        } else {
            return AnyView(self)
        }
    }
    
    /// Apply glass toolbar style
    func glassToolbar(material: LiquidGlassMaterial = .headerView) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LiquidGlassBackground(
                    material: material,
                    cornerRadius: 0,
                    borderWidth: 0,
                    borderOpacity: 0
                )
            )
    }
}

// MARK: - Enhanced Card View with Liquid Glass
struct EnhancedCardView<Content: View>: View {
    let content: () -> Content
    let material: LiquidGlassMaterial
    let padding: CGFloat
    let cornerRadius: CGFloat
    let enableHoverEffect: Bool
    
    @State private var isHovered = false
    
    init(
        material: LiquidGlassMaterial = LiquidGlassTheme.cardMaterial,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = LiquidGlassTheme.cardCornerRadius,
        enableHoverEffect: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.material = material
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.enableHoverEffect = enableHoverEffect
    }
    
    var body: some View {
        content()
            .padding(padding)
            .liquidGlass(
                material: isHovered && enableHoverEffect ? .thin : material,
                cornerRadius: cornerRadius,
                shadowRadius: isHovered ? LiquidGlassTheme.shadowRadius * 1.5 : LiquidGlassTheme.shadowRadius,
                shadowOpacity: isHovered ? LiquidGlassTheme.shadowOpacity * 1.5 : LiquidGlassTheme.shadowOpacity
            )
            .scaleEffect(isHovered && enableHoverEffect ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                if enableHoverEffect {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Enhanced Card Header with Glass Effects
struct EnhancedCardHeaderView: View {
    let title: String
    let icon: String
    let color: Color
    let showBadge: Bool
    let badgeText: String
    
    init(
        title: String,
        icon: String,
        color: Color,
        showBadge: Bool = false,
        badgeText: String = ""
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.showBadge = showBadge
        self.badgeText = badgeText
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .glassTextVibrancy()
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .glassTextVibrancy()
            
            if showBadge && !badgeText.isEmpty {
                Text(badgeText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.2))
                    .foregroundColor(color)
                    .clipShape(Capsule())
                    .liquidGlass(
                        material: .ultraThin,
                        cornerRadius: 12,
                        shadowRadius: 2,
                        shadowOpacity: 0.1
                    )
            }
            
            Spacer()
        }
    }
}

// MARK: - Compact Stats Card with Liquid Glass
struct EnhancedCompactStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String
    
    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        subtitle: String = ""
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }
    
    var body: some View {
        EnhancedCardView(
            material: .thin,
            padding: 12,
            cornerRadius: 10
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title3)
                        .glassTextVibrancy()
                    
                    Spacer()
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .glassTextVibrancy()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .glassTextVibrancy()
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .glassTextVibrancy()
                    }
                }
            }
        }
    }
}

// MARK: - Glass Info Row
struct GlassInfoRowView: View {
    let label: String
    let value: String
    let valueColor: Color
    let showSeparator: Bool
    
    init(
        label: String,
        value: String,
        valueColor: Color = .primary,
        showSeparator: Bool = false
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.showSeparator = showSeparator
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .glassTextVibrancy()
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
                    .glassTextVibrancy()
            }
            
            if showSeparator {
                Divider()
                    .opacity(0.5)
            }
        }
    }
}

// MARK: - Glass Progress View
struct GlassProgressView: View {
    let value: Double
    let total: Double
    let color: Color
    let height: CGFloat
    let showPercentage: Bool
    
    init(
        value: Double,
        total: Double,
        color: Color = .blue,
        height: CGFloat = 8,
        showPercentage: Bool = false
    ) {
        self.value = value
        self.total = total
        self.color = color
        self.height = height
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showPercentage {
                HStack {
                    Spacer()
                    Text("\(Int((value / total) * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .glassTextVibrancy()
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: height)
                    
                    // Progress fill with glass effect
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.8),
                                    color
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geometry.size.width * (value / total), geometry.size.width)), height: height)
                        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Glass Sparkline View
struct GlassSparklineView: View {
    let data: [Double]
    let lineColor: Color
    let lineWidth: CGFloat
    let fillGradient: Bool
    
    init(
        data: [Double],
        lineColor: Color = .blue,
        lineWidth: CGFloat = 2,
        fillGradient: Bool = true
    ) {
        self.data = data
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.fillGradient = fillGradient
    }
    
    var body: some View {
        GeometryReader { geometry in
            if !data.isEmpty && data.count > 1 {
                let maxValue = data.max() ?? 1
                let minValue = data.min() ?? 0
                let range = maxValue - minValue
                let adjustedRange = range > 0 ? range : 1
                
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                        let normalizedValue = range > 0 ? (value - minValue) / adjustedRange : 0.5
                        let y = geometry.size.height - (normalizedValue * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, lineWidth: lineWidth)
                .shadow(color: lineColor.opacity(0.3), radius: 1, x: 0, y: 1)
                
                if fillGradient {
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                            let normalizedValue = range > 0 ? (value - minValue) / adjustedRange : 0.5
                            let y = geometry.size.height - (normalizedValue * geometry.size.height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                lineColor.opacity(0.3),
                                lineColor.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Glass-Enhanced Components
struct GlassButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    let material: LiquidGlassMaterial
    let isDestructive: Bool
    
    init(
        action: @escaping () -> Void,
        material: LiquidGlassMaterial = .thin,
        isDestructive: Bool = false,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
        self.material = material
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundColor(isDestructive ? .red : .primary)
                .glassTextVibrancy()
        }
        .buttonStyle(.plain)
        .liquidGlass(
            material: material,
            cornerRadius: 8,
            shadowRadius: 4,
            shadowOpacity: 0.15
        )
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

struct GlassToggle: View {
    @Binding var isOn: Bool
    let title: String
    let material: LiquidGlassMaterial
    
    init(_ title: String, isOn: Binding<Bool>, material: LiquidGlassMaterial = .thin) {
        self.title = title
        self._isOn = isOn
        self.material = material
    }
    
    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlass(material: material, cornerRadius: 8)
    }
}

// MARK: - Glass Theme Configuration
struct LiquidGlassTheme {
    static let cardMaterial: LiquidGlassMaterial = SystemVersionInfo.supportsUltraEffects ? .thin : .regular
    static let headerMaterial: LiquidGlassMaterial = .headerView
    static let sidebarMaterial: LiquidGlassMaterial = .sidebar
    static let windowMaterial: LiquidGlassMaterial = .sidebar
    
    static let defaultCornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 8
    
    static let shadowRadius: CGFloat = SystemVersionInfo.supportsAdvancedBlur ? 12 : 8
    static let shadowOpacity: Double = SystemVersionInfo.supportsAdvancedBlur ? 0.15 : 0.1
}

// MARK: - Global Toggle for Liquid Glass Effects
class LiquidGlassSettings: ObservableObject {
    @Published var isEnabled: Bool
    
    init() {
        // Enable liquid glass by default on supported systems
        self.isEnabled = SystemVersionInfo.supportsMaterials
    }
    
    func toggle() {
        isEnabled.toggle()
    }
}