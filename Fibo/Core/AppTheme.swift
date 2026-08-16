import SwiftUI

enum AppTheme {
    static let primary = Color(hex: 0x6817E8)
    static let primaryDeep = Color(hex: 0x25104D)
    static let primarySoft = Color(hex: 0xF1EAFF)
    static let lime = Color(hex: 0xC9FF00)
    static let limeDeep = Color(hex: 0x425500)
    static let background = Color(hex: 0xFAF9F5)
    /// Surface des cartes : transparente, les blocs se détachent par un filet
    /// fin plutôt que par un aplat.
    static let card = Color.clear
    static let ink = Color(hex: 0x151221)
    static let secondary = Color(hex: 0x726B87)
    static let line = Color(hex: 0xE9DFFF)
    /// Filet qui dessine le contour des cartes.
    static let cardLine = Color(hex: 0x8C7CB4).opacity(0.26)
    static let positive = Color(hex: 0x21B978)
    static let negative = Color(hex: 0xEF5B64)
    static let warning = Color(hex: 0xF0A23A)

    static let heroGradient = LinearGradient(
        colors: [primary, primaryDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.cardLine, lineWidth: 0.8)
            }
    }
}

private struct SensitiveAmountModifier: ViewModifier {
    let isSensitive: Bool
    @AppStorage(AppPreferenceKey.amountsHidden) private var amountsHidden = false

    func body(content: Content) -> some View {
        let isHidden = isSensitive && amountsHidden
        content
            .blur(radius: isHidden ? 7 : 0)
            .accessibilityHidden(isHidden)
            .animation(.easeInOut(duration: 0.18), value: isHidden)
    }
}

extension View {
    func appCard(padding: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func sensitiveAmount(_ isSensitive: Bool = true) -> some View {
        modifier(SensitiveAmountModifier(isSensitive: isSensitive))
    }
}
