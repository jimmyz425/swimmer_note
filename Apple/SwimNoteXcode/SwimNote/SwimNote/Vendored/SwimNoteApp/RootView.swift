import SwiftUI

public struct RootView: View {
    @Bindable var appModel: SwimNoteAppModel

    public init(appModel: SwimNoteAppModel) {
        self.appModel = appModel
    }

    public var body: some View {
        Group {
            if appModel.activeProfile != nil {
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
        .task {
            await appModel.loadProfiles()
        }
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

#Preview("Root - With Active Profile") {
    let model = SwimNoteAppModel.bootstrap()
    model.activeProfile = UserProfile(
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
    model.needsSetup = false
    model.loadBundledContent()
    return RootView(appModel: model)
}

#Preview("Root - Welcome Screen") {
    let model = SwimNoteAppModel.bootstrap()
    model.needsSetup = true
    model.profiles = []
    return RootView(appModel: model)
}

#Preview("Root - User Selection") {
    let model = SwimNoteAppModel.bootstrap()
    model.needsSetup = false
    model.profiles = [
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
}