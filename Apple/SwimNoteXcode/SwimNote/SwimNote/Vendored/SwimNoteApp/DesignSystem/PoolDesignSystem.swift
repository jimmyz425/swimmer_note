import SwiftUI

/// SwimNote Design System - Pantone 2026 Inspired Pool Theme
/// Adaptive color system supporting both light and dark modes
///
/// Light Mode (Pool theme - calm, water-inspired):
/// - 云上舞白 (#F0F4F8) - Light background
/// - 深青绿 (#006D6F) - Primary accent
/// - 冰川蓝 (#A3D9E8) - Secondary accent
///
/// Dark Mode (Deep pool theme - elegant night swim):
/// - 深夜蓝 (#0D1B2A) - Dark background (ocean depth)
/// - 薄荷青 (#2ECC71) - Primary accent (bioluminescent glow)
/// - 钴蓝 (#1B4965) - Secondary accent
enum PoolTheme {

    // MARK: - Adaptive Colors (Light/Dark)

    /// Surface background - adaptive
    /// Light: 云上舞白 (#F0F4F8) - Soft white
    /// Dark: 深夜蓝 (#0D1B2A) - Deep ocean
    static var surface: Color {
        Color(light: Color(hex: "#F0F4F8"), dark: Color(hex: "#0D1B2A"))
    }

    /// Light accent / card backgrounds - adaptive
    /// Light: 冰川蓝 (#A3D9E8) - Ice blue
    /// Dark: 钴蓝 (#1B4965) - Cobalt
    static var light: Color {
        Color(light: Color(hex: "#A3D9E8"), dark: Color(hex: "#1B4965"))
    }

    /// Primary accent - adaptive
    /// Light: 深青绿 (#006D6F) - Teal
    /// Dark: 薄荷青 (#2ECC71) - Bioluminescent mint (brighter for contrast)
    static var mid: Color {
        Color(light: Color(hex: "#006D6F"), dark: Color(hex: "#2ECC71"))
    }

    /// Primary text - adaptive
    /// Light: 石墨灰 (#2D3748) - Graphite
    /// Dark: 云雾白 (#E8ECF0) - Soft white
    static var deep: Color {
        Color(light: Color(hex: "#2D3748"), dark: Color(hex: "#E8ECF0"))
    }

    /// Secondary text - adaptive
    /// Light: 烟灰色 (#718096) - Smoke gray
    /// Dark: 银雾 (#A0AEC0) - Silver mist
    static var smoke: Color {
        Color(light: Color(hex: "#718096"), dark: Color(hex: "#A0AEC0"))
    }

    /// Gold accent - unchanged for both modes (high contrast)
    static let gold = Color(red: 1.0, green: 0.71, blue: 0.16)

    // MARK: - Dark Mode Specific Colors

    /// Card background for dark mode - slightly elevated
    static var cardSurface: Color {
        Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#162233"))
    }

    /// Elevated surface - for sheets and overlays
    static var elevated: Color {
        Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1A2D42"))
    }

    /// Border color - adaptive
    static var border: Color {
        Color(light: Color(hex: "#A3D9E8").opacity(0.45), dark: Color(hex: "#2ECC71").opacity(0.3))
    }

    /// Shadow color - adaptive
    static var shadow: Color {
        Color(light: Color(hex: "#2D3748").opacity(0.08), dark: Color(hex: "#000000").opacity(0.3))
    }

    // MARK: - Typography Sizes

    static let fontSizeLargeTitle: CGFloat = 34
    static let fontSizeTitle2: CGFloat = 22
    static let fontSizeTitle3: CGFloat = 20
    static let fontSizeHeadline: CGFloat = 17
    static let fontSizeBody: CGFloat = 17
    static let fontSizeSubheadline: CGFloat = 15
    static let fontSizeCaption: CGFloat = 12
    static let fontSizeCaption2: CGFloat = 11

    // MARK: - Segment Colors (Zone-based, work in both modes)

    /// Warm-up segment color
    static var warmUp: Color { .green }

    /// Drill segment color
    static var drill: Color { mid }

    /// Main set segment color
    static var mainSet: Color { .orange }

    /// Secondary segment color
    static var secondary: Color { .purple }

    /// Cool-down segment color
    static var coolDown: Color { .blue }
}

// MARK: - Adaptive Color Extension

extension Color {
    /// Creates an adaptive color for light and dark mode
    init(light: Color, dark: Color) {
        self.init(
            UIColor { traits in
                switch traits.userInterfaceStyle {
                case .dark:
                    return UIColor(dark)
                default:
                    return UIColor(light)
                }
            }
        )
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Pool Card Modifier (Adaptive)

struct PoolCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PoolTheme.cardSurface)
                    .shadow(color: PoolTheme.shadow, radius: 8, x: 0, y: 4)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PoolTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func poolCard() -> some View {
        modifier(PoolCard())
    }
}

// MARK: - Preview Helpers

/// Container view for previewing components in both light and dark mode
struct ThemePreview<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content
                .background(PoolTheme.surface)
                .environment(\.colorScheme, .light)

            Divider()

            content
                .background(PoolTheme.surface)
                .environment(\.colorScheme, .dark)
        }
    }
}