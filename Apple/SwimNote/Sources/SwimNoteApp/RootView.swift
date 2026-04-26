import SwiftUI
import SwimNoteCore

struct RootView: View {
    @Bindable var appModel: SwimNoteAppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            DashboardView(appModel: appModel)
                .tabItem { Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.symbol) }
                .tag(AppTab.dashboard)

            HistoryView(appModel: appModel)
                .tabItem { Label(AppTab.history.rawValue, systemImage: AppTab.history.symbol) }
                .tag(AppTab.history)

            TechniqueHomeView(appModel: appModel)
                .tabItem { Label(AppTab.trees.rawValue, systemImage: AppTab.trees.symbol) }
                .tag(AppTab.trees)

            VideoToolsView(appModel: appModel)
                .tabItem { Label(AppTab.video.rawValue, systemImage: AppTab.video.symbol) }
                .tag(AppTab.video)

            SettingsView(appModel: appModel)
                .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(PoolTheme.mid)
    }
}
