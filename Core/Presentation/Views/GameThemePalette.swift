import SwiftUI

enum GameThemePalette {
    static let chickenGoldenYellow = Color(hex: "#FFD700")
    static let chickenWhite = Color(hex: "#FFFFFF")
    static let chickenSkyBlue = Color(hex: "#00AEEF")
    static let chickenRed = Color(hex: "#E31E24")
    static let chickenDeepOrange = Color(hex: "#F58220")
    static let chickenSkyTop = Color(hex: "#0071BC")
    static let chickenSkyBottom = Color(hex: "#EAFBFF")
    static let chickenTextPrimary = Color(hex: "#F7FCFF")

    static var skyBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                chickenSkyTop,
                chickenSkyBlue,
                chickenSkyBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var goldControlGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#FFF200"),
                Color(hex: "#F7941D")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var fireAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                chickenWhite,
                Color(hex: "#FFF200"),
                chickenDeepOrange,
                chickenRed
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardSurfaceBackground: Color {
        chickenSkyTop.opacity(0.36)
    }

    static var elevatedCardSurfaceBackground: Color {
        chickenSkyTop.opacity(0.48)
    }

    static var destructiveSurfaceBackground: Color {
        chickenRed.opacity(0.4)
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intValue: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&intValue)

        let red, green, blue: UInt64
        switch sanitized.count {
        case 3:
            red = (intValue >> 8) * 17
            green = ((intValue >> 4) & 0xF) * 17
            blue = (intValue & 0xF) * 17
        case 6:
            red = intValue >> 16
            green = (intValue >> 8) & 0xFF
            blue = intValue & 0xFF
        default:
            red = 255
            green = 255
            blue = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}
