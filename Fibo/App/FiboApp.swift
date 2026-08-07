import SwiftUI

@main
struct FiboApp: App {
    @StateObject private var store = DashboardStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await store.refresh()
            BackgroundRefresh.schedule()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}
