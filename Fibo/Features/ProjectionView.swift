import Charts
import SwiftUI

struct ProjectionPoint: Identifiable, Equatable {
    var id: Int { month }
    let month: Int
    let grossCapital: Double
    let taxableGain: Double
    let estimatedTax: Double
    let netCapital: Double
}

enum ProjectionCalculator {
    static func result(
        capital: Double,
        monthlyRatePercent: Double,
        taxRatePercent: Double,
        months: Int
    ) -> ProjectionPoint {
        let safeCapital = max(0, capital)
        let safeMonthlyRate = max(-99.9, monthlyRatePercent) / 100
        let safeTaxRate = min(max(taxRatePercent, 0), 100) / 100
        let grossCapital = safeCapital * pow(1 + safeMonthlyRate, Double(max(0, months)))
        let taxableGain = max(0, grossCapital - safeCapital)
        let estimatedTax = taxableGain * safeTaxRate

        return ProjectionPoint(
            month: max(0, months),
            grossCapital: grossCapital,
            taxableGain: taxableGain,
            estimatedTax: estimatedTax,
            netCapital: grossCapital - estimatedTax
        )
    }

    static func points(
        capital: Double,
        monthlyRatePercent: Double,
        taxRatePercent: Double,
        through maximumMonth: Int = 240
    ) -> [ProjectionPoint] {
        (0...maximumMonth).map {
            result(
                capital: capital,
                monthlyRatePercent: monthlyRatePercent,
                taxRatePercent: taxRatePercent,
                months: $0
            )
        }
    }

    /// Moyenne géométrique des rendements mensuels calculés à partir des profits
    /// journaliers, afin de limiter l’effet des dépôts et retraits sur la performance.
    static func historicalMonthlyRate(from daily: [DailyPoint], maximumMonths: Int = 12) -> Double? {
        struct MonthKey: Hashable { let year: Int; let month: Int }

        let calendar = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: daily.sorted { $0.date < $1.date }) { point in
            let components = calendar.dateComponents([.year, .month], from: point.date)
            return MonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }

        let factors = grouped.values.compactMap { points -> (date: Date, factor: Double)? in
            guard let first = points.first,
                  let monthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: first.date)) else {
                return nil
            }

            let profit = points.reduce(0) { $0 + $1.profit }
            let openingBalance = max(first.balance - first.profit, 0)
            guard openingBalance > 0 else { return nil }
            let factor = 1 + profit / openingBalance
            guard factor > 0, factor.isFinite else { return nil }
            return (monthDate, factor)
        }
        .sorted { $0.date < $1.date }
        .suffix(maximumMonths)

        guard !factors.isEmpty else { return nil }
        let product = factors.reduce(1) { $0 * $1.factor }
        return (pow(product, 1 / Double(factors.count)) - 1) * 100
    }
}

struct ProjectionView: View {
    @EnvironmentObject private var store: DashboardStore

