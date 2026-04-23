import SwiftUI

/// Main native shell placeholder. Extend with your tabs and content in the host app.
/// Tab roots use a full-bleed SwiftUI background with safe-area-aware content.
struct MainTabView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @StateObject private var fallbackTimerSessionStore = InMemoryTimerSessionStore()

    var body: some View {
        let timerSessionStore = dependencyContainer?.timerSessionStore ?? fallbackTimerSessionStore
        ZStack {
            GameThemePalette.skyBackgroundGradient
                .ignoresSafeArea()
            TabView {
                NavigationStack {
                    TimerScreen(viewModel: TimerViewModel(timerSessionStore: timerSessionStore))
                }
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }

                NavigationStack {
                    HistoryScreen(viewModel: HistoryViewModel(timerSessionStore: timerSessionStore))
                }
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
            .tint(GameThemePalette.chickenGoldenYellow)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(GameThemePalette.chickenSkyTop.opacity(0.92), for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
