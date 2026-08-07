import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            Group {
                if store.isAuthenticated {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isAuthenticated)

            if isShowingSplash {
                SplashView(isReady: isBootstrapFinished) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        isShowingSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task { await store.bootstrap() }
    }

    /// Le splash se retire dès que le premier chargement est terminé
    /// (données affichables, erreur, ou utilisateur non connecté).
    private var isBootstrapFinished: Bool {
        switch store.state {
        case .loading, .connecting:
            return store.hasContent
        case .ready, .refreshing, .failed, .signedOut:
            return true
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var selection = Self.initialSelection

    private static var initialSelection: Int {
        if ProcessInfo.processInfo.arguments.contains("--activity") { return 1 }
        if ProcessInfo.processInfo.arguments.contains("--projection") { return 2 }
        return 0
    }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                DashboardView()
                    .tag(0)
                    .tabItem { Label("Accueil", systemImage: "house.fill") }

                TradingActivityView()
                    .tag(1)
                    .tabItem { Label("Activité", systemImage: "arrow.up.arrow.down.circle.fill") }

                ProjectionView()
                    .tag(2)
                    .tabItem { Label("Projection", systemImage: "function") }

                SettingsView()
                    .tag(3)
                    .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
            }
            .tint(AppTheme.primary)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            if store.state == .loading && !store.hasContent {
                AppTheme.background.ignoresSafeArea()
                LoadingOverlay(title: "Synchronisation du portefeuille…")
            }
        }
    }
}
