import SwiftUI

public struct RootView: View {
    @Bindable var appModel: SwimNoteAppModel

    public init(appModel: SwimNoteAppModel) {
        self.appModel = appModel
    }

    public var body: some View {
        Group {
            if !appModel.isInitialized {
                // Show loading state while Core Data initializes
                ProgressView("Loading...")
                    .tint(PoolTheme.mid)
            } else if appModel.activeProfile != nil {
                mainTabs
            } else if appModel.needsSetup && appModel.showingUserSetup {
                UserSetupView(appModel: appModel)
            } else if appModel.needsSetup {
                WelcomeView(appModel: appModel)
            } else {
                UserSelectionView(appModel: appModel)
            }
        }
        .tint(PoolTheme.mid)
    }

    private var mainTabs: some View {
        TabView(selection: $appModel.selectedTab) {
            DashboardView(appModel: appModel)
                .tabItem { Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.symbol) }
                .tag(AppTab.dashboard)

            CalendarView(appModel: appModel)
                .tabItem { Label(AppTab.calendar.rawValue, systemImage: AppTab.calendar.symbol) }
                .tag(AppTab.calendar)

            ToolsView(appModel: appModel)
                .tabItem { Label(AppTab.tools.rawValue, systemImage: AppTab.tools.symbol) }
                .tag(AppTab.tools)

            PlanningView(appModel: appModel)
                .tabItem { Label(AppTab.plan.rawValue, systemImage: AppTab.plan.symbol) }
                .tag(AppTab.plan)

            SettingsView(appModel: appModel)
                .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Previews

@MainActor
private func previewRootWithActiveProfile() -> some View {
    let model = SwimNoteAppModel.bootstrap()
    let profile = UserProfile(
        id: "preview-user",
        name: "Alex Swimmer",
        birthday: "1995-06-15",
        sex: .male,
        skillLevel: .intermediate,
        weeklySessionTarget: 3,
        preferredStrokes: [.freestyle],
        mainStroke: .freestyle,
        distancePreference: .mid,
        personalBests: PersonalBests(freestyle50m: 32.5),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    model.profileStore.profiles = [profile]
    model.profileStore.activeProfile = profile
    model.profileStore.needsSetup = false
    model.loadBundledContent()
    return RootView(appModel: model)
        .environment(model.profileStore)
        .environment(model.contentStore)
}

@MainActor
private func previewRootWelcome() -> some View {
    let model = SwimNoteAppModel.bootstrap()
    model.profileStore.needsSetup = true
    model.profileStore.profiles = []
    return RootView(appModel: model)
        .environment(model.profileStore)
        .environment(model.contentStore)
}

@MainActor
private func previewRootUserSelection() -> some View {
    let model = SwimNoteAppModel.bootstrap()
    model.profileStore.needsSetup = false
    model.profileStore.profiles = [
        UserProfile(
            id: "user-1",
            name: "Alex",
            birthday: "1995-06-15",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
            mainStroke: .freestyle,
            distancePreference: .mid,
            personalBests: PersonalBests(freestyle50m: 32.5),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        ),
        UserProfile(
            id: "user-2",
            name: "Maya",
            birthday: "2000-03-20",
            sex: .female,
            skillLevel: .beginner,
            weeklySessionTarget: 2,
            preferredStrokes: [.backstroke],
            distancePreference: .na,
            personalBests: .empty(),
            trainingGoals: [],
            createdAt: "2024-02-01T00:00:00Z",
            updatedAt: "2024-02-01T00:00:00Z"
        )
    ]
    return RootView(appModel: model)
        .environment(model.profileStore)
        .environment(model.contentStore)
}

#Preview("Root - With Active Profile") {
    previewRootWithActiveProfile()
}

#Preview("Root - Welcome Screen") {
    previewRootWelcome()
}

#Preview("Root - User Selection") {
    previewRootUserSelection()
}