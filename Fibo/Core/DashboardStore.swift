import Foundation
import SwiftUI

@MainActor
final class DashboardStore: ObservableObject {
    enum State: Equatable {
        case signedOut
        case connecting
        case loading
        case ready
        case refreshing
        case failed
    }

    @Published private(set) var state: State
    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var accounts: [TradingAccount] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isShowingCachedData = false
    @Published private(set) var portfolioContributions: [PortfolioContribution] = []

    private let api: MyfxbookAPI
    private let keychain: KeychainStore
    private let cache: SnapshotCache
    private let defaults: UserDefaults
    private let preferredAccountKey = "preferredMyfxbookAccountID"
    private let portfolioContributionsKeyPrefix = "portfolioContributions"
    private let portfolioAllocationBasisKeyPrefix = "portfolioAllocationBasis"
    private let previewMode: Bool
    private let loginPreviewMode: Bool

    init(
        api: MyfxbookAPI = MyfxbookAPI(),
        keychain: KeychainStore = KeychainStore(),
        cache: SnapshotCache = SnapshotCache(),
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.keychain = keychain
        self.cache = cache
        self.defaults = defaults
        previewMode = ProcessInfo.processInfo.arguments.contains("--demo")
        loginPreviewMode = ProcessInfo.processInfo.arguments.contains("--login-preview")
        let cached: DashboardSnapshot? = loginPreviewMode ? nil : (previewMode ? PreviewData.snapshot : cache.load())
        snapshot = cached
        portfolioContributions = cached.map {
            Self.loadOrCreatePortfolioContributions(
                from: $0,
                defaults: defaults,
                contributionsKeyPrefix: "portfolioContributions",
                legacyBasisKeyPrefix: "portfolioAllocationBasis"
            )
        } ?? []
        state = loginPreviewMode
            ? .signedOut
            : (previewMode ? .ready : (keychain.loadCredentials() == nil ? .signedOut : (cached == nil ? .loading : .ready)))
        isShowingCachedData = !previewMode && !loginPreviewMode && cached != nil
    }

    var isAuthenticated: Bool { !loginPreviewMode && (previewMode || keychain.loadCredentials() != nil) }
    var hasContent: Bool { snapshot != nil }
    var account: TradingAccount? { snapshot?.account }

    func bootstrap() async {
        if loginPreviewMode {
            state = .signedOut
            return
        }
        if previewMode { return }
        guard isAuthenticated else {
            state = .signedOut
            return
        }
        await refresh(showLoadingState: snapshot == nil)
    }

