import SwiftUI
import UIKit

struct BrandMark: View {
    var size: CGFloat = 42

    @ViewBuilder
    var body: some View {
        if let iconURL = Bundle.main.url(forResource: "FiboBrandIcon@3x", withExtension: "png"),
           let icon = UIImage(contentsOfFile: iconURL.path) {
            Image(uiImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                .accessibilityLabel("Fibo")
        } else {
            Image(systemName: "arrow.up.right")
                .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.lime)
                .frame(width: size, height: size)
                .background(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                .accessibilityLabel("Fibo")
        }
    }
}

struct AppHeader: View {
    let title: String
    var subtitle: String?
    var trailingSymbol: String?
    var trailingAction: (() -> Void)?
    var isTrailingActive = false
    var usesBrandStyle = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            Spacer()
            if let trailingSymbol {
                Button(action: { trailingAction?() }) {
                    Image(systemName: trailingSymbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(usesBrandStyle ? AppTheme.lime : AppTheme.primaryDeep)
                        .rotationEffect(.degrees(isTrailingActive ? 360 : 0))
                        .animation(
                            isTrailingActive
                                ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                                : .default,
                            value: isTrailingActive
                        )
                        .frame(width: 46, height: 46)
                        .background(usesBrandStyle ? AppTheme.primary : AppTheme.primarySoft)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(
                                usesBrandStyle ? AppTheme.lime.opacity(0.32) : AppTheme.line,
                                lineWidth: usesBrandStyle ? 2 : 1
                            )
                        }
                        .shadow(
                            color: usesBrandStyle ? AppTheme.primary.opacity(0.2) : .clear,
                            radius: 12,
                            y: 6
                        )
                }
                .buttonStyle(.plain)
                .disabled(isTrailingActive)
                .accessibilityLabel(isTrailingActive ? "Actualisation en cours" : "Actualiser")
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = AppTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .sensitiveAmount()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 16)
    }
}

struct SectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondary)
            }
        }
    }
}

struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 52, height: 52)
                .background(AppTheme.primarySoft)
                .clipShape(Circle())
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .appCard()
    }
}

struct ProfitText: View {
    let value: Double
    let currency: String
    var font: Font = .headline

    var body: some View {
        Text(AppFormat.currency(value, code: currency, showSign: true))
            .font(font)
            .foregroundStyle(value >= 0 ? AppTheme.positive : AppTheme.negative)
            .sensitiveAmount()
    }
}

struct DirectionBadge: View {
    let isBuy: Bool
    let label: String

    var body: some View {
        Text(label.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(isBuy ? AppTheme.positive : AppTheme.negative)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((isBuy ? AppTheme.positive : AppTheme.negative).opacity(0.1))
            .clipShape(Capsule())
    }
}

struct LoadingOverlay: View {
    let title: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            BrandMark(size: 64)
                .scaleEffect(isAnimating ? 1.04 : 0.92)
                .rotationEffect(.degrees(isAnimating ? 3 : -3))
                .shadow(color: AppTheme.primary.opacity(0.2), radius: 18)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
