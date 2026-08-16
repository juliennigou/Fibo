import SwiftUI

enum PerformanceCalendarCalculator {
    static func profit(
        in interval: DateInterval,
        points: [DailyPoint]
    ) -> Double {
        points
            .filter { $0.date >= interval.start && $0.date < interval.end }
            .reduce(0) { $0 + $1.profit }
    }

    static func trades(
        on date: Date,
        history: [TradeTransaction],
        activePoints: [DailyPoint],
        calendar: Calendar
    ) -> [TradeTransaction] {
        guard activePoints.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return []
        }
        return history
            .filter { transaction in
                guard let closeDate = transaction.closeDate else { return false }
                return calendar.isDate(closeDate, inSameDayAs: date)
            }
            .sorted { ($0.closeDate ?? .distantPast) > ($1.closeDate ?? .distantPast) }
    }
}

struct PerformanceCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferenceKey.amountsHidden) private var amountsHidden = false

    let points: [DailyPoint]
    let history: [TradeTransaction]
    let currency: String

    @State private var displayedMonth: Date
    @State private var selectedDate: Date
    @State private var detailDay: CalendarDaySelection?

    private let calendar: Calendar

    init(points: [DailyPoint], history: [TradeTransaction], currency: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
        self.points = points
        self.history = history
        self.currency = currency

        let referenceDate = points.map(\.date).max() ?? Date()
        let month = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        _displayedMonth = State(initialValue: month)
        _selectedDate = State(initialValue: calendar.startOfDay(for: referenceDate))
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth)
            ?? DateInterval(start: displayedMonth, duration: 0)
    }

    private var monthProfit: Double {
        PerformanceCalendarCalculator.profit(in: monthInterval, points: points)
    }

    private var gridDates: [Date] {
        guard let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start else {
            return []
        }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var weeks: [[Date]] {
        stride(from: 0, to: gridDates.count, by: 7).map { start in
            Array(gridDates[start..<min(start + 7, gridDates.count)])
        }
    }

    private var canMoveForward: Bool {
        let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return displayedMonth < currentMonth
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                fullPageCalendar
            }
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $detailDay) { selection in
                CalendarDayDetailView(
                    date: selection.date,
                    profit: profit(on: selection.date),
                    trades: trades(on: selection.date),
                    currency: currency
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
    }

    private var fullPageCalendar: some View {
        VStack(spacing: 0) {
            monthHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider().overlay(AppTheme.cardLine)

            weekdayHeader
                .padding(.horizontal, 8)
                .padding(.vertical, 9)

            GeometryReader { geometry in
                let rowHeight = max(55, (geometry.size.height - 5) / 6)
                VStack(spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                        weekRow(week, height: rowHeight)
                        if index < weeks.count - 1 {
                            Divider().overlay(AppTheme.cardLine.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .id(displayedMonth)
                .transition(.opacity)
                .simultaneousGesture(monthSwipe)
            }

            HStack(spacing: 14) {
                legend(color: AppTheme.positive, text: "Gain")
                legend(color: AppTheme.negative, text: "Perte")
                Spacer()
                Text("Toucher un jour pour le détail")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }

    private var monthHeader: some View {
        HStack {
            monthButton(symbol: "chevron.left") { moveMonth(by: -1) }
            Spacer()
            VStack(spacing: 3) {
                Text(
                    displayedMonth.formatted(
                        .dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))
                    ).capitalized
                )
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                Text(AppFormat.currency(monthProfit, code: currency, showSign: true))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(tint(for: monthProfit))
                    .sensitiveAmount()
            }
            Spacer()
            monthButton(symbol: "chevron.right", isDisabled: !canMoveForward) { moveMonth(by: 1) }
        }
    }

    private var weekdayHeader: some View {
        let symbols = ["L", "M", "M", "J", "V", "S", "D"]
        return HStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            Text("SEM.")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(AppTheme.secondary)
                .frame(width: 50)
        }
    }

    private func weekRow(_ dates: [Date], height: CGFloat) -> some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(dates, id: \.self) { date in
                    dayCell(date, height: height - 8)
                }
            }
            weeklyTotal(dates, height: height - 8)
                .frame(width: 50)
        }
        .frame(height: height)
    }

    private func weeklyTotal(_ dates: [Date], height: CGFloat) -> some View {
        let value = weekProfit(for: dates)
        return VStack(spacing: 2) {
            Text(compactAmount(value))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint(for: value))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .sensitiveAmount()
            Text(currencySymbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppTheme.secondary)
                .sensitiveAmount()
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .background(AppTheme.primarySoft.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total de la semaine")
        .accessibilityValue(
            amountsHidden
                ? "Montant masqué"
                : AppFormat.currency(value, code: currency, showSign: true)
        )
    }

    private func dayCell(_ date: Date, height: CGFloat) -> some View {
        let isInMonth = isInMonth(date)
        let dayProfit = profit(on: date)
        let dayTrades = trades(on: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(selectedDate, inSameDayAs: date)

        return Button {
            if isInMonth {
                selectedDate = date
                detailDay = CalendarDaySelection(date: date)
            } else {
                displayedMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
                selectedDate = date
            }
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 12, weight: isToday ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isToday ? Color.white : AppTheme.ink)
                    .frame(width: 23, height: 23)
                    .background(isToday ? AppTheme.primary : Color.clear)
                    .clipShape(Circle())

                if isInMonth, dayProfit != 0 {
                    Text(compactAmount(dayProfit))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(tint(for: dayProfit))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .sensitiveAmount()
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                }

                if isInMonth, !dayTrades.isEmpty {
                    Text("\(dayTrades.count) op.")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.system(size: 8.5))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(dayBackground(dayProfit, isInMonth: isInMonth))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.primary, lineWidth: 1.5)
                }
            }
            .opacity(isInMonth ? 1 : 0.28)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityLabel(for: date, profit: dayProfit, trades: dayTrades.count))
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 45 else { return }
                if value.translation.width < 0 {
                    if canMoveForward { moveMonth(by: 1) }
                } else {
                    moveMonth(by: -1)
                }
            }
    }

    private func monthButton(
        symbol: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isDisabled ? AppTheme.secondary.opacity(0.3) : AppTheme.primary)
                .frame(width: 36, height: 36)
                .background(AppTheme.primarySoft.opacity(isDisabled ? 0.4 : 1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        let newInterval = calendar.dateInterval(of: .month, for: newMonth)
        let newSelection = points.map(\.date).filter { date in
            guard let newInterval else { return false }
            return date >= newInterval.start && date < newInterval.end
        }.max()
            ?? newInterval?.start
            ?? newMonth
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
            selectedDate = newSelection
            detailDay = nil
        }
    }

    private func profit(on date: Date) -> Double {
        points
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.profit }
    }

    private func isInMonth(_ date: Date) -> Bool {
        date >= monthInterval.start && date < monthInterval.end
    }

    private func trades(on date: Date) -> [TradeTransaction] {
        PerformanceCalendarCalculator.trades(
            on: date,
            history: history,
            activePoints: points,
            calendar: calendar
        )
    }

    private func weekProfit(for dates: [Date]) -> Double {
        guard let start = dates.first,
              let end = calendar.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return PerformanceCalendarCalculator.profit(
            in: DateInterval(start: start, end: end),
            points: points
        )
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.currencySymbol ?? currency
    }

    private func compactAmount(_ value: Double) -> String {
        if abs(value) < 0.005 { return "0" }
        let sign = value > 0 ? "+" : "−"
        let absolute = abs(value)
        if absolute >= 1_000 {
            return "\(sign)\(AppFormat.decimal(absolute / 1_000, digits: 1))k"
        }
        return "\(sign)\(AppFormat.decimal(absolute, digits: 0))"
    }

    private func dayBackground(_ profit: Double, isInMonth: Bool) -> Color {
        guard isInMonth else { return Color.clear }
        if profit > 0 { return AppTheme.positive.opacity(0.1) }
        if profit < 0 { return AppTheme.negative.opacity(0.09) }
        return AppTheme.background.opacity(0.52)
    }

    private func tint(for amount: Double) -> Color {
        if amount > 0 { return AppTheme.positive }
        if amount < 0 { return AppTheme.negative }
        return AppTheme.ink
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(AppTheme.secondary)
    }

    private func accessibilityLabel(for date: Date, profit: Double, trades: Int) -> String {
        let formattedDate = date.formatted(
            .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))
        )
        let result = amountsHidden
            ? "montant masqué"
            : AppFormat.currency(profit, code: currency, showSign: true)
        return "\(formattedDate), \(result), \(trades) opération\(trades > 1 ? "s" : "")"
    }
}

