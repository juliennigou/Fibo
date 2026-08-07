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

    private let api: MyfxbookAPI
    private let keychain: KeychainStore
    private let cache: SnapshotCache
    private let defaults: UserDefaults
    private let preferredAccountKey = "preferredMyfxbookAccountID"
    private let previewMode: Bool

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
        let cached = previewMode ? PreviewData.snapshot : cache.load()
        snapshot = cached
        state = previewMode ? .ready : (keychain.loadCredentials() == nil ? .signedOut : (cached == nil ? .loading : .ready))
        isShowingCachedData = !previewMode && cached != nil
    }

    var isAuthenticated: Bool { previewMode || keychain.loadCredentials() != nil }
    var hasContent: Bool { snapshot != nil }
    var account: TradingAccount? { snapshot?.account }

    func bootstrap() async {
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
            try await loadRemoteData(sessionID: sessionID)
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
        accounts = []
        snapshot = nil
        errorMessage = nil
        isShowingCachedData = false
        state = .signedOut
    }

    func dismissError() {
        errorMessage = nil
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

        let newSnapshot = try await DashboardSnapshot(
            fetchedAt: Date(),
            account: selected,
            positions: positions,
            orders: orders,
            history: history,
            daily: daily
        )
        snapshot = newSnapshot
        cache.save(newSnapshot)
        isShowingCachedData = false
        errorMessage = nil
        state = .ready
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
