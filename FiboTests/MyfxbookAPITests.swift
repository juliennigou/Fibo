import XCTest
@testable import Fibo

final class MyfxbookAPITests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.handler = nil
    }

    func testAccountsDecodeNumbersAndStrings() async throws {
        let api = makeAPI(json: """
        {
          "error": false,
          "message": "",
          "accounts": [{
            "id": 42,
            "accountId": 123456,
            "name": "Demo Strategy",
            "gain": 2.41,
            "daily": "0.04",
            "monthly": "1.25",
            "withdrawals": 0,
            "deposits": 6000,
            "profit": 158.75,
            "balance": 6158.75,
            "drawdown": 3.2,
            "equity": 6170.5,
            "demo": false,
            "lastUpdateDate": "08/07/2026 16:00",
            "firstTradeDate": "07/01/2026 09:00",
            "commission": -0.52,
            "currency": "EUR",
            "profitFactor": 1.8,
            "pips": 81.2,
            "server": { "name": "Demo Broker" }
          }]
        }
        """)

        let accounts = try await api.accounts(sessionID: "session")
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].accountNumber, 123456)
        XCTAssertEqual(accounts[0].balance, 6158.75, accuracy: 0.001)
        XCTAssertEqual(accounts[0].dailyGain, 0.04, accuracy: 0.001)
        XCTAssertFalse(accounts[0].isDemo)
    }

    func testNestedDailyArrayIsFlattened() async throws {
        let api = makeAPI(json: """
        {
          "error": false,
          "message": "",
          "dataDaily": [[{
            "date": "08/05/2026",
            "balance": 6158.75,
            "pips": 42.1,
            "lots": 0.96,
            "floatingPL": 0,
            "profit": 94.31,
            "growthEquity": 1.55
          }]]
        }
        """)

        let points = try await api.dailyData(
            sessionID: "session",
            accountID: 42,
            start: Date(timeIntervalSince1970: 0),
            end: Date()
        )
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].profit, 94.31, accuracy: 0.001)
        XCTAssertEqual(points[0].balance, 6158.75, accuracy: 0.001)
    }

    func testAPIErrorsAreSurfaced() async {
        let api = makeAPI(json: #"{"error":true,"message":"Invalid session"}"#)
        do {
            _ = try await api.accounts(sessionID: "expired")
            XCTFail("Expected authentication error")
        } catch {
            XCTAssertEqual(error as? MyfxbookError, .authenticationRequired)
        }
    }

    func testLoginErrorDoesNotRequireSessionField() async {
        let api = makeAPI(json: #"{"error":true,"message":"Invalid credentials"}"#)
        do {
            _ = try await api.login(email: "test@example.com", password: "invalid")
            XCTFail("Expected API error")
        } catch MyfxbookError.api(let message) {
            XCTAssertEqual(message, "Invalid credentials")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoginPreservesSpecialCharactersInCredentials() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
            let query = Dictionary(uniqueKeysWithValues: (items ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            })
            XCTAssertEqual(query["email"], "dev+trading@example.com")
            XCTAssertEqual(query["password"], "Example+&$42")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"error":false,"message":"","session":"safe-session"}"#.utf8)
            )
        }

        let api = MyfxbookAPI(session: URLSession(configuration: configuration))
        let session = try await api.login(email: "dev+trading@example.com", password: "Example+&$42")
        XCTAssertEqual(session, "safe-session")
    }

    private func makeAPI(json: String) -> MyfxbookAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "www.myfxbook.com")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        return MyfxbookAPI(session: URLSession(configuration: configuration))
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
