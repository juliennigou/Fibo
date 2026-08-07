import XCTest
@testable import Fibo

final class ModelTests: XCTestCase {
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
}
