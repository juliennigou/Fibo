import Foundation

enum MyfxbookError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case api(String)
    case authenticationRequired
    case accountNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Impossible de construire la requête Myfxbook."
        case .invalidResponse: "Myfxbook a renvoyé une réponse illisible."
        case let .api(message): Self.localizedAPIMessage(message)
        case .authenticationRequired: "La session Myfxbook a expiré."
        case .accountNotFound: "Aucun compte de trading n’est disponible dans Myfxbook."
        }
    }

    private static func localizedAPIMessage(_ message: String) -> String {
        let normalized = message.lowercased()
        if normalized.contains("wrong email/password") || normalized.contains("wrong email or password") {
            return "L’adresse e-mail ou le mot de passe Myfxbook est incorrect."
        }
        if normalized.contains("max login attempts") {
            return "Trop de tentatives Myfxbook. Connecte-toi d’abord sur myfxbook.com, puis réessaie dans Fibo."
        }
        return message.isEmpty ? "Une erreur Myfxbook est survenue." : message
    }
}

private protocol MyfxbookResponse: Decodable {
    var error: Bool { get }
    var message: String { get }
}

private struct ResponseEnvelope: Decodable {
    let error: Bool
    let message: String
}

actor MyfxbookAPI {
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage?
    private let baseURL = URL(string: "https://www.myfxbook.com/api/")!

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            cookieStorage = session.configuration.httpCookieStorage
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 25
            configuration.httpShouldSetCookies = true
            configuration.httpCookieAcceptPolicy = .always
            configuration.httpMaximumConnectionsPerHost = 1
            configuration.httpAdditionalHeaders = ["Accept": "application/json"]
            self.session = URLSession(configuration: configuration)
            cookieStorage = configuration.httpCookieStorage
        }
    }

    func login(email: String, password: String) async throws -> String {
        let response: LoginResponse = try await request(
            "login.json",
            query: [URLQueryItem(name: "email", value: email), URLQueryItem(name: "password", value: password)],
            requiresSession: false
        )
        guard let encodedSession = response.session?.trimmingCharacters(in: .whitespacesAndNewlines),
              !encodedSession.isEmpty else { throw MyfxbookError.invalidResponse }
        return encodedSession.removingPercentEncoding ?? encodedSession
    }

    func logout(sessionID: String) async {
        let _: BasicResponse? = try? await request(
            "logout.json",
            query: [URLQueryItem(name: "session", value: sessionID)]
        )
    }

    func accounts(sessionID: String) async throws -> [TradingAccount] {
        let response: AccountsResponse = try await request(
            "get-my-accounts.json",
            query: [URLQueryItem(name: "session", value: sessionID)]
        )
        return response.accounts.map(\.domain)
    }

    func openPositions(sessionID: String, accountID: Int) async throws -> [OpenPosition] {
        let response: OpenTradesResponse = try await accountRequest(
            "get-open-trades.json", sessionID: sessionID, accountID: accountID
        )
        return response.openTrades.enumerated().map { $0.element.domain(index: $0.offset) }
    }

    func pendingOrders(sessionID: String, accountID: Int) async throws -> [PendingOrder] {
        let response: OpenOrdersResponse = try await accountRequest(
            "get-open-orders.json", sessionID: sessionID, accountID: accountID
        )
        return response.openOrders.enumerated().map { $0.element.domain(index: $0.offset) }
    }

    func history(sessionID: String, accountID: Int) async throws -> [TradeTransaction] {
        let response: HistoryResponse = try await accountRequest(
            "get-history.json", sessionID: sessionID, accountID: accountID
        )
        return response.history.enumerated().map { $0.element.domain(index: $0.offset) }
    }

    func dailyData(sessionID: String, accountID: Int, start: Date, end: Date) async throws -> [DailyPoint] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let response: DailyDataResponse = try await request(
            "get-data-daily.json",
            query: [
                URLQueryItem(name: "session", value: sessionID),
                URLQueryItem(name: "id", value: String(accountID)),
                URLQueryItem(name: "start", value: formatter.string(from: start)),
                URLQueryItem(name: "end", value: formatter.string(from: end))
            ]
        )
        return response.dataDaily.values.compactMap(\.domain).sorted { $0.date < $1.date }
    }

    private func accountRequest<Response: MyfxbookResponse>(
        _ endpoint: String,
        sessionID: String,
        accountID: Int
    ) async throws -> Response {
        try await request(
            endpoint,
            query: [
                URLQueryItem(name: "session", value: sessionID),
                URLQueryItem(name: "id", value: String(accountID))
            ]
        )
    }

    private func request<Response: MyfxbookResponse>(
        _ endpoint: String,
        query: [URLQueryItem],
        requiresSession: Bool = true
    ) async throws -> Response {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw MyfxbookError.invalidURL
        }
        components.queryItems = query
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw MyfxbookError.invalidURL }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 25)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cookies = cookieStorage?.cookies(for: url), !cookies.isEmpty {
            HTTPCookie.requestHeaderFields(with: cookies).forEach {
                request.setValue($0.value, forHTTPHeaderField: $0.key)
            }
        }

        debugLog("→ \(endpoint)")

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            let networkError = error as NSError
            debugLog("✕ \(endpoint) network \(networkError.domain) \(networkError.code)")
            throw error
        }

        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            debugLog("✕ \(endpoint) non-HTTP response")
            throw MyfxbookError.invalidResponse
        }
        debugLog("← \(endpoint) HTTP \(http.statusCode)")
        guard (200..<300).contains(http.statusCode) else { throw MyfxbookError.invalidResponse }

        let envelope: ResponseEnvelope
        do {
            envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        } catch {
            debugLog("✕ \(endpoint) unreadable JSON (\(data.count) bytes)")
            throw MyfxbookError.invalidResponse
        }

        if envelope.error {
            debugLog("✕ \(endpoint) Myfxbook: \(envelope.message)")
            let lowercased = envelope.message.lowercased()
            if requiresSession && (
                lowercased.contains("session") ||
                lowercased.contains("login") ||
                lowercased.contains("authentication")
            ) {
                throw MyfxbookError.authenticationRequired
            }
            throw MyfxbookError.api(envelope.message)
        }

        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            debugLog("✓ \(endpoint)")
            return decoded
        } catch {
            debugLog("✕ \(endpoint) unexpected JSON structure")
            throw MyfxbookError.invalidResponse
        }
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[Fibo/Myfxbook] \(message)")
#endif
    }
}

