import Foundation

enum PreviewData {
    static let snapshot: DashboardSnapshot = {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let daily: [DailyPoint] = (0..<120).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 119, to: now) else { return nil }
            let trend = Double(offset) * 5.4
            let wave = sin(Double(offset) / 7.0) * 85 + cos(Double(offset) / 13.0) * 45
            let personalCapitalAdjustment = 475.0
            let tradingBalance = 5480 + trend + wave + personalCapitalAdjustment
            let fatherDeposit = offset == 119 ? PortfolioAllocationBasis.fatherInitialCapital : 0
            let balance = tradingBalance + fatherDeposit
            let previous = 5480 + Double(max(0, offset - 1)) * 5.4
                + sin(Double(max(0, offset - 1)) / 7.0) * 85
                + cos(Double(max(0, offset - 1)) / 13.0) * 45
                + personalCapitalAdjustment
            return DailyPoint(
                date: date,
                balance: balance,
                pips: (balance - previous) * 0.4,
                lots: offset % 3 == 0 ? 0.42 : 0.14,
                floatingProfit: 0,
                profit: offset == 0 ? 0 : tradingBalance - previous,
                growthEquity: 0
            )
        }

        let account = TradingAccount(
            id: 100001,
            accountNumber: 123456,
            name: "Demo Strategy",
            broker: "Demo Broker",
            currency: "EUR",
            balance: daily.last?.balance ?? 6158.75,
            equity: (daily.last?.balance ?? 6158.75) + 18.42,
            profit: 702.31,
            gain: 11.71,
            dailyGain: 0.62,
            monthlyGain: 3.84,
            drawdown: 4.28,
            deposits: 16000,
            withdrawals: 0,
            commission: -4.12,
            pips: 284.2,
            profitFactor: 1.74,
            isDemo: false,
            lastUpdate: now,
            firstTradeDate: daily.first?.date
        )

        let positions = [
            OpenPosition(
                id: "preview-1", openDate: calendar.date(byAdding: .hour, value: -5, to: now),
                symbol: "AUDCADp", action: "Buy", size: 0.14, sizeType: "lots", openPrice: 0.98825,
                takeProfit: 0.99520, stopLoss: 0.98210, profit: 23.18, pips: 18.4, swap: -0.42,
                comment: "demo", magic: 10101
            ),
            OpenPosition(
                id: "preview-2", openDate: calendar.date(byAdding: .hour, value: -2, to: now),
                symbol: "NZDCADp", action: "Sell", size: 0.08, sizeType: "lots", openPrice: 0.82608,
                takeProfit: 0.82000, stopLoss: 0.83120, profit: -4.34, pips: -6.2, swap: 0,
                comment: "demo", magic: 10101
            )
        ]

        let history: [TradeTransaction] = (0..<12).map { index in
            let profit = index % 4 == 0 ? -18.40 : Double(12 + index * 3)
            return TradeTransaction(
                id: "history-\(index)",
                openDate: calendar.date(byAdding: .day, value: -index - 1, to: now),
                closeDate: calendar.date(byAdding: .day, value: -index, to: now),
                symbol: index % 2 == 0 ? "AUDCADp" : "NZDCADp",
                action: index % 3 == 0 ? "Sell" : "Buy",
                size: 0.14,
                sizeType: "lots",
                openPrice: 0.98,
                closePrice: 0.99,
                takeProfit: 0,
                stopLoss: 0,
                pips: profit / 2,
                profit: profit,
                interest: index % 5 == 0 ? -0.62 : 0,
                commission: 0,
                comment: "demo"
            )
        }

        return DashboardSnapshot(
            fetchedAt: now,
            account: account,
            positions: positions,
            orders: [],
            history: history,
            daily: daily
        )
    }()
}