private struct CalendarDaySelection: Identifiable {
    var id: Date { date }
    let date: Date
}

private struct CalendarDayDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let profit: Double
    let trades: [TradeTransaction]
    let currency: String

    private var wins: Int { trades.filter { $0.netProfit > 0 }.count }
    private var losses: Int { trades.filter { $0.netProfit < 0 }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 7) {
                            Text("Résultat du jour")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondary)
                            Text(AppFormat.currency(profit, code: currency, showSign: true))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(tint)
                                .sensitiveAmount()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.cardLine, lineWidth: 0.8)
                        }

                        HStack(spacing: 8) {
                            stat(title: "Trades", value: trades.count, color: AppTheme.primary)
                            stat(title: "Gagnés", value: wins, color: AppTheme.positive)
                            stat(title: "Perdus", value: losses, color: AppTheme.negative)
                        }

                        if trades.isEmpty {
                            EmptyStateCard(
                                symbol: "calendar.badge.clock",
                                title: "Aucune opération détaillée",
                                message: profit == 0
                                    ? "Aucun résultat enregistré pour cette journée."
                                    : "Le résultat journalier est disponible, mais Myfxbook n’a pas renvoyé le détail de ces opérations."
                            )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                                    tradeRow(trade)
                                    if index < trades.count - 1 {
                                        Divider().overlay(AppTheme.cardLine).padding(.leading, 44)
                                    }
                                }
                            }
                            .appCard(padding: 8)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(
                date.formatted(
                    .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))
                ).capitalized
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var tint: Color {
        if profit > 0 { return AppTheme.positive }
        if profit < 0 { return AppTheme.negative }
        return AppTheme.ink
    }

    private func stat(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 0.7)
        }
    }

    private func tradeRow(_ trade: TradeTransaction) -> some View {
        HStack(spacing: 11) {
            Image(systemName: trade.isBuy ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(trade.isBuy ? AppTheme.positive : AppTheme.negative)
                .frame(width: 34, height: 34)
                .background((trade.isBuy ? AppTheme.positive : AppTheme.negative).opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(trade.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(trade.action) · \(AppFormat.decimal(trade.size)) \(trade.sizeType)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(outcome(for: trade.netProfit))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outcomeColor(for: trade.netProfit))
                Text(trade.closeDate?.formatted(.dateTime.hour().minute()) ?? "—")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func outcome(for value: Double) -> String {
        if value > 0 { return "Gagné" }
        if value < 0 { return "Perdu" }
        return "Neutre"
    }

    private func outcomeColor(for value: Double) -> Color {
        if value > 0 { return AppTheme.positive }
        if value < 0 { return AppTheme.negative }
        return AppTheme.secondary
    }
}