private struct BasicResponse: MyfxbookResponse {
    let error: Bool
    let message: String
}

private struct LoginResponse: MyfxbookResponse {
    let error: Bool
    let message: String
    let session: String?
}

private struct AccountsResponse: MyfxbookResponse {
    let error: Bool
    let message: String
    let accounts: [AccountDTO]
}

private struct OpenTradesResponse: MyfxbookResponse {
    let error: Bool
    let message: String
    let openTrades: [OpenTradeDTO]
}

private struct OpenOrdersResponse: MyfxbookResponse {
    let error: Bool
    let message: String
    let openOrders: [OpenOrderDTO]
}

private struct HistoryResponse: MyfxbookResponse {
    let error: Bool
    let message: String
    let history: [HistoryDTO]
}

private struct DailyDataResponse: MyfxbookResponse {
    let error: Bool
    let message: String
    let dataDaily: FlatOrNestedArray<DailyDTO>
}

private struct FlatOrNestedArray<Element: Decodable>: Decodable {
    let values: [Element]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            values = []
        } else if let flat = try? container.decode([Element].self) {
            values = flat
        } else {
            values = try container.decode([[Element]].self).flatMap { $0 }
        }
    }
}

private struct ServerDTO: Decodable {
    let name: String
}

private struct AccountDTO: Decodable {
    let id: Int
    let accountID: Int
    let name: String
    let gain: Double
    let daily: Double
    let monthly: Double
    let withdrawals: Double
    let deposits: Double
    let profit: Double
    let balance: Double
    let drawdown: Double
    let equity: Double
    let demo: Bool
    let lastUpdateDate: String
    let firstTradeDate: String
    let commission: Double
    let currency: String
    let profitFactor: Double
    let pips: Double
    let server: ServerDTO

