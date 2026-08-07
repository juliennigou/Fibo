import Foundation

struct TradingAccount: Identifiable, Codable, Equatable {
    let id: Int
    let accountNumber: Int
    let name: String
    let broker: String
    let currency: String
    let balance: Double
    let equity: Double
    let profit: Double
    let gain: Double
    let dailyGain: Double
    let monthlyGain: Double
    let drawdown: Double
    let deposits: Double
    let withdrawals: Double
    let commission: Double
    let pips: Double
    let profitFactor: Double
    let isDemo: Bool
    let lastUpdate: Date?
    let firstTradeDate: Date?

    var floatingProfit: Double { equity - balance }
}

struct OpenPosition: Identifiable, Codable, Equatable {
    let id: String
    let openDate: Date?
    let symbol: String
    let action: String
    let size: Double
    let sizeType: String
    let openPrice: Double
    let takeProfit: Double
    let stopLoss: Double
    let profit: Double
    let pips: Double
    let swap: Double
    let comment: String
    let magic: Int?

    var isBuy: Bool { action.localizedCaseInsensitiveContains("buy") }
}

struct PendingOrder: Identifiable, Codable, Equatable {
    let id: String
    let openDate: Date?
    let symbol: String
    let action: String
    let size: Double
    let sizeType: String
    let openPrice: Double
    let takeProfit: Double
    let stopLoss: Double
    let comment: String

    var isBuy: Bool { action.localizedCaseInsensitiveContains("buy") }
}

struct TradeTransaction: Identifiable, Codable, Equatable {
    let id: String
    let openDate: Date?
    let closeDate: Date?
    let symbol: String
    let action: String
    let size: Double
    let sizeType: String
    let openPrice: Double
    let closePrice: Double
    let takeProfit: Double
    let stopLoss: Double
    let pips: Double
    let profit: Double
    let interest: Double
    let commission: Double
    let comment: String

    var netProfit: Double { profit + interest + commission }
    var isBuy: Bool { action.localizedCaseInsensitiveContains("buy") }
}

struct DailyPoint: Identifiable, Codable, Equatable {
    var id: Date { date }
    let date: Date
    let balance: Double
    let pips: Double
    let lots: Double
    let floatingProfit: Double
    let profit: Double
    let growthEquity: Double
}

struct DashboardSnapshot: Codable, Equatable {
    let fetchedAt: Date
    let account: TradingAccount
    let positions: [OpenPosition]
    let orders: [PendingOrder]
    let history: [TradeTransaction]
    let daily: [DailyPoint]
}

enum ChartRange: String, CaseIterable, Identifiable {
    case week = "1S"
    case month = "1M"
    case quarter = "3M"
    case year = "1A"
    case all = "TOUT"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 31
        case .quarter: 92
        case .year: 366
        case .all: nil
        }
    }
}