    @State private var capital = 10_000.0
    @State private var monthlyRate = 1.0
    @State private var taxRate = 30.0
    @State private var capitalDraft = ""
    @State private var monthlyRateDraft = ""
    @State private var taxRateDraft = ""
    @State private var selectedMonth: Int? = 120
    @State private var hasLoadedDefaults = false
    @State private var isShowingInformation = false
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case capital
        case monthlyRate
        case taxRate
    }

    private var points: [ProjectionPoint] {
        ProjectionCalculator.points(
            capital: capital,
            monthlyRatePercent: monthlyRate,
            taxRatePercent: taxRate
        )
    }

    private var selectedResult: ProjectionPoint {
        ProjectionCalculator.result(
            capital: capital,
            monthlyRatePercent: monthlyRate,
            taxRatePercent: taxRate,
            months: min(max(selectedMonth ?? 120, 0), 240)
        )
    }

    private var annualizedRate: Double {
        let factor = max(0.001, 1 + monthlyRate / 100)
        return (pow(factor, 12) - 1) * 100
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        header
                        inputsCard
                        projectionCard
                        resultsCard
                        disclaimer
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Terminé") {
                        if let focusedField { commit(focusedField) }
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $isShowingInformation) {
            ProjectionInformationSheet()
        }
        .onAppear { loadDefaultsIfNeeded() }
        .onChange(of: focusedField) { previous, _ in
            if let previous { commit(previous) }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Projection")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text("Simule ton capital dans le temps")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            Button { isShowingInformation = true } label: {
                Image(systemName: "info")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppTheme.lime)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.primary)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AppTheme.lime.opacity(0.32), lineWidth: 2) }
                    .shadow(color: AppTheme.primary.opacity(0.2), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Informations sur la projection")
        }
    }

    private var inputsCard: some View {
        VStack(spacing: 6) {
            VStack(spacing: 0) {
                capitalRow

                Divider().overlay(AppTheme.cardLine)

                HStack(spacing: 0) {
                    compactRow(
                        title: "Rendement / mois",
                        draft: $monthlyRateDraft,
                        suffix: "%",
                        field: .monthlyRate
                    )
                    Rectangle()
                        .fill(AppTheme.cardLine)
                        .frame(width: 1, height: 36)
                    compactRow(
                        title: "Fiscalité",
                        draft: $taxRateDraft,
                        suffix: "%",
                        field: .taxRate
                    )
                }
            }
            .appCard(padding: 0)

            Text("Pré-rempli avec ton compte et ta moyenne réelle des 12 derniers mois.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    /// Le capital garde une ligne pleine largeur : c'est la valeur la plus longue.
    private var capitalRow: some View {
        HStack(spacing: 12) {
            Text("Capital initial")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 8)
            TextField("0", text: $capitalDraft)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(focusedField == .capital ? AppTheme.primary : AppTheme.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .capital)
                .submitLabel(.done)
                .onSubmit { commit(.capital) }
                .accessibilityLabel("Capital initial")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 190, alignment: .trailing)
                .sensitiveAmount()
            Text("€")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.secondary)
                .sensitiveAmount()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .capital }
    }

    private func compactRow(
        title: String,
        draft: Binding<String>,
        suffix: String,
        field: InputField
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(AppTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", text: draft)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(focusedField == field ? AppTheme.primary : AppTheme.ink)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .submitLabel(.done)
                    .onSubmit { commit(field) }
                    .accessibilityLabel(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 72, alignment: .leading)
                Text(suffix)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
    }

    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppFormat.currency(selectedResult.netCapital, code: currencyCode))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(-0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .sensitiveAmount()
                Text("Capital net estimé dans \(selectedHorizonLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
            }

            HStack(spacing: 16) {
                chartLegend(color: AppTheme.lime, title: "Net estimé")
                chartLegend(color: AppTheme.primarySoft.opacity(0.8), title: "Brut")
            }

            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Mois", point.month),
                        y: .value("Brut", point.grossCapital),
                        series: .value("Série", "Brut")
                    )
                    .foregroundStyle(AppTheme.primarySoft.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Mois", point.month),
                        y: .value("Net", point.netCapital),
                        series: .value("Série", "Net")
                    )
                    .foregroundStyle(AppTheme.lime)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(x: .value("Sélection", selectedResult.month))
                    .foregroundStyle(.white.opacity(0.36))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Mois sélectionné", selectedResult.month),
                    y: .value("Net sélectionné", selectedResult.netCapital)
                )
                .foregroundStyle(AppTheme.lime)
                .symbolSize(95)
            }
            .chartXScale(domain: 0...240)
            .chartXAxis {
                AxisMarks(values: [0, 24, 60, 120, 240]) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.06))
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text(month == 0 ? "0" : "\(month / 12) ans")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.52))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(compactAmount(amount))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .frame(height: 230)
            .sensitiveAmount()
            .accessibilityLabel("Courbe de projection sur vingt ans")
            .accessibilityValue("Horizon sélectionné : \(selectedHorizonLabel)")

            HStack(spacing: 7) {
                Image(systemName: "hand.draw.fill")
                Text("Glisse sur la courbe pour changer l’horizon")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(20)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: AppTheme.primary.opacity(0.22), radius: 24, y: 12)
    }

    private var resultsCard: some View {
        VStack(spacing: 14) {
            resultRow(title: "Capital brut", value: selectedResult.grossCapital, color: AppTheme.primary)
            Divider().overlay(AppTheme.cardLine)
            resultRow(title: "Gain imposable", value: selectedResult.taxableGain, color: AppTheme.positive)
            Divider().overlay(AppTheme.cardLine)
            resultRow(title: "Fiscalité estimée", value: -selectedResult.estimatedTax, color: AppTheme.warning)
        }
        .appCard(padding: 18)
    }

    private func resultRow(title: String, value: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
            Spacer()
            Text(AppFormat.currency(value, code: currencyCode, showSign: value < 0))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .sensitiveAmount()
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppTheme.primary)
            Text("Projection à rendement constant, non garantie. Taux annualisé équivalent : \(AppFormat.percent(annualizedRate)). La fiscalité dépend de ta situation et de l’instrument.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(AppTheme.primarySoft.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func chartLegend(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 20, height: 3)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
    }

    private var selectedHorizonLabel: String {
        let month = selectedResult.month
        let years = month / 12
        let remainingMonths = month % 12
        if years == 0 { return "\(remainingMonths) mois" }
        if remainingMonths == 0 { return "\(years) an\(years > 1 ? "s" : "")" }
        return "\(years) an\(years > 1 ? "s" : "") et \(remainingMonths) mois"
    }

    private var currencyCode: String {
        store.snapshot?.account.currency ?? "EUR"
    }

    private func compactAmount(_ value: Double) -> String {
        let absolute = abs(value)
        let sign = value < 0 ? "−" : ""
        if absolute >= 1_000_000 {
            return "\(sign)\(AppFormat.decimal(absolute / 1_000_000, digits: 1)) M€"
        }
        if absolute >= 1_000 {
            return "\(sign)\(AppFormat.decimal(absolute / 1_000, digits: 0)) k€"
        }
        return "\(sign)\(AppFormat.decimal(absolute, digits: 0)) €"
    }

    private func loadDefaultsIfNeeded() {
        guard !hasLoadedDefaults else { return }
        hasLoadedDefaults = true

        if let snapshot = store.snapshot {
            capital = max(snapshot.account.equity, 0)
            monthlyRate = ProjectionCalculator.historicalMonthlyRate(from: snapshot.daily)
                ?? snapshot.account.monthlyGain
        }
        refreshDrafts()
    }

    private func commit(_ field: InputField) {
        switch field {
        case .capital:
            if let parsed = parse(capitalDraft), parsed >= 0 {
                capital = min(parsed, 1_000_000_000_000)
            }
        case .monthlyRate:
            if let parsed = parse(monthlyRateDraft), parsed > -100 {
                monthlyRate = min(parsed, 100)
            }
        case .taxRate:
            if let parsed = parse(taxRateDraft) {
                taxRate = min(max(parsed, 0), 100)
            }
        }
        refreshDrafts()
    }

    private func refreshDrafts() {
        capitalDraft = AppFormat.decimal(capital, digits: 2)
        monthlyRateDraft = AppFormat.decimal(monthlyRate, digits: 2)
        taxRateDraft = AppFormat.decimal(taxRate, digits: 0)
    }

    private func parse(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "%", with: "")
        return Double(normalized)
    }
}

private struct ProjectionInformationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    informationBlock(
                        symbol: "chart.line.uptrend.xyaxis",
                        title: "Une projection, pas une prédiction",
                        text: "La courbe prolonge un rendement mensuel constant. Les performances futures peuvent être très différentes."
                    )
                    informationBlock(
                        symbol: "percent",
                        title: "Fiscalité estimée",
                        text: "Le taux est appliqué uniquement au gain positif projeté. Il reste modifiable car le traitement réel dépend de ta situation et de l’instrument utilisé."
                    )
                    informationBlock(
                        symbol: "function",
                        title: "Calcul composé",
                        text: "Chaque mois, le rendement est appliqué au capital déjà augmenté des gains précédents."
                    )
                }
                .padding(22)
            }
            .background(AppTheme.background)
            .navigationTitle("À propos du calcul")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(AppTheme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func informationBlock(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.lime)
                .frame(width: 42, height: 42)
                .background(AppTheme.primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ProjectionView()
        .environmentObject(DashboardStore())
}