    enum CodingKeys: String, CodingKey {
        case id, name, gain, daily, monthly, withdrawals, deposits, profit, balance, drawdown, equity
        case demo, lastUpdateDate, firstTradeDate, commission, currency, profitFactor, pips, server
        case accountID = "accountId"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexibleInt(.id)
        accountID = c.flexibleInt(.accountID)
        name = c.string(.name)
        gain = c.flexibleDouble(.gain)
        daily = c.flexibleDouble(.daily)
        monthly = c.flexibleDouble(.monthly)
        withdrawals = c.flexibleDouble(.withdrawals)
        deposits = c.flexibleDouble(.deposits)
        profit = c.flexibleDouble(.profit)
        balance = c.flexibleDouble(.balance)
        drawdown = c.flexibleDouble(.drawdown)
        equity = c.flexibleDouble(.equity)
        demo = (try? c.decode(Bool.self, forKey: .demo)) ?? false
        lastUpdateDate = c.string(.lastUpdateDate)
        firstTradeDate = c.string(.firstTradeDate)
        commission = c.flexibleDouble(.commission)
        currency = c.string(.currency, fallback: "EUR")
        profitFactor = c.flexibleDouble(.profitFactor)
        pips = c.flexibleDouble(.pips)
        server = (try? c.decode(ServerDTO.self, forKey: .server)) ?? ServerDTO(name: "MetaTrader 5")
    }

    var domain: TradingAccount {
        TradingAccount(
            id: id,
            accountNumber: accountID,
            name: name,
            broker: server.name,
            currency: currency,
            balance: balance,
            equity: equity,
            profit: profit,
            gain: gain,
            dailyGain: daily,
            monthlyGain: monthly,
            drawdown: drawdown,
            deposits: deposits,
            withdrawals: withdrawals,
            commission: commission,
            pips: pips,
            profitFactor: profitFactor,
            isDemo: demo,
            lastUpdate: MyfxbookDateParser.parse(lastUpdateDate),
            firstTradeDate: MyfxbookDateParser.parse(firstTradeDate)
        )
    }
}

private struct SizingDTO: Decodable {
    let type: String
    let value: Double

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.string(.type, fallback: "lots")
        value = c.flexibleDouble(.value)
    }
}

private struct OpenTradeDTO: Decodable {
    let openTime: String
    let symbol: String
    let action: String
    let sizing: SizingDTO
    let openPrice: Double
    let tp: Double
    let sl: Double
    let comment: String
    let profit: Double
    let pips: Double
    let swap: Double
    let magic: Int?

    enum CodingKeys: String, CodingKey {
        case openTime, openDate, symbol, action, sizing, openPrice, tp, sl, comment, profit, pips, swap, magic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openTime = c.string(.openTime, fallback: c.string(.openDate))
        symbol = c.string(.symbol)
        action = c.string(.action)
        sizing = (try? c.decode(SizingDTO.self, forKey: .sizing)) ?? SizingDTO(type: "lots", value: 0)
        openPrice = c.flexibleDouble(.openPrice)
        tp = c.flexibleDouble(.tp)
        sl = c.flexibleDouble(.sl)
        comment = c.string(.comment)
        profit = c.flexibleDouble(.profit)
        pips = c.flexibleDouble(.pips)
        swap = c.flexibleDouble(.swap)
        magic = c.optionalFlexibleInt(.magic)
    }

    func domain(index: Int) -> OpenPosition {
        OpenPosition(
            id: "\(symbol)-\(openTime)-\(index)", openDate: MyfxbookDateParser.parse(openTime), symbol: symbol,
            action: action, size: sizing.value, sizeType: sizing.type, openPrice: openPrice,
            takeProfit: tp, stopLoss: sl, profit: profit, pips: pips, swap: swap, comment: comment, magic: magic
        )
    }
}

private struct OpenOrderDTO: Decodable {
    let openTime: String
    let symbol: String
    let action: String
    let sizing: SizingDTO
    let openPrice: Double
    let tp: Double
    let sl: Double
    let comment: String

