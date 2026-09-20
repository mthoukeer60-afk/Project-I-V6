import SwiftUI
import UIKit

enum AppTheme {
    static let primary = adaptive(light: 0x356B5B, dark: 0x8FD3B8)
    static let primaryPressed = adaptive(light: 0x285548, dark: 0xA8E4CA)

    static let background = adaptive(light: 0xF7F8F6, dark: 0x0D1110)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x151B19)
    static let elevatedSurface = adaptive(light: 0xF0F3F0, dark: 0x1C2421)

    static let primaryText = adaptive(light: 0x17201D, dark: 0xF2F5F3)
    static let onPrimary = adaptive(light: 0xFFFFFF, dark: 0x17201D)
    static let secondaryText = adaptive(light: 0x68736F, dark: 0x9DAAA5)
    static let tertiaryText = adaptive(light: 0x929B97, dark: 0x6F7B76)

    static let border = adaptive(light: 0xDDE3DF, dark: 0x29332F)
    static let divider = adaptive(light: 0xE8ECE9, dark: 0x202925)

    static let completed = adaptive(light: 0x3E8E70, dark: 0x72C7A4)
    static let success = adaptive(light: 0x31805F, dark: 0x6DCA9F)
    static let warning = adaptive(light: 0xB9853B, dark: 0xE2B96D)
    static let error = adaptive(light: 0xB95353, dark: 0xF07F7F)
    static let info = adaptive(light: 0x547D91, dark: 0x82B8D0)

    static let shadow = adaptive(
        light: 0x17201D,
        dark: 0x000000,
        lightAlpha: 0.08,
        darkAlpha: 0.24
    )

    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            }
            return UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension View {
    func istiqamahCard() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.border)
            }
            .shadow(color: AppTheme.shadow, radius: 14, y: 6)
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
