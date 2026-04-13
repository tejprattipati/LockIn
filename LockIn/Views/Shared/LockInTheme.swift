// LockInTheme.swift
// Centralised design tokens for the app's minimal, dark, disciplined aesthetic.

import SwiftUI

enum LockInTheme {
    // MARK: - Colors
    enum Colors {
        static let background     = Color(hex: "0A0A0A")   // near-black
        static let surface        = Color(hex: "141414")   // card background
        static let surfaceElevated = Color(hex: "1C1C1E")  // slightly lighter card
        static let border         = Color(hex: "2C2C2E")   // subtle separator
        static let accent         = Color(hex: "D4A843")   // warm gold — discipline, not aggression
        static let accentRed      = Color(hex: "E8453C")   // failure / warning
        static let accentGreen    = Color(hex: "34C759")   // success
        static let accentOrange   = Color(hex: "FF9500")   // caution
        static let textPrimary    = Color.white
        static let textSecondary  = Color(hex: "8E8E93")
        static let textTertiary   = Color(hex: "48484A")
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
        static let xs: CGFloat   = 4
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 16
        static let lg: CGFloat   = 24
        static let xl: CGFloat   = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    var elevated: Bool = false
    func body(content: Content) -> some View {
        content
            .background(elevated ? LockInTheme.Colors.surfaceElevated : LockInTheme.Colors.surface)
            .cornerRadius(LockInTheme.Radius.md)
    }
}

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold, design: .default))
            .foregroundColor(LockInTheme.Colors.textSecondary)
            .tracking(1.5)
            .textCase(.uppercase)
    }
}

extension View {
    func cardStyle(elevated: Bool = false) -> some View {
        modifier(CardStyle(elevated: elevated))
    }
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Reusable stat row
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
            }
        }
        .frame(height: height)
    }
}
