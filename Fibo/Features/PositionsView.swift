import SwiftUI

struct PositionsView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var selectedPosition: OpenPosition?
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
                        AppHeader(
                            title: "Positions",
                            subtitle: exposureSubtitle,
                            trailingSymbol: "arrow.clockwise",
                            trailingAction: { Task { await store.refresh() } }
                        )

                        if let sectionSelection {
                            ActivityPagePicker(selection: sectionSelection)
                        }

                        if let snapshot = store.snapshot {
                            exposureCard(snapshot)
                            openPositions(snapshot)
                            pendingOrders(snapshot)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .refreshable { await store.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedPosition) { position in
                PositionDetailView(position: position, currency: store.account?.currency ?? "EUR")
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var exposureSubtitle: String {
        let count = store.snapshot?.positions.count ?? 0
        return count == 0 ? "Aucune exposition" : "\(count) position\(count > 1 ? "s" : "") ouverte\(count > 1 ? "s" : "")"
    }

    private func exposureCard(_ snapshot: DashboardSnapshot) -> some View {
        let floating = snapshot.positions.reduce(0) { $0 + $1.profit + $1.swap }
        let totalLots = snapshot.positions.reduce(0) { $0 + $1.size }

        return HStack(spacing: 0) {
            exposureMetric(
                label: "P/L flottant",
                value: AppFormat.currency(floating, code: snapshot.account.currency, showSign: true),
                tint: floating >= 0 ? AppTheme.positive : AppTheme.negative
            )
            Divider().frame(height: 48).overlay(AppTheme.cardLine).padding(.horizontal, 16)
            exposureMetric(
                label: "Volume total",
                value: "\(AppFormat.decimal(totalLots)) lots",
                tint: AppTheme.primary
            )
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private func exposureMetric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openPositions(_ snapshot: DashboardSnapshot) -> some View {
        VStack(spacing: 13) {
            SectionTitle(title: "En cours", detail: "Données Myfxbook")
            if snapshot.positions.isEmpty {
                EmptyStateCard(
                    symbol: "scope",
                    title: "Marché calme",
                    message: "Les nouvelles positions de l’algorithme apparaîtront automatiquement ici."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(snapshot.positions) { position in
                        Button { selectedPosition = position } label: {
                            PositionCard(position: position, currency: snapshot.account.currency)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func pendingOrders(_ snapshot: DashboardSnapshot) -> some View {
        VStack(spacing: 13) {
            SectionTitle(title: "Ordres en attente", detail: snapshot.orders.isEmpty ? "Aucun" : "\(snapshot.orders.count)")
            if snapshot.orders.isEmpty {
                EmptyStateCard(
                    symbol: "hourglass",
                    title: "Aucun ordre en attente",
                    message: "Les ordres limit et stop apparaîtront dans cette section."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(snapshot.orders) { order in
                        PendingOrderCard(order: order)
                    }
                }
            }
        }
    }
}

private struct PositionCard: View {
    let position: OpenPosition
    let currency: String

    var body: some View {
        VStack(spacing: 17) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 9) {
                        Text(position.symbol)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        DirectionBadge(isBuy: position.isBuy, label: position.action)
                    }
                    Text(position.openDate.map(AppFormat.dateTime) ?? "Date inconnue")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    ProfitText(
                        value: position.profit + position.swap,
                        currency: currency,
                        font: .system(.title3, design: .rounded, weight: .bold)
                    )
                    Text("\(AppFormat.decimal(position.pips, digits: 1)) pips")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
            }

            Divider().overlay(AppTheme.cardLine)

            HStack {
                valueBlock("Volume", "\(AppFormat.decimal(position.size)) \(position.sizeType)")
                Spacer()
                valueBlock("Entrée", AppFormat.decimal(position.openPrice, digits: 5), alignment: .trailing)
                Spacer()
                valueBlock("Swap", AppFormat.currency(position.swap, code: currency, showSign: true), alignment: .trailing)
            }
        }
        .appCard()
    }

    private func valueBlock(_ label: String, _ value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(AppTheme.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
        }
    }
}

private struct PendingOrderCard: View {
    let order: PendingOrder

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.warning)
                .frame(width: 42, height: 42)
                .background(AppTheme.warning.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(order.symbol)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    DirectionBadge(isBuy: order.isBuy, label: order.action)
                }
                Text("\(AppFormat.decimal(order.size)) \(order.sizeType) · \(AppFormat.decimal(order.openPrice, digits: 5))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
        }
        .appCard(padding: 15)
    }
}

private struct PositionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let position: OpenPosition
    let currency: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 9) {
                            DirectionBadge(isBuy: position.isBuy, label: position.action)
                            Text(position.symbol)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                            ProfitText(
                                value: position.profit + position.swap,
                                currency: currency,
                                font: .system(.title2, design: .rounded, weight: .bold)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)

                        VStack(spacing: 0) {
                            detailRow("Ouverture", position.openDate.map(AppFormat.dateTime) ?? "—")
                            detailRow("Volume", "\(AppFormat.decimal(position.size)) \(position.sizeType)")
                            detailRow("Prix d’entrée", AppFormat.decimal(position.openPrice, digits: 5))
                            detailRow("Stop-loss", position.stopLoss == 0 ? "Non défini" : AppFormat.decimal(position.stopLoss, digits: 5))
                            detailRow("Take-profit", position.takeProfit == 0 ? "Non défini" : AppFormat.decimal(position.takeProfit, digits: 5))
                            detailRow("Pips", AppFormat.decimal(position.pips, digits: 1))
                            detailRow("Swap", AppFormat.currency(position.swap, code: currency, showSign: true), divider: false)
                        }
                        .appCard(padding: 6)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Détail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String, divider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(AppTheme.secondary)
                Spacer()
                Text(value).fontWeight(.semibold).foregroundStyle(AppTheme.ink)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            if divider { Divider().overlay(AppTheme.cardLine).padding(.leading, 14) }
        }
    }
}
