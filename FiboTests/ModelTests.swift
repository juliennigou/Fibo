import XCTest
@testable import Fibo

final class ModelTests: XCTestCase {
    func testPortfolioAllocationsKeepEarlierDailyGainPersonal() {
        let calendar = Calendar(identifier: .gregorian)
        let personalDate = Date(timeIntervalSince1970: 1_800_000_000)
        let fatherDate = calendar.date(byAdding: .day, value: 1, to: personalDate)!
        let contributions = [
            PortfolioContribution(owner: .personal, amount: 6_000, date: personalDate),
            PortfolioContribution(
                owner: .father,
                amount: 10_000,
                date: fatherDate,
                profitBeforeContributionOnDate: 158.75
            )
        ]
        let result = PortfolioAllocationCalculator.result(
            contributions: contributions,
            daily: [point(on: personalDate, profit: 0), point(on: fatherDate, profit: 158.75)],
            currentBalance: 16_158.75,
            currentDate: fatherDate,
            calendar: calendar
        )

        XCTAssertEqual(result.fatherBalance, 10_000, accuracy: 0.001)
        XCTAssertEqual(result.personalBalance, 6_158.75, accuracy: 0.001)
        XCTAssertEqual(result.fatherPoints.last?.profit ?? .nan, 0, accuracy: 0.001)
        XCTAssertEqual(result.personalPoints.last?.profit ?? .nan, 158.75, accuracy: 0.001)
    }

    func testFatherEntryAnchorKeepsAllExistingBalancePersonal() {
        let calendar = Calendar(identifier: .gregorian)
        let personalDate = Date(timeIntervalSince1970: 1_800_000_000)
        let fatherDate = calendar.date(byAdding: .day, value: 1, to: personalDate)!
        let result = PortfolioAllocationCalculator.result(
            contributions: [
                PortfolioContribution(owner: .personal, amount: 6_000, date: personalDate),
                PortfolioContribution(
                    owner: .father,
                    amount: 10_000,
                    date: fatherDate,
                    profitBeforeContributionOnDate: 100,
                    personalBalanceBeforeContribution: 6_158.75
                )
            ],
            daily: [point(on: personalDate, profit: 0), point(on: fatherDate, profit: 100)],
            currentBalance: 16_158.75,
            currentDate: fatherDate,
            calendar: calendar
        )

        XCTAssertEqual(result.fatherBalance, 10_000, accuracy: 0.001)
        XCTAssertEqual(result.personalBalance, 6_158.75, accuracy: 0.001)
    }

    func testPortfolioAllocationsShareOnlyFuturePerformance() {
        let calendar = Calendar(identifier: .gregorian)
        let personalDate = Date(timeIntervalSince1970: 1_800_000_000)
        let fatherDate = calendar.date(byAdding: .day, value: 1, to: personalDate)!
        let followingDay = calendar.date(byAdding: .day, value: 1, to: fatherDate)!
        let result = PortfolioAllocationCalculator.result(
            contributions: [
                PortfolioContribution(owner: .personal, amount: 6_000, date: personalDate),
                PortfolioContribution(owner: .father, amount: 10_000, date: fatherDate)
            ],
            daily: [
                point(on: personalDate, profit: 0),
                point(on: fatherDate, profit: 0),
                point(on: followingDay, profit: 160)
            ],
            currentBalance: 16_160,
            currentDate: followingDay,
            calendar: calendar
        )

        XCTAssertEqual(result.fatherPoints.last?.profit ?? .nan, 100, accuracy: 0.001)
        XCTAssertEqual(result.personalPoints.last?.profit ?? .nan, 60, accuracy: 0.001)
        XCTAssertEqual(result.fatherBalance, 10_100, accuracy: 0.001)
        XCTAssertEqual(result.personalBalance, 6_060, accuracy: 0.001)
    }

    func testLaterContributionChangesOnlyLaterProfitShares() {
        let calendar = Calendar(identifier: .gregorian)
        let day0 = Date(timeIntervalSince1970: 1_800_000_000)
        let day1 = calendar.date(byAdding: .day, value: 1, to: day0)!
        let day2 = calendar.date(byAdding: .day, value: 2, to: day0)!
        let day3 = calendar.date(byAdding: .day, value: 3, to: day0)!
        let result = PortfolioAllocationCalculator.result(
            contributions: [
                PortfolioContribution(owner: .personal, amount: 6_000, date: day0),
                PortfolioContribution(owner: .father, amount: 10_000, date: day1),
                PortfolioContribution(owner: .personal, amount: 4_040, date: day3)
            ],
            daily: [
                point(on: day0, profit: 0),
                point(on: day1, profit: 0),
                point(on: day2, profit: 160),
                point(on: day3, profit: 202)
            ],
            currentBalance: 20_402,
            currentDate: day3,
            calendar: calendar
        )

        XCTAssertEqual(result.fatherPoints.first(where: { $0.date == day2 })?.profit ?? .nan, 100, accuracy: 0.001)
        XCTAssertEqual(result.personalPoints.first(where: { $0.date == day2 })?.profit ?? .nan, 60, accuracy: 0.001)
        XCTAssertEqual(result.fatherPoints.last?.profit ?? .nan, 101, accuracy: 0.001)
        XCTAssertEqual(result.personalPoints.last?.profit ?? .nan, 101, accuracy: 0.001)
        XCTAssertEqual(result.fatherBalance, 10_201, accuracy: 0.001)
        XCTAssertEqual(result.personalBalance, 10_201, accuracy: 0.001)
    }