    func connect(email: String, password: String) async -> Bool {
        errorMessage = nil
        state = .connecting
        do {
            let sessionID = try await api.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            try keychain.saveCredentials(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            try keychain.saveSession(sessionID)
            do {
                try await loadRemoteData(sessionID: sessionID)
            } catch MyfxbookError.authenticationRequired {
                let renewedSession = try await api.login(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                try keychain.saveSession(renewedSession)
                try await loadRemoteData(sessionID: renewedSession)
            }
            return true
        } catch {
            keychain.clearAll()
            errorMessage = userFacing(error)
            state = .signedOut
            return false
        }
    }

    func refresh(showLoadingState: Bool = false) async {
        if previewMode { return }
        guard let credentials = keychain.loadCredentials() else {
            state = .signedOut
            return
        }

        errorMessage = nil
        state = showLoadingState ? .loading : .refreshing

        do {
            var sessionID = keychain.loadSession()
            if sessionID == nil {
                sessionID = try await api.login(email: credentials.email, password: credentials.password)
                try keychain.saveSession(sessionID!)
            }

            do {
                try await loadRemoteData(sessionID: sessionID!)
            } catch MyfxbookError.authenticationRequired {
                let renewedSession = try await api.login(email: credentials.email, password: credentials.password)
                try keychain.saveSession(renewedSession)
                try await loadRemoteData(sessionID: renewedSession)
            }
        } catch {
            errorMessage = userFacing(error)
            isShowingCachedData = snapshot != nil
            state = snapshot == nil ? .failed : .ready
        }
    }

    func selectAccount(_ accountID: Int) async {
        defaults.set(accountID, forKey: preferredAccountKey)
        await refresh(showLoadingState: true)
    }

    func disconnect() async {
        if let sessionID = keychain.loadSession() {
            await api.logout(sessionID: sessionID)
        }
        keychain.clearAll()
        cache.clear()
        defaults.removeObject(forKey: preferredAccountKey)
        let accountIDs = Set(accounts.map(\.id) + [snapshot?.account.id].compactMap { $0 })
        for accountID in accountIDs {
            defaults.removeObject(forKey: portfolioContributionsKey(for: accountID))
            defaults.removeObject(forKey: portfolioAllocationBasisKey(for: accountID))
        }
        accounts = []
        snapshot = nil
        portfolioContributions = []
        errorMessage = nil
        isShowingCachedData = false
        state = .signedOut
    }

    func dismissError() {
        errorMessage = nil
    }

    func addPortfolioContribution(owner: PortfolioOwner, amount: Double, date: Date) {
        guard amount > 0, let snapshot else { return }
        portfolioContributions.append(
            PortfolioContribution(
                owner: owner,
                amount: amount,
                date: Calendar.current.startOfDay(for: date)
            )
        )
        persistPortfolioContributions(accountID: snapshot.account.id)
    }

    func updatePortfolioContribution(id: UUID, owner: PortfolioOwner, amount: Double, date: Date) {
        guard amount > 0,
              let snapshot,
              let index = portfolioContributions.firstIndex(where: { $0.id == id }) else { return }
        let existing = portfolioContributions[index]
        let normalizedDate = Calendar.current.startOfDay(for: date)
        portfolioContributions[index] = PortfolioContribution(
            id: existing.id,
            owner: owner,
            amount: amount,
            date: normalizedDate,
            profitBeforeContributionOnDate: Calendar.current.isDate(existing.date, inSameDayAs: normalizedDate)
                ? existing.profitBeforeContributionOnDate
                : nil,
            personalBalanceBeforeContribution: existing.owner == owner
                && existing.amount == amount
                && Calendar.current.isDate(existing.date, inSameDayAs: normalizedDate)
                ? existing.personalBalanceBeforeContribution
                : nil
        )
        persistPortfolioContributions(accountID: snapshot.account.id)
    }

    func deletePortfolioContribution(id: UUID) {
        guard let snapshot else { return }
        portfolioContributions.removeAll { $0.id == id }
        persistPortfolioContributions(accountID: snapshot.account.id)
    }

    private func loadRemoteData(sessionID: String) async throws {
        let remoteAccounts = try await api.accounts(sessionID: sessionID)
        guard !remoteAccounts.isEmpty else { throw MyfxbookError.accountNotFound }
        accounts = remoteAccounts

        let preferredID = defaults.integer(forKey: preferredAccountKey)
        let selected = remoteAccounts.first(where: { $0.id == preferredID })
            ?? remoteAccounts[0]
        defaults.set(selected.id, forKey: preferredAccountKey)

        let calendar = Calendar(identifier: .gregorian)
        let start = selected.firstTradeDate
            ?? calendar.date(byAdding: .year, value: -5, to: Date())
            ?? Date(timeIntervalSince1970: 0)

        async let positions = api.openPositions(sessionID: sessionID, accountID: selected.id)
        async let orders = api.pendingOrders(sessionID: sessionID, accountID: selected.id)
        async let history = api.history(sessionID: sessionID, accountID: selected.id)
        async let daily = api.dailyData(sessionID: sessionID, accountID: selected.id, start: start, end: Date())

        let loadedPositions = try await positions
        let loadedOrders = try await orders
        let loadedHistory = try await history
        let loadedDaily = try await daily
        let fetchedAt = Date()
        let newSnapshot = DashboardSnapshot(
            fetchedAt: fetchedAt,
            account: selected,
            positions: loadedPositions,
            orders: loadedOrders,
            history: loadedHistory,
            daily: loadedDaily
        )
        portfolioContributions = Self.loadOrCreatePortfolioContributions(
            from: newSnapshot,
            defaults: defaults,
            contributionsKeyPrefix: portfolioContributionsKeyPrefix,
            legacyBasisKeyPrefix: portfolioAllocationBasisKeyPrefix
        )
        snapshot = newSnapshot
        cache.save(newSnapshot)
        isShowingCachedData = false
        errorMessage = nil
        state = .ready
    }

    private func persistPortfolioContributions(accountID: Int) {
        guard let data = try? JSONEncoder().encode(portfolioContributions) else { return }
        defaults.set(data, forKey: portfolioContributionsKey(for: accountID))
    }

    private func portfolioContributionsKey(for accountID: Int) -> String {
        "\(portfolioContributionsKeyPrefix).\(accountID)"
    }

    private func portfolioAllocationBasisKey(for accountID: Int) -> String {
        "\(portfolioAllocationBasisKeyPrefix).\(accountID)"
    }

    private static func loadPortfolioAllocationBasis(
        accountID: Int,
        defaults: UserDefaults,
        keyPrefix: String
    ) -> PortfolioAllocationBasis? {
        guard let data = defaults.data(forKey: "\(keyPrefix).\(accountID)") else { return nil }
        return try? JSONDecoder().decode(PortfolioAllocationBasis.self, from: data)
    }

    private static func loadOrCreatePortfolioContributions(
        from snapshot: DashboardSnapshot,
        defaults: UserDefaults,
        contributionsKeyPrefix: String,
        legacyBasisKeyPrefix: String
    ) -> [PortfolioContribution] {
        let key = "\(contributionsKeyPrefix).\(snapshot.account.id)"
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([PortfolioContribution].self, from: data) {
            return saved
        }

        let legacyBasis = loadPortfolioAllocationBasis(
            accountID: snapshot.account.id,
            defaults: defaults,
            keyPrefix: legacyBasisKeyPrefix
        )
        let fatherEntryDate = legacyBasis?.fatherEntryDate ?? snapshot.fetchedAt
        let dailyProfitAtFatherEntry = legacyBasis?.dailyProfitAtFatherEntry
            ?? snapshot.daily.last {
                Calendar.current.isDate($0.date, inSameDayAs: fatherEntryDate)
            }?.profit
            ?? 0
        let personalEntryDate = snapshot.account.firstTradeDate
            ?? snapshot.daily.first?.date
            ?? snapshot.fetchedAt
        let contributions = [
            PortfolioContribution(
                owner: .personal,
                amount: PortfolioAllocationBasis.personalInitialCapital,
                date: Calendar.current.startOfDay(for: personalEntryDate)
            ),
            PortfolioContribution(
                owner: .father,
                amount: PortfolioAllocationBasis.fatherInitialCapital,
                date: fatherEntryDate,
                profitBeforeContributionOnDate: dailyProfitAtFatherEntry,
                personalBalanceBeforeContribution: (
                    legacyBasis?.totalBalanceAtFatherEntry ?? snapshot.account.balance
                ) - PortfolioAllocationBasis.fatherInitialCapital
            )
        ]
        if let data = try? JSONEncoder().encode(contributions) {
            defaults.set(data, forKey: key)
        }
        return contributions
    }

    private func userFacing(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Connexion impossible. Les dernières données disponibles restent affichées."
        }
        return "Une erreur inattendue est survenue."
    }
}
