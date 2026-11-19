
import SwiftUI

enum AppTheme {
    
    // MARK: - Brand Colors
    
    static let lime = Color(hex: 0xC4F64D)
    static let lilac = Color(hex: 0xBC9CFF)
    static let obsidian = Color(hex: 0x111111)
    static let charcoal = Color(hex: 0x202020)
    static let offWhite = Color(hex: 0xF6F7F2)
    static let forestBlack = Color(hex: 0x102A20)
    
    // MARK: - Adaptive Colors
    
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? obsidian : offWhite
    }
    
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? charcoal : .white
    }
    
    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? offWhite : forestBlack
    }
    
    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color(hex: 0x999999)
        : Color(hex: 0x686E66)
    }
    
    // MARK: - Layout
    
    static let screenPadding: CGFloat = 24
    static let cardRadius: CGFloat = 24
    static let spacing: CGFloat = 16
}

// MARK: - Hex Color Support

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }
}