    enum CodingKeys: String, CodingKey {
        case openTime, openDate, symbol, action, sizing, openPrice, tp, sl, comment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openTime = c.string(.openTime, fallback: c.string(.openDate))
        symbol = c.string(.symbol)
        action = c.string(.action)
        sizing = (try? c.decode(SizingDTO.self, forKey: .sizing)) ?? SizingDTO(type: "lots", value: 0)
        openPrice = c.flexibleDouble(.openPrice)
        tp = c.flexibleDouble(.tp)
        sl = c.flexibleDouble(.sl)
        comment = c.string(.comment)
    }

    func domain(index: Int) -> PendingOrder {
        PendingOrder(
            id: "\(symbol)-\(openTime)-\(index)", openDate: MyfxbookDateParser.parse(openTime), symbol: symbol,
            action: action, size: sizing.value, sizeType: sizing.type, openPrice: openPrice,
            takeProfit: tp, stopLoss: sl, comment: comment
        )
    }
}

private struct HistoryDTO: Decodable {
    let openTime: String
    let closeTime: String
    let symbol: String
    let action: String
    let sizing: SizingDTO
    let openPrice: Double
    let closePrice: Double
    let tp: Double
    let sl: Double
    let comment: String
    let pips: Double
    let profit: Double
    let interest: Double
    let commission: Double

    enum CodingKeys: String, CodingKey {
        case openTime, openDate, closeTime, closeDate, symbol, action, sizing, openPrice, closePrice
        case tp, sl, comment, pips, profit, interest, commission
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openTime = c.string(.openTime, fallback: c.string(.openDate))
        closeTime = c.string(.closeTime, fallback: c.string(.closeDate))
        symbol = c.string(.symbol)
        action = c.string(.action)
        sizing = (try? c.decode(SizingDTO.self, forKey: .sizing)) ?? SizingDTO(type: "lots", value: 0)
        openPrice = c.flexibleDouble(.openPrice)
        closePrice = c.flexibleDouble(.closePrice)
        tp = c.flexibleDouble(.tp)
        sl = c.flexibleDouble(.sl)
        comment = c.string(.comment)
        pips = c.flexibleDouble(.pips)
        profit = c.flexibleDouble(.profit)
        interest = c.flexibleDouble(.interest)
        commission = c.flexibleDouble(.commission)
    }

    func domain(index: Int) -> TradeTransaction {
        TradeTransaction(
            id: "\(symbol)-\(closeTime)-\(index)", openDate: MyfxbookDateParser.parse(openTime),
            closeDate: MyfxbookDateParser.parse(closeTime), symbol: symbol, action: action,
            size: sizing.value, sizeType: sizing.type, openPrice: openPrice, closePrice: closePrice,
            takeProfit: tp, stopLoss: sl, pips: pips, profit: profit, interest: interest,
            commission: commission, comment: comment
        )
    }
}

private struct DailyDTO: Decodable {
    let date: String
    let balance: Double
    let pips: Double
    let lots: Double
    let floatingPL: Double
    let profit: Double
    let growthEquity: Double

    enum CodingKeys: String, CodingKey { case date, balance, pips, lots, floatingPL, profit, growthEquity }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.string(.date)
        balance = c.flexibleDouble(.balance)
        pips = c.flexibleDouble(.pips)
        lots = c.flexibleDouble(.lots)
        floatingPL = c.flexibleDouble(.floatingPL)
        profit = c.flexibleDouble(.profit)
        growthEquity = c.flexibleDouble(.growthEquity)
    }

    var domain: DailyPoint? {
        guard let date = MyfxbookDateParser.parse(date) else { return nil }
        return DailyPoint(
            date: date, balance: balance, pips: pips, lots: lots,
            floatingProfit: floatingPL, profit: profit, growthEquity: growthEquity
        )
    }
}

private extension KeyedDecodingContainer {
    func string(_ key: Key, fallback: String = "") -> String {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        return fallback
    }

    func flexibleDouble(_ key: Key) -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: ",", with: "")) ?? 0
        }
        return 0
    }

    func flexibleInt(_ key: Key) -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Int(value) ?? 0 }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        return 0
    }

    func optionalFlexibleInt(_ key: Key) -> Int? {
        guard contains(key) else { return nil }
        return flexibleInt(key)
    }
}

private extension SizingDTO {
    init(type: String, value: Double) {
        self.type = type
        self.value = value
    }
}
