import SwiftUI

/// App-wide custom font. Register the bundled TTF file under `UIAppFonts`.
enum AppTypography {
    /// PostScript name resolved from the embedded TTF metadata.
    static let appPostScriptName = "PlumbSoft-Black"

    static func appFont(size: CGFloat) -> Font {
        Font.custom(appPostScriptName, size: size)
    }

    static var largeTitle: Font { appFont(size: 34) }
    static var title: Font { appFont(size: 28) }
    static var title2: Font { appFont(size: 22) }
    static var title3: Font { appFont(size: 20) }
    static var headline: Font { appFont(size: 17) }
    static var body: Font { appFont(size: 17) }
    static var callout: Font { appFont(size: 16) }
    static var subheadline: Font { appFont(size: 15) }
    static var footnote: Font { appFont(size: 13) }
    static var caption: Font { appFont(size: 12) }
    static var caption2: Font { appFont(size: 11) }
    /// Tab bar item titles
    static var tabBar: Font { appFont(size: 10) }
}

#if canImport(UIKit)
import UIKit

extension AppTypography {
    static func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont(name: appPostScriptName, size: size)
            ?? .systemFont(ofSize: size, weight: weight)
    }

    static func applyAppTabBarTitles(appearance: UITabBarAppearance, titleColor: UIColor = .label) {
        let font = uiFont(size: 10)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: titleColor]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = attrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = attrs
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = attrs
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = attrs
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = attrs
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = attrs
    }
}
#endif
