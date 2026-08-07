import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DashboardStore

    var body: some View {
        Group {
            if store.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isAuthenticated)
        .task { await store.bootstrap() }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: DashboardStore
    @State private var selection = 0

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                DashboardView()
                    .tag(0)
                    .tabItem { Label("Accueil", systemImage: "house.fill") }

                PositionsView()
                    .tag(1)
                    .tabItem { Label("Positions", systemImage: "arrow.up.arrow.down") }

                ActivityView()
                    .tag(2)
                    .tabItem { Label("Historique", systemImage: "clock.fill") }

                SettingsView()
                    .tag(3)
                    .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
            }
            .tint(AppTheme.blue)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            if store.state == .loading && !store.hasContent {
                AppTheme.background.ignoresSafeArea()
                LoadingOverlay(title: "Synchronisation du portefeuille…")
            }
        }
    }
}
