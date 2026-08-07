import SwiftUI

enum AppTheme {
    static let blue = Color(hex: 0x4464FF)
    static let blueDeep = Color(hex: 0x2F4CE5)
    static let blueSoft = Color(hex: 0xEEF1FF)
    static let background = Color(hex: 0xF7F7FA)
    static let card = Color.white
    static let ink = Color(hex: 0x15192B)
    static let secondary = Color(hex: 0x75798C)
    static let line = Color(hex: 0xE9EAF0)
    static let positive = Color(hex: 0x21B978)
    static let negative = Color(hex: 0xEF5B64)
    static let warning = Color(hex: 0xF0A23A)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.7), lineWidth: 0.5)
            }
            .shadow(color: AppTheme.ink.opacity(0.045), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func appCard(padding: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding))
    }
}
