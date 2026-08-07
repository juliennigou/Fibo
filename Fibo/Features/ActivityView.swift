import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var searchText = ""
    @State private var selectedSegment = 0
    private let sectionSelection: Binding<Int>?

    init(sectionSelection: Binding<Int>? = nil) {
        self.sectionSelection = sectionSelection
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 20) {
                        AppHeader(title: "Historique", subtitle: "Rapports et transactions")

                        if let sectionSelection {
                            ActivityPagePicker(selection: sectionSelection)
                        }

                        if let snapshot = store.snapshot {
                            Picker("Vue", selection: $selectedSegment) {
                                Text("Jours").tag(0)
                                Text("Transactions").tag(1)
                            }
                            .pickerStyle(.segmented)

                            if selectedSegment == 0 {
                                dailySummary(snapshot)
                            } else {
                                transactions(snapshot)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .refreshable { await store.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func dailySummary(_ snapshot: DashboardSnapshot) -> some View {
        let profitableDays = snapshot.daily.filter { $0.profit > 0 }.count
        let activeDays = snapshot.daily.filter { $0.profit != 0 }.count
        let winRate = activeDays == 0 ? 0 : Double(profitableDays) / Double(activeDays) * 100

        return VStack(spacing: 20) {
            HStack(spacing: 12) {
                MetricCard(
                    title: "Jours gagnants",
                    value: activeDays == 0 ? "—" : AppFormat.percent(winRate),
                    symbol: "checkmark.circle",
                    tint: AppTheme.positive
                )
                MetricCard(
                    title: "Profit factor",
                    value: snapshot.account.profitFactor == 0 ? "—" : AppFormat.decimal(snapshot.account.profitFactor),
                    symbol: "scalemass",
                    tint: AppTheme.primary
                )
            }

            VStack(spacing: 13) {
                SectionTitle(title: "Rapports journaliers", detail: "\(snapshot.daily.count) jours")
                if snapshot.daily.isEmpty {
                    EmptyStateCard(
                        symbol: "calendar.badge.clock",
                        title: "Pas encore de rapport",
                        message: "Les performances quotidiennes apparaîtront après la synchronisation Myfxbook."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(snapshot.daily.sorted { $0.date > $1.date }) { day in
                            DailyReportCard(day: day, currency: snapshot.account.currency)
                        }
                    }
                }
            }
        }
    }

    private func transactions(_ snapshot: DashboardSnapshot) -> some View {
        let filtered = snapshot.history.filter {
            searchText.isEmpty || $0.symbol.localizedCaseInsensitiveContains(searchText)
                || $0.action.localizedCaseInsensitiveContains(searchText)
        }

        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondary)
                TextField("Rechercher un symbole", text: $searchText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            SectionTitle(title: "Dernières opérations", detail: "50 maximum via Myfxbook")

            if filtered.isEmpty {
                EmptyStateCard(
                    symbol: "tray",
                    title: searchText.isEmpty ? "Aucune transaction" : "Aucun résultat",
                    message: searchText.isEmpty ? "Les transactions clôturées apparaîtront ici." : "Essaie un autre symbole."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filtered.sorted { ($0.closeDate ?? .distantPast) > ($1.closeDate ?? .distantPast) }) { transaction in
                        TransactionCard(transaction: transaction, currency: snapshot.account.currency)
                    }
                }
            }
        }
    }
}

struct TradingActivityView: View {
    @State private var selectedPage = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            PositionsView(sectionSelection: $selectedPage)
                .tag(0)

            ActivityView(sectionSelection: $selectedPage)
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(AppTheme.background.ignoresSafeArea())
    }
}

struct ActivityPagePicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("Activité", selection: $selection) {
            Text("Positions").tag(0)
            Text("Historique").tag(1)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Type d’activité")
    }
}

private struct DailyReportCard: View {
    let day: DailyPoint
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(day.date.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(day.date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "fr_FR"))).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.secondary)
            }
            .frame(width: 42, height: 48)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(day.profit == 0 ? "Journée sans résultat" : (day.profit > 0 ? "Journée positive" : "Journée négative"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(AppFormat.decimal(day.lots)) lots · \(AppFormat.decimal(day.pips, digits: 1)) pips")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ProfitText(value: day.profit, currency: currency)
                Text(AppFormat.currency(day.balance, code: currency))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .appCard(padding: 14)
    }
}

private struct TransactionCard: View {
    let transaction: TradeTransaction
    let currency: String

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: transaction.isBuy ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(transaction.isBuy ? AppTheme.positive : AppTheme.negative)
                        .frame(width: 36, height: 36)
                        .background((transaction.isBuy ? AppTheme.positive : AppTheme.negative).opacity(0.1))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(transaction.symbol)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("\(transaction.action) · \(AppFormat.decimal(transaction.size)) \(transaction.sizeType)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
                Spacer()
                ProfitText(value: transaction.netProfit, currency: currency)
            }

            HStack {
                Label(transaction.closeDate.map(AppFormat.dateTime) ?? "Date inconnue", systemImage: "calendar")
                Spacer()
                Text("\(AppFormat.decimal(transaction.pips, digits: 1)) pips")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondary)
        }
        .appCard(padding: 15)
    }
}
