// LockInTheme.swift
// Design tokens. Dark navy palette — serious, crisp, mission-control feel.
// Not wellness-app soft. Not pure black. Readable with visible depth.

import SwiftUI

enum LockInTheme {

    // MARK: - Colors
    enum Colors {
        // Backgrounds — dark navy-black with visible depth between layers
        static let background      = Color(hex: "0C0F1A")  // deep navy
        static let surface         = Color(hex: "141A28")  // card bg — visible vs background
        static let surfaceElevated = Color(hex: "1C2438")  // modal / elevated card
        static let border          = Color(hex: "28334E")  // separator

        // Primary accent — electric cornflower blue
        // Reads as "systems / precision / control" without being childish
        static let accent          = Color(hex: "4F8EF7")  // main CTA, highlights
        static let accentDim       = Color(hex: "2C5299")  // subtle accent bg tint

        // Status colors — bright and unambiguous
        static let accentRed       = Color(hex: "FF453A")  // failure / danger
        static let accentGreen     = Color(hex: "30D158")  // success / on-track
        static let accentOrange    = Color(hex: "FF9F0A")  // caution / moderate risk
        static let accentYellow    = Color(hex: "FFD60A")  // warning

        // Text hierarchy
        static let textPrimary     = Color(hex: "F0F4FF")  // near-white with slight blue tint
        static let textSecondary   = Color(hex: "7D8BA8")  // muted blue-gray
        static let textTertiary    = Color(hex: "3D4860")  // very dim, labels
    }

    // MARK: - Typography
    enum Font {
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        static func title(_ size: CGFloat = 28, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        static func label(_ size: CGFloat = 14, weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}

// MARK: - Color Hex Init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Card modifier
struct CardStyle: ViewModifier {
    var elevated: Bool = false
    func body(content: Content) -> some View {
        content
            .background(elevated ? LockInTheme.Colors.surfaceElevated : LockInTheme.Colors.surface)
            .cornerRadius(LockInTheme.Radius.md)
    }
}

// MARK: - Section header
struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(LockInTheme.Colors.textTertiary)
            .tracking(1.8)
            .textCase(.uppercase)
    }
}

extension View {
    func cardStyle(elevated: Bool = false) -> some View { modifier(CardStyle(elevated: elevated)) }
    func sectionHeaderStyle() -> some View { modifier(SectionHeaderStyle()) }
    /// Subtle electric glow — use on accent-colored bold text and key UI elements
    func glowAccent(radius: CGFloat = 7) -> some View {
        shadow(color: LockInTheme.Colors.accent.opacity(0.55), radius: radius, x: 0, y: 0)
    }
    func glowGreen(radius: CGFloat = 6) -> some View {
        shadow(color: LockInTheme.Colors.accentGreen.opacity(0.5), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Shared stat row
struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = LockInTheme.Colors.textPrimary
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(LockInTheme.Font.label(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(LockInTheme.Font.mono(14, weight: .semibold))
                    .foregroundColor(valueColor)
                if let caption {
                    Text(caption)
                        .font(.system(size: 10))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Progress bar
struct LockInProgressBar: View {
    var value: Double      // 0..1
    var color: Color = LockInTheme.Colors.accent
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(LockInTheme.Colors.border)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(1, max(0, value))), height: height)
                    .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: height)
    }
}
