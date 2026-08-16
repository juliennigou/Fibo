import Foundation

enum AppPreferenceKey {
    static let portfolioSplitEnabled = "portfolioSplitEnabled"
    static let amountsHidden = "amountsHidden"
}

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

enum PortfolioAllocation: Int, CaseIterable, Identifiable {
    case total
    case father
    case personal

    var id: Int { rawValue }
}

enum PortfolioOwner: String, CaseIterable, Codable, Identifiable {
    case personal
    case father

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Moi"
        case .father: "Père"
        }
    }
}

struct PortfolioContribution: Identifiable, Codable, Equatable {
    let id: UUID
    var owner: PortfolioOwner
    var amount: Double
    var date: Date
    var profitBeforeContributionOnDate: Double?
    var personalBalanceBeforeContribution: Double?

    init(
        id: UUID = UUID(),
        owner: PortfolioOwner,
        amount: Double,
        date: Date,
        profitBeforeContributionOnDate: Double? = nil,
        personalBalanceBeforeContribution: Double? = nil
    ) {
        self.id = id
        self.owner = owner
        self.amount = amount
        self.date = date
        self.profitBeforeContributionOnDate = profitBeforeContributionOnDate
        self.personalBalanceBeforeContribution = personalBalanceBeforeContribution
    }
}

struct PortfolioAllocationResult {
    let totalPoints: [DailyPoint]
    let fatherPoints: [DailyPoint]
    let personalPoints: [DailyPoint]
    let totalBalance: Double
    let fatherBalance: Double
    let personalBalance: Double
    let totalInvestedCapital: Double
    let fatherInvestedCapital: Double
    let personalInvestedCapital: Double

    func points(for allocation: PortfolioAllocation) -> [DailyPoint] {
        switch allocation {
        case .total: totalPoints
        case .father: fatherPoints
        case .personal: personalPoints
        }
    }

    func balance(for allocation: PortfolioAllocation) -> Double {
        switch allocation {
        case .total: totalBalance
        case .father: fatherBalance
        case .personal: personalBalance
        }
    }

    func investedCapital(for allocation: PortfolioAllocation) -> Double {
        switch allocation {
        case .total: totalInvestedCapital
        case .father: fatherInvestedCapital
        case .personal: personalInvestedCapital
        }
    }

    func profitSinceStart(for allocation: PortfolioAllocation) -> Double {
        balance(for: allocation) - investedCapital(for: allocation)
    }

    func currentShare(for allocation: PortfolioAllocation) -> Double {
        guard abs(totalBalance) > 0.01 else { return allocation == .total ? 1 : 0 }
        switch allocation {
        case .total: return 1
        case .father: return fatherBalance / totalBalance
        case .personal: return personalBalance / totalBalance
        }
    }
}

enum PortfolioAllocationCalculator {
    static func result(
        contributions: [PortfolioContribution],
        daily: [DailyPoint],
        currentBalance: Double,
        currentDate: Date,
        calendar: Calendar = .current
    ) -> PortfolioAllocationResult {
        let eligibleContributions = contributions
            .filter { $0.amount != 0 && $0.date <= currentDate }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.date < rhs.date
            }
        let sortedPoints = daily.sorted { $0.date < $1.date }

        var balances: [PortfolioOwner: Double] = [.personal: 0, .father: 0]
        var invested: [PortfolioOwner: Double] = [.personal: 0, .father: 0]
        var hasCapital: [PortfolioOwner: Bool] = [.personal: false, .father: false]
        var personalPoints: [DailyPoint] = []
        var fatherPoints: [DailyPoint] = []
        var contributionIndex = 0

        func distribute(_ profit: Double) -> (personal: Double, father: Double) {
            let personalBase = max(balances[.personal, default: 0], 0)
            let fatherBase = max(balances[.father, default: 0], 0)
            let totalBase = personalBase + fatherBase
            let personalProfit: Double
            let fatherProfit: Double

            if totalBase > 0.01 {
                personalProfit = profit * personalBase / totalBase
                fatherProfit = profit - personalProfit
            } else {
                personalProfit = profit
                fatherProfit = 0
            }

            balances[.personal, default: 0] += personalProfit
            balances[.father, default: 0] += fatherProfit
            return (personalProfit, fatherProfit)
        }

