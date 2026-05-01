import SwiftUI

struct UserSelectionView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var showingAddProfile = false
    @State private var showingEditProfile: UserProfile?
    @State private var showingDeleteConfirm: UserProfile?

    var body: some View {
        NavigationStack {
            List {
                ForEach(appModel.profiles) { profile in
                    profileCard(profile)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            switchToProfile(profile)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                showingDeleteConfirm = profile
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                showingEditProfile = profile
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                }
            }
            .navigationTitle("Select User")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProfile) {
                UserSetupView(appModel: appModel)
            }
            .sheet(item: $showingEditProfile) { profile in
                PersonalBestsEditor(appModel: appModel, profile: profile)
            }
            .alert("Delete Profile?", isPresented: .init(
                get: { showingDeleteConfirm != nil },
                set: { if !$0 { showingDeleteConfirm = nil } }
            ), presenting: showingDeleteConfirm) { profile in
                Button("Cancel", role: .cancel) { showingDeleteConfirm = nil }
                Button("Delete", role: .destructive) {
                    deleteProfile(profile)
                }
            } message: { profile in
                Text("Delete \(profile.name)? Their training notes will be kept.")
            }
        }
    }

    private func profileCard(_ profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(profile.id == appModel.activeProfile?.id ? PoolTheme.deep : PoolTheme.mid)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(profile.name.prefix(1)))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(profile.age) yrs")
                    Text(profile.sex.rawValue.capitalized)
                    skillBadge(profile.skillLevel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if profile.id == appModel.activeProfile?.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PoolTheme.deep)
            }
        }
        .padding(.vertical, 4)
    }

    private func skillBadge(_ level: SkillLevel) -> some View {
        Text(level.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(skillColor(level))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private func skillColor(_ level: SkillLevel) -> Color {
        switch level {
        case .beginner: .gray
        case .intermediate: .blue
        case .advanced: .green
        case .competitive: .orange
        case .elite: .purple
        }
    }

    private func switchToProfile(_ profile: UserProfile) {
        Task { @MainActor in
            try? await appModel.switchProfile(to: profile)
        }
    }

    private func deleteProfile(_ profile: UserProfile) {
        Task { @MainActor in
            try? await appModel.deleteProfile(id: profile.id)
        }
        showingDeleteConfirm = nil
    }
}

// MARK: - Previews

#Preview("User Selection - Multiple Profiles") {
    let model = SwimNoteAppModel.bootstrap()
    model.profiles = [
        UserProfile(
            id: "user-1",
            name: "Alex",
            birthday: "1995-06-15",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
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
            personalBests: .empty(),
            trainingGoals: [],
            createdAt: "2024-02-01T00:00:00Z",
            updatedAt: "2024-02-01T00:00:00Z"
        ),
        UserProfile(
            id: "user-3",
            name: "Jordan",
            birthday: "1988-11-10",
            sex: .male,
            skillLevel: .elite,
            weeklySessionTarget: 5,
            preferredStrokes: [.butterfly],
            personalBests: PersonalBests(butterfly50m: 24.8),
            trainingGoals: [],
            createdAt: "2024-03-01T00:00:00Z",
            updatedAt: "2024-03-01T00:00:00Z"
        )
    ]
    model.activeProfile = model.profiles.first
    return UserSelectionView(appModel: model)
}

#Preview("User Selection - Single Profile") {
    let model = SwimNoteAppModel.bootstrap()
    model.profiles = [
        UserProfile(
            id: "user-1",
            name: "Solo Swimmer",
            birthday: "1990-01-01",
            sex: .male,
            skillLevel: .advanced,
            weeklySessionTarget: 4,
            preferredStrokes: [.freestyle, .backstroke],
            personalBests: PersonalBests(freestyle50m: 28.0, backstroke50m: 30.5),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    ]
    model.activeProfile = model.profiles.first
    return UserSelectionView(appModel: model)
}