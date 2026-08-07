import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var chartRange: ChartRange = .all

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if let snapshot = store.snapshot {
                    content(snapshot)
                } else {
                    unavailable
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func content(_ snapshot: DashboardSnapshot) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                AppHeader(
                    title: "Portfolio",
                    subtitle: "Compte \(snapshot.account.accountNumber)",
                    trailingSymbol: store.state == .refreshing ? nil : "arrow.clockwise",
                    trailingAction: { Task { await store.refresh() } }
                )

                if let message = store.errorMessage {
                    errorBanner(message)
                } else if store.isShowingCachedData {
                    cachedBanner(snapshot.fetchedAt)
                }

                portfolioCard(snapshot)

                HStack(spacing: 12) {
                    MetricCard(
                        title: "Equity",
                        value: AppFormat.currency(snapshot.account.equity, code: snapshot.account.currency),
                        symbol: "waveform.path.ecg"
                    )
                    MetricCard(
                        title: "Gain total",
                        value: AppFormat.percent(snapshot.account.gain, showSign: true),
                        symbol: "chart.line.uptrend.xyaxis",
                        tint: snapshot.account.gain >= 0 ? AppTheme.positive : AppTheme.negative
                    )
                }

                HStack(spacing: 12) {
                    MetricCard(
                        title: "Profit cumulé",
                        value: AppFormat.currency(snapshot.account.profit, code: snapshot.account.currency, showSign: true),
                        symbol: "eurosign.circle",
                        tint: snapshot.account.profit >= 0 ? AppTheme.positive : AppTheme.negative
                    )
                    MetricCard(
                        title: "Drawdown",
                        value: AppFormat.percent(snapshot.account.drawdown),
                        symbol: "arrow.down.right",
                        tint: AppTheme.warning
                    )
                }

                positionsPreview(snapshot)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .refreshable { await store.refresh() }
    }

    private func portfolioCard(_ snapshot: DashboardSnapshot) -> some View {
        let points = filteredPoints(snapshot.daily)
        let periodProfit = points.reduce(0) { $0 + $1.profit }

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Solde")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.secondary)
                    Text(AppFormat.currency(snapshot.account.balance, code: snapshot.account.currency))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .tracking(-1)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Spacer()
                StatusPill(
                    text: snapshot.account.isDemo ? "Démo" : "Live",
                    color: snapshot.account.isDemo ? AppTheme.warning : AppTheme.positive,
                    symbol: snapshot.account.isDemo ? "flask.fill" : "checkmark.circle.fill"
                )
            }

            HStack(spacing: 8) {
                ProfitText(value: periodProfit, currency: snapshot.account.currency, font: .subheadline.weight(.bold))
                Text(label(for: chartRange))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }

            BalanceChart(points: points)
                .frame(height: 180)

            HStack(spacing: 6) {
                ForEach(ChartRange.allCases) { range in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { chartRange = range }
                    } label: {
                        Text(range.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(chartRange == range ? .white : AppTheme.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(chartRange == range ? AppTheme.blue : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(AppTheme.background)
            .clipShape(Capsule())

            HStack {
                Label {
                    Text("Source mise à jour \(AppFormat.relativeDate(snapshot.account.lastUpdate ?? snapshot.fetchedAt))")
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
                Spacer()
                if store.state == .refreshing {
                    ProgressView().tint(AppTheme.blue).controlSize(.small)
                }
            }
        }
        .appCard(padding: 20)
    }

    private func positionsPreview(_ snapshot: DashboardSnapshot) -> some View {
        VStack(spacing: 13) {
            SectionTitle(
                title: "Positions ouvertes",
                detail: snapshot.positions.isEmpty ? "Aucune" : "\(snapshot.positions.count) position\(snapshot.positions.count > 1 ? "s" : "")"
            )

            if snapshot.positions.isEmpty {
                EmptyStateCard(
                    symbol: "checkmark.circle",
                    title: "Aucune position ouverte",
                    message: "Le portefeuille n’a actuellement aucune exposition au marché."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.positions.prefix(3).enumerated()), id: \.element.id) { index, position in
                        PositionCompactRow(position: position, currency: snapshot.account.currency)
                        if index < min(snapshot.positions.count, 3) - 1 {
                            Divider().overlay(AppTheme.line).padding(.leading, 48)
                        }
                    }
                }
                .appCard(padding: 8)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(AppTheme.warning)
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Button { store.dismissError() } label: {
                Image(systemName: "xmark").foregroundStyle(AppTheme.secondary)
            }
        }
        .padding(14)
        .background(AppTheme.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cachedBanner(_ date: Date) -> some View {
        Label("Mode hors ligne · données du \(AppFormat.dateTime(date))", systemImage: "icloud.slash")
            .font(.footnote.weight(.medium))
            .foregroundStyle(AppTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            EmptyStateCard(
                symbol: "exclamationmark.arrow.triangle.2.circlepath",
                title: "Données indisponibles",
                message: store.errorMessage ?? "Impossible de charger le portefeuille pour le moment."
            )
            Button("Réessayer") { Task { await store.refresh(showLoadingState: true) } }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)
        }
        .padding(22)
    }

    private func filteredPoints(_ points: [DailyPoint]) -> [DailyPoint] {
        guard let days = chartRange.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return points }
        let filtered = points.filter { $0.date >= cutoff }
        return filtered.isEmpty ? Array(points.suffix(min(days, points.count))) : filtered
    }

    private func label(for range: ChartRange) -> String {
        switch range {
        case .week: "sur 7 jours"
        case .month: "sur 1 mois"
        case .quarter: "sur 3 mois"
        case .year: "sur 1 an"
        case .all: "depuis le début"
        }
    }
}

private struct BalanceChart: View {
    let points: [DailyPoint]

    private var bounds: ClosedRange<Double> {
        let values = points.map(\.balance)
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
        let spread = max(maximum - minimum, max(abs(maximum) * 0.01, 1))
        return (minimum - spread * 0.18)...(maximum + spread * 0.18)
    }

    var body: some View {
        if points.isEmpty {
            VStack(spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(AppTheme.blue.opacity(0.65))
                Text("La courbe apparaîtra après la première synchronisation complète.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Base", bounds.lowerBound),
                    yEnd: .value("Solde", point.balance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.blue.opacity(0.24), AppTheme.blue.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Solde", point.balance)
                )
                .foregroundStyle(AppTheme.blue)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: bounds)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plot in plot.clipped() }
            .accessibilityLabel("Évolution du solde")
        }
    }
}

struct PositionCompactRow: View {
    let position: OpenPosition
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: position.isBuy ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(position.isBuy ? AppTheme.positive : AppTheme.negative)
                .frame(width: 38, height: 38)
                .background((position.isBuy ? AppTheme.positive : AppTheme.negative).opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(position.symbol)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(position.action) · \(AppFormat.decimal(position.size)) \(position.sizeType)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            ProfitText(value: position.profit + position.swap, currency: currency)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
    }
}