        func apply(_ contribution: PortfolioContribution) {
            balances[contribution.owner, default: 0] += contribution.amount
            invested[contribution.owner, default: 0] += contribution.amount
            hasCapital[contribution.owner] = true
        }

        for point in sortedPoints {
            let pointDay = calendar.startOfDay(for: point.date)

            while contributionIndex < eligibleContributions.count,
                  calendar.startOfDay(for: eligibleContributions[contributionIndex].date) < pointDay {
                apply(eligibleContributions[contributionIndex])
                contributionIndex += 1
            }

            var contributionsToday: [PortfolioContribution] = []
            while contributionIndex < eligibleContributions.count,
                  calendar.isDate(eligibleContributions[contributionIndex].date, inSameDayAs: point.date) {
                contributionsToday.append(eligibleContributions[contributionIndex])
                contributionIndex += 1
            }
            contributionsToday.sort {
                switch ($0.profitBeforeContributionOnDate, $1.profitBeforeContributionOnDate) {
                case (nil, .some): return true
                case (.some, nil): return false
                case let (.some(lhs), .some(rhs)): return lhs < rhs
                case (nil, nil): return $0.id.uuidString < $1.id.uuidString
                }
            }

            var allocatedProfit = 0.0
            var personalProfit = 0.0
            var fatherProfit = 0.0

            for contribution in contributionsToday {
                let profitBeforeContribution = contribution.profitBeforeContributionOnDate ?? 0
                let segment = profitBeforeContribution - allocatedProfit
                let allocation = distribute(segment)
                personalProfit += allocation.personal
                fatherProfit += allocation.father
                allocatedProfit = profitBeforeContribution
                if let personalBalance = contribution.personalBalanceBeforeContribution {
                    balances[.personal] = personalBalance
                    hasCapital[.personal] = true
                }
                apply(contribution)
            }

            let remainingAllocation = distribute(point.profit - allocatedProfit)
            personalProfit += remainingAllocation.personal
            fatherProfit += remainingAllocation.father

            let trackedBalance = balances.values.reduce(0, +)
            let personalShare = abs(trackedBalance) > 0.01
                ? balances[.personal, default: 0] / trackedBalance
                : 0
            let fatherShare = abs(trackedBalance) > 0.01
                ? balances[.father, default: 0] / trackedBalance
                : 0

            if hasCapital[.personal] == true {
                personalPoints.append(
                    allocatedPoint(
                        point,
                        balance: balances[.personal, default: 0],
                        profit: personalProfit,
                        floatingShare: personalShare
                    )
                )
            }
            if hasCapital[.father] == true {
                fatherPoints.append(
                    allocatedPoint(
                        point,
                        balance: balances[.father, default: 0],
                        profit: fatherProfit,
                        floatingShare: fatherShare
                    )
                )
            }
        }

        while contributionIndex < eligibleContributions.count {
            apply(eligibleContributions[contributionIndex])
            contributionIndex += 1
        }

        _ = distribute(currentBalance - balances.values.reduce(0, +))

        return PortfolioAllocationResult(
            totalPoints: sortedPoints,
            fatherPoints: fatherPoints,
            personalPoints: personalPoints,
            totalBalance: currentBalance,
            fatherBalance: balances[.father, default: 0],
            personalBalance: balances[.personal, default: 0],
            totalInvestedCapital: invested.values.reduce(0, +),
            fatherInvestedCapital: invested[.father, default: 0],
            personalInvestedCapital: invested[.personal, default: 0]
        )
    }

    private static func allocatedPoint(
        _ point: DailyPoint,
        balance: Double,
        profit: Double,
        floatingShare: Double
    ) -> DailyPoint {
        DailyPoint(
            date: point.date,
            balance: balance,
            pips: point.pips,
            lots: point.lots,
            floatingProfit: point.floatingProfit * floatingShare,
            profit: profit,
            growthEquity: point.growthEquity
        )
    }
}

struct PortfolioAllocationBasis: Codable, Equatable {
    static let fatherInitialCapital = 10_000.0
    static let personalInitialCapital = 6_000.0

    let fatherEntryDate: Date
    let totalBalanceAtFatherEntry: Double
    let dailyProfitAtFatherEntry: Double

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
