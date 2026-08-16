import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: DashboardStore
    @AppStorage(AppPreferenceKey.portfolioSplitEnabled) private var isPortfolioSplitEnabled = false
    @AppStorage(AppPreferenceKey.amountsHidden) private var amountsHidden = false
    @State private var chartRange: ChartRange = .all
    @State private var selectedAllocation: PortfolioAllocation = .total
    @State private var showsPerformanceAsPercentage = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if let snapshot = store.snapshot {
                    pages(snapshot)
                } else {
                    unavailable
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func pages(_ snapshot: DashboardSnapshot) -> some View {
        if isPortfolioSplitEnabled {
            TabView(selection: $selectedAllocation) {
                ForEach(PortfolioAllocation.allCases) { allocation in
                    content(snapshot, allocation: allocation)
                        .tag(allocation)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            content(snapshot, allocation: .total)
        }
    }

    private func content(_ snapshot: DashboardSnapshot, allocation: PortfolioAllocation) -> some View {
        let result = allocationResult(for: snapshot)
        let allocationPoints = result.points(for: allocation)
        let points = filteredPoints(allocationPoints)

        return ScrollView {
            LazyVStack(spacing: 20) {
                AppHeader(
                    title: "Portfolio",
                    subtitle: "Compte \(snapshot.account.accountNumber)",
                    trailingSymbol: "arrow.clockwise",
                    trailingAction: { Task { await store.refresh() } },
                    isTrailingActive: store.state == .refreshing,
                    usesBrandStyle: true
                )

                if let message = store.errorMessage {
                    errorBanner(message)
                } else if store.isShowingCachedData {
                    cachedBanner(snapshot.fetchedAt)
                }

                portfolioSection(snapshot, allocation: allocation, result: result)

                PaceRow(
                    snapshot: snapshot,
                    points: allocationPoints,
                    balance: result.balance(for: allocation),
                    floatingProfitMultiplier: result.currentShare(for: allocation)
                )

                ResultBarsCard(
                    points: points,
                    calendarPoints: allocationPoints,
                    history: snapshot.history,
                    range: chartRange,
                    currency: snapshot.account.currency
                )

                positionsPreview(
                    snapshot,
                    profitMultiplier: result.currentShare(for: allocation)
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .refreshable { await store.refresh() }
    }

    private func portfolioSection(
        _ snapshot: DashboardSnapshot,
        allocation: PortfolioAllocation,
        result: PortfolioAllocationResult
    ) -> some View {
        VStack(spacing: 10) {
            portfolioCard(snapshot, allocation: allocation, result: result)

            if isPortfolioSplitEnabled {
                HStack(spacing: 6) {
                    ForEach(PortfolioAllocation.allCases) { page in
                        Circle()
                            .fill(page == selectedAllocation ? AppTheme.primary : AppTheme.secondary.opacity(0.25))
                            .frame(width: page == selectedAllocation ? 7 : 5, height: page == selectedAllocation ? 7 : 5)
                    }
                }
                .frame(height: 7)
                .animation(.easeInOut(duration: 0.2), value: selectedAllocation)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(selectedAllocation.rawValue + 1) sur \(PortfolioAllocation.allCases.count)")
            }
        }
    }

    private func portfolioCard(
        _ snapshot: DashboardSnapshot,
        allocation: PortfolioAllocation,
        result: PortfolioAllocationResult
    ) -> some View {
        let points = filteredPoints(result.points(for: allocation))
        let balance = result.balance(for: allocation)
        let periodProfit = chartRange == .all
            ? result.profitSinceStart(for: allocation)
            : points.reduce(0) { $0 + $1.profit }
        let performance = performancePercentage(
            profit: periodProfit,
            balance: balance,
            investedCapital: result.investedCapital(for: allocation)
        )

        return ZStack {
            SpiralWatermark()
                .stroke(
                    Color.white.opacity(0.045),
                    style: StrokeStyle(lineWidth: 38, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 290, height: 290)
                .offset(x: 54, y: 34)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Solde")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                amountsHidden.toggle()
                            }
                        } label: {
                            Text(AppFormat.currency(balance, code: snapshot.account.currency))
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .tracking(-1)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .sensitiveAmount()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(amountsHidden ? "Afficher les montants" : "Masquer les montants")
                        .accessibilityHint("Ce réglage s’applique à toute l’application")
                    }
                    Spacer()
                    Label(
                        snapshot.account.isDemo ? "Démo" : "Live",
                        systemImage: snapshot.account.isDemo ? "flask.fill" : "circle.fill"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.account.isDemo ? AppTheme.warning : AppTheme.lime)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.primaryDeep.opacity(0.62))
                    .clipShape(Capsule())
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsPerformanceAsPercentage.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(
                            showsPerformanceAsPercentage
                                ? AppFormat.percent(performance, showSign: true)
                                : AppFormat.currency(periodProfit, code: snapshot.account.currency, showSign: true)
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(periodProfit >= 0 ? AppTheme.lime : AppTheme.negative)
                        .contentTransition(.numericText())
                        .sensitiveAmount()
                        Text(label(for: chartRange))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    amountsHidden
                        ? "Performance \(label(for: chartRange)), montant masqué"
                        : "Performance \(label(for: chartRange)), \(showsPerformanceAsPercentage ? AppFormat.percent(performance, showSign: true) : AppFormat.currency(periodProfit, code: snapshot.account.currency, showSign: true))"
                )
                .accessibilityHint(showsPerformanceAsPercentage ? "Toucher pour afficher le montant" : "Toucher pour afficher le pourcentage")

                BalanceChart(
                    points: points,
                    lineColor: AppTheme.lime,
                    emptyTextColor: .white.opacity(0.65),
                    areaTopOpacity: 0.34
                )
                .frame(height: 200)

                HStack(spacing: 6) {
                    ForEach(ChartRange.allCases) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { chartRange = range }
                        } label: {
                            Text(range.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(chartRange == range ? AppTheme.primaryDeep : .white.opacity(0.72))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(chartRange == range ? AppTheme.lime : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
                .background(.white.opacity(0.075))
                .clipShape(Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.08), lineWidth: 1) }

                HStack {
                    Label {
                        Text("Source mise à jour \(AppFormat.relativeDate(snapshot.account.lastUpdate ?? snapshot.fetchedAt))")
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    Spacer()
                    if store.state == .refreshing {
                        ProgressView().tint(AppTheme.lime).controlSize(.small)
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            amountsHidden
                ? "Capital masqué"
                : "Capital investi \(AppFormat.currency(result.investedCapital(for: allocation), code: snapshot.account.currency))"
        )
    }

    private func allocationResult(for snapshot: DashboardSnapshot) -> PortfolioAllocationResult {
        PortfolioAllocationCalculator.result(
            contributions: store.portfolioContributions,
            daily: snapshot.daily,
            currentBalance: snapshot.account.balance,
            currentDate: snapshot.fetchedAt
        )
    }

    private func performancePercentage(profit: Double, balance: Double, investedCapital: Double) -> Double {
        let base = chartRange == .all ? investedCapital : balance - profit
        guard abs(base) > 0.01 else { return 0 }
        return profit / abs(base) * 100
    }

    private func positionsPreview(
        _ snapshot: DashboardSnapshot,
        profitMultiplier: Double
    ) -> some View {
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
                        PositionCompactRow(
                            position: position,
                            currency: snapshot.account.currency,
                            profitMultiplier: profitMultiplier
                        )
                        if index < min(snapshot.positions.count, 3) - 1 {
                            Divider().overlay(AppTheme.cardLine).padding(.leading, 48)
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
                .tint(AppTheme.primary)
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
    var lineColor = AppTheme.primary
    var emptyTextColor = AppTheme.secondary
    var areaTopOpacity = 0.24

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
                    .foregroundStyle(lineColor.opacity(0.8))
                Text("La courbe apparaîtra après la première synchronisation complète.")
                    .font(.caption)
                    .foregroundStyle(emptyTextColor)
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
                        colors: [lineColor.opacity(areaTopOpacity), lineColor.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Solde", point.balance)
                )
                .foregroundStyle(lineColor)
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

private struct SpiralWatermark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let turns = 2.35
        let steps = 150
        let maximumRadius = min(rect.width, rect.height) * 0.47

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = progress * turns * 2 * Double.pi
            let radius = maximumRadius * progress
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle) * radius),
                y: center.y + CGFloat(sin(angle) * radius)
            )

            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

struct PositionCompactRow: View {
    let position: OpenPosition
    let currency: String
    var profitMultiplier = 1.0

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
            ProfitText(value: (position.profit + position.swap) * profitMultiplier, currency: currency)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
    }
}

// MARK: - Rythme

/// Trois chiffres de tempo sous le graphe : ce que la courbe ne montre pas d'un coup d'œil.
private struct PaceRow: View {
    let snapshot: DashboardSnapshot
    let points: [DailyPoint]
    let balance: Double
    let floatingProfitMultiplier: Double

    private var todayProfit: Double {
        points
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.profit }
    }

    private var monthProfit: Double {
        let calendar = Calendar.current
        return points
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.profit }
    }

    private var floatingProfit: Double {
        snapshot.account.floatingProfit * floatingProfitMultiplier
    }

    /// Pourcentage recalculé depuis le montant affiché : les gains journaliers et
    /// mensuels renvoyés par Myfxbook ne portent pas toujours le même signe.
    private func share(of amount: Double) -> Double {
        let base = balance - amount
        guard abs(base) > 0.01 else { return 0 }
        return amount / abs(base) * 100
    }

    private var positionsLabel: String {
        let count = snapshot.positions.count
        switch count {
        case 0: return "Aucune position"
        case 1: return "1 position"
        default: return "\(count) positions"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            column(
                title: "Aujourd'hui",
                value: AppFormat.currency(todayProfit, code: snapshot.account.currency, showSign: true),
                detail: AppFormat.percent(share(of: todayProfit), showSign: true),
                amount: todayProfit
            )
            divider
            column(
                title: "Ce mois-ci",
                value: AppFormat.currency(monthProfit, code: snapshot.account.currency, showSign: true),
                detail: AppFormat.percent(share(of: monthProfit), showSign: true),
                amount: monthProfit
            )
            divider
            column(
                title: "Flottant",
                value: AppFormat.currency(floatingProfit, code: snapshot.account.currency, showSign: true),
                detail: positionsLabel,
                amount: floatingProfit
            )
        }
        .padding(.vertical, 2)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.line)
            .frame(width: 1, height: 38)
            .padding(.top, 4)
    }

    private func column(title: String, value: String, detail: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.secondary)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(tint(amount))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .sensitiveAmount()
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .sensitiveAmount(title != "Flottant")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    private func tint(_ amount: Double) -> Color {
        if amount > 0 { return AppTheme.positive }
        if amount < 0 { return AppTheme.negative }
        return AppTheme.ink
    }
}

// MARK: - Résultats en bâtonnets

/// Résultat réalisé par période, en bâtonnets signés. Le pas s'adapte à la plage
/// choisie (jour, semaine, mois) et une barre peut être sélectionnée au doigt.
private struct ResultBarsCard: View {
    let points: [DailyPoint]
    let calendarPoints: [DailyPoint]
    let history: [TradeTransaction]
    let range: ChartRange
    let currency: String
    /// `true` : carte violette profonde (inverse du reste de l'écran).
    var isDark = true

    @State private var selectedDate: Date?
    @State private var isShowingCalendar = ProcessInfo.processInfo.arguments.contains("--calendar")

    private var primaryText: Color { isDark ? .white : AppTheme.ink }
    private var secondaryText: Color { isDark ? .white.opacity(0.6) : AppTheme.secondary }
    private var ruleColor: Color { isDark ? .white.opacity(0.16) : AppTheme.line }
    private var upColor: Color { isDark ? AppTheme.lime : AppTheme.positive }

    private var step: Calendar.Component {
        switch range {
        case .week, .month: .day
        case .quarter: .weekOfYear
        case .year, .all: .month
        }
    }

    private var stepLabel: String {
        switch step {
        case .day: "par jour"
        case .weekOfYear: "par semaine"
        default: "par mois"
        }
    }

    private var buckets: [ResultBucket] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) { point -> Date in
            switch step {
            case .day:
                return calendar.startOfDay(for: point.date)
            case .weekOfYear:
                return calendar.dateInterval(of: .weekOfYear, for: point.date)?.start
                    ?? calendar.startOfDay(for: point.date)
            default:
                return calendar.dateInterval(of: .month, for: point.date)?.start
                    ?? calendar.startOfDay(for: point.date)
            }
        }
        return grouped
            .map { ResultBucket(date: $0.key, value: $0.value.reduce(0) { $0 + $1.profit }) }
            .sorted { $0.date < $1.date }
    }

    private var selectedBucket: ResultBucket? {
        guard let selectedDate else { return nil }
        return buckets.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedDate)) < abs(rhs.date.timeIntervalSince(selectedDate))
        }
    }

    private var total: Double { buckets.reduce(0) { $0 + $1.value } }
    private var best: ResultBucket? { buckets.max { $0.value < $1.value } }
    private var worst: ResultBucket? { buckets.min { $0.value < $1.value } }
    private var winningCount: Int { buckets.filter { $0.value > 0 }.count }
    private var tradedCount: Int { buckets.filter { $0.value != 0 }.count }

    /// Bâtonnets fins et réguliers, quel que soit le nombre de périodes.
    private var barWidth: MarkDimension {
        buckets.count <= 10 ? .fixed(18) : .ratio(0.62)
    }

    private var bounds: ClosedRange<Double> {
        let values = buckets.map(\.value)
        let maximum = max(values.max() ?? 0, 0)
        let minimum = min(values.min() ?? 0, 0)
        let spread = max(maximum - minimum, 1)
        return (minimum - spread * 0.12)...(maximum + spread * 0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if tradedCount == 0 {
                Text("Aucun résultat réalisé sur cette période.")
                    .font(.footnote)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 26)
            } else {
                chart
                footer
            }
        }
        .padding(18)
        .background {
            if isDark {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryDeep, Color(hex: 0x180A38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                    .shadow(color: AppTheme.primaryDeep.opacity(0.22), radius: 18, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.7), lineWidth: 0.5)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: range)
        .fullScreenCover(isPresented: $isShowingCalendar) {
            PerformanceCalendarView(
                points: calendarPoints,
                history: history,
                currency: currency
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedBucket == nil ? "Résultat \(stepLabel)" : label(for: selectedBucket!.date))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text(selectedBucket == nil ? "\(winningCount) sur \(tradedCount) en positif" : "résultat réalisé")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Text(AppFormat.currency(selectedBucket?.value ?? total, code: currency, showSign: true))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(tint(selectedBucket?.value ?? total))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .sensitiveAmount()
            Button {
                isShowingCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDark ? AppTheme.lime : AppTheme.primary)
                    .frame(width: 34, height: 34)
                    .background(isDark ? Color.white.opacity(0.09) : AppTheme.primarySoft)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(isDark ? Color.white.opacity(0.1) : AppTheme.cardLine, lineWidth: 0.7)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ouvrir le calendrier des performances")
        }
    }

    private var chart: some View {
        Chart {
            RuleMark(y: .value("Zéro", 0))
                .foregroundStyle(ruleColor)
                .lineStyle(StrokeStyle(lineWidth: 1))

            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Période", bucket.date, unit: step),
                    y: .value("Résultat", bucket.value),
                    width: barWidth
                )
                .foregroundStyle(fill(for: bucket.value))
                .opacity(selectedBucket == nil || selectedBucket?.id == bucket.id ? 1 : 0.28)
                .cornerRadius(4)
            }
        }
        .chartYScale(domain: bounds)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: axisFormat, centered: true)
                    .font(.system(size: 10))
                    .foregroundStyle(secondaryText)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 118)
        .accessibilityLabel("Résultat \(stepLabel)")
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if let best, best.value > 0 {
                Text("Meilleur \(AppFormat.currency(best.value, code: currency, showSign: true))")
                    .foregroundStyle(upColor)
                    .sensitiveAmount()
            }
            if let worst, worst.value < 0 {
                Text("·").foregroundStyle(ruleColor)
                Text("Pire \(AppFormat.currency(worst.value, code: currency, showSign: true))")
                    .foregroundStyle(AppTheme.negative)
                    .sensitiveAmount()
            }
            Spacer()
        }
        .font(.system(size: 11.5, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var axisFormat: Date.FormatStyle {
        switch step {
        case .day: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))
        case .weekOfYear: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))
        default: .dateTime.month(.abbreviated).locale(Locale(identifier: "fr_FR"))
        }
    }

    private func label(for date: Date) -> String {
        switch step {
        case .day: AppFormat.shortDate(date)
        case .weekOfYear: "Semaine du \(AppFormat.shortDate(date))"
        default: date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR")))
        }
    }

    private func tint(_ amount: Double) -> Color {
        if amount > 0 { return upColor }
        if amount < 0 { return AppTheme.negative }
        return secondaryText
    }

    /// Barres positives en dégradé, pour rappeler la courbe du hero.
    private func fill(for amount: Double) -> LinearGradient {
        let colors: [Color]
        if amount < 0 {
            colors = [AppTheme.negative, AppTheme.negative.opacity(0.7)]
        } else if isDark {
            colors = [AppTheme.lime, AppTheme.lime.opacity(0.72)]
        } else {
            colors = [AppTheme.lime.opacity(0.9), AppTheme.positive]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

private struct ResultBucket: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