    func testPortfolioContributionPersistsAmountOwnerAndDate() throws {
        let contribution = PortfolioContribution(
            owner: .father,
            amount: 10_000,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            profitBeforeContributionOnDate: 42.5,
            personalBalanceBeforeContribution: 6_042.5
        )

        let data = try JSONEncoder().encode([contribution])
        let decoded = try JSONDecoder().decode([PortfolioContribution].self, from: data)

        XCTAssertEqual(decoded, [contribution])
    }

    func testPerformanceCalendarSumsSelectedMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let august3 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let august5 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let september1 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let august = calendar.dateInterval(of: .month, for: august3)!

        let result = PerformanceCalendarCalculator.profit(
            in: august,
            points: [
                point(on: august3, profit: 52.20),
                point(on: august5, profit: 91.64),
                point(on: september1, profit: 44.18)
            ]
        )

        XCTAssertEqual(result, 143.84, accuracy: 0.001)
    }

    func testPerformanceCalendarSumsSelectedWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        let nextMonday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let week = calendar.dateInterval(of: .weekOfYear, for: monday)!

        let result = PerformanceCalendarCalculator.profit(
            in: week,
            points: [
                point(on: monday, profit: 52.20),
                point(on: friday, profit: 202.59),
                point(on: nextMonday, profit: 44.18)
            ]
        )

        XCTAssertEqual(result, 254.79, accuracy: 0.001)
    }

    func testPositionDirection() {
        let position = OpenPosition(
            id: "1", openDate: nil, symbol: "AUDCADp", action: "Buy", size: 0.14,
            sizeType: "lots", openPrice: 0.98, takeProfit: 1, stopLoss: 0.95,
            profit: 26.04, pips: 12, swap: -0.78, comment: "", magic: nil
        )
        XCTAssertTrue(position.isBuy)
        XCTAssertEqual(position.profit + position.swap, 25.26, accuracy: 0.001)
    }

    func testTransactionNetProfitIncludesCosts() {
        let transaction = TradeTransaction(
            id: "1", openDate: nil, closeDate: nil, symbol: "NZDCADp", action: "Buy",
            size: 0.14, sizeType: "lots", openPrice: 0.82, closePrice: 0.83,
            takeProfit: 0, stopLoss: 0, pips: 10, profit: 97.39,
            interest: -2.56, commission: -0.52, comment: ""
        )
        XCTAssertEqual(transaction.netProfit, 94.31, accuracy: 0.001)
    }

    func testProjectionTaxesOnlyPositiveGain() {
        let result = ProjectionCalculator.result(
            capital: 10_000,
            monthlyRatePercent: 0,
            taxRatePercent: 30,
            months: 120
        )

        XCTAssertEqual(result.grossCapital, 10_000, accuracy: 0.001)
        XCTAssertEqual(result.taxableGain, 0, accuracy: 0.001)
        XCTAssertEqual(result.estimatedTax, 0, accuracy: 0.001)
        XCTAssertEqual(result.netCapital, 10_000, accuracy: 0.001)
    }

    func testProjectionCompoundsAndAppliesTaxToGain() {
        let result = ProjectionCalculator.result(
            capital: 10_000,
            monthlyRatePercent: 1,
            taxRatePercent: 30,
            months: 12
        )
        let expectedGross = 10_000.0 * Foundation.pow(1.01, 12.0)
        let expectedTax = (expectedGross - 10_000) * 0.30

        XCTAssertEqual(result.grossCapital, expectedGross, accuracy: 0.001)
        XCTAssertEqual(result.estimatedTax, expectedTax, accuracy: 0.001)
        XCTAssertEqual(result.netCapital, expectedGross - expectedTax, accuracy: 0.001)
    }

    private func point(on date: Date, profit: Double) -> DailyPoint {
        DailyPoint(
            date: date,
            balance: 0,
            pips: 0,
            lots: 0,
            floatingProfit: 0,
            profit: profit,
            growthEquity: 0
        )
    }
}
