import SwiftUI

struct CalendarView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    @State private var showingProfileMenu = false
    @State private var showingUserSelection = false
    @State private var showingEditProfile = false
    @State private var selectedSession: DetailedSession?
    @State private var expandedSession: Bool = true

    private let calendar = Calendar.current

    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        var days: [Date] = []
        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return days
    }

    private var firstWeekdayOffset: Int {
        guard let firstDay = daysInMonth.first else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private var monthTitle: String {
        DateFormatter.monthTitle.string(from: displayedMonth)
    }

    private func dateString(from date: Date) -> String {
        DateFormatter.yyyyMMdd.string(from: date)
    }

    private func noteForDate(_ date: Date) -> TrainingNote? {
        let dateString = dateString(from: date)
        return appModel.notes.first { $0.date == dateString }
    }

    private func sessionsForDate(_ date: Date) -> [DetailedSession] {
        let dateString = dateString(from: date)
        // Use cached lookup from appModel
        return appModel.sessionsForDate(dateString)
    }

    private func dryLandForDate(_ date: Date) -> [DryLandExercisePlan] {
        let dateString = dateString(from: date)
        var exercises: [DryLandExercisePlan] = []
        for plan in appModel.weeklyPlans {
            if let dryLand = plan.dryLandProgram {
                for exercise in dryLand {
                    if let scheduledDate = exercise.scheduledDate {
                        let exerciseDateStr = DateFormatter.yyyyMMdd.string(from: scheduledDate)
                        if exerciseDateStr == dateString {
                            exercises.append(exercise)
                        }
                    }
                }
            }
        }
        return exercises
    }

    private func weeklyPlanForSession(_ session: DetailedSession) -> WeeklyTrainingPlan? {
        // Find the plan containing this session
        for plan in appModel.weeklyPlans {
            if plan.detailedSessions.contains(where: { $0.id == session.id }) {
                return plan
            }
        }
        return nil
    }

    private func hasContentForDate(_ date: Date) -> Bool {
        let note = noteForDate(date)
        let sessions = sessionsForDate(date)
        let dryLand = dryLandForDate(date)
        return (note != nil && (!note!.goals.isEmpty || !note!.notes.isEmpty)) || !sessions.isEmpty || !dryLand.isEmpty
    }

    private func hasSessionForDate(_ date: Date) -> Bool {
        return !sessionsForDate(date).isEmpty
    }

    private func hasDryLandForDate(_ date: Date) -> Bool {
        return !dryLandForDate(date).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    monthNavigationSection

                    calendarGridSection

                    selectedDaySection
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .task {
                if let userId = appModel.activeProfile?.id {
                    await appModel.reloadNotes(userId: userId)
                }
            }
            .onChange(of: appModel.activeProfile?.id) { _, newUserId in
                if let userId = newUserId {
                    Task {
                        await appModel.reloadNotes(userId: userId)
                    }
                }
                // Reset profile-specific UI state
                selectedSession = nil
                expandedSession = true
            }
            .onChange(of: appModel.weeklyPlans.count) { _, _ in
                // Refresh when plans are saved/loaded
                Task {
                    if let userId = appModel.activeProfile?.id {
                        await appModel.reloadNotes(userId: userId)
                    }
                }
            }
            .sheet(isPresented: $showingUserSelection) {
                UserSelectionView(appModel: appModel)
            }
            .sheet(isPresented: $showingEditProfile) {
                if let profile = appModel.activeProfile {
                    PersonalBestsEditor(appModel: appModel, profile: profile)
                }
            }
            .sheet(item: $selectedSession) { session in
                if let plan = weeklyPlanForSession(session) {
                    NavigationStack {
                        SessionDetailView(session: session, plan: plan, appModel: appModel)
                    }
                    .presentationDetents([.large])
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TRAINING CALENDAR")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)
                Text("Plan and track your sessions")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.mid)
            }

            Spacer()

            if let profile = appModel.activeProfile {
                Button {
                    showingProfileMenu = true
                } label: {
                    ProfileIconView(profile: profile, size: 40)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Profile Options", isPresented: $showingProfileMenu) {
                    Button("Switch User") { showingUserSelection = true }
                    Button("Edit Profile") { showingEditProfile = true }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
    }

    private var monthNavigationSection: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(PoolTheme.deep)
            }

            Spacer()

            Text(monthTitle)
                .font(.title2.bold())
                .foregroundStyle(PoolTheme.deep)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(PoolTheme.deep)
            }
        }
        .poolCard()
    }

    private var calendarGridSection: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.mid)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Leading spacers to align day 1 under the correct weekday
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }

                ForEach(daysInMonth, id: \.self) { day in
                    DayCell(
                        date: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        hasContent: hasContentForDate(day),
                        hasSession: hasSessionForDate(day),
                        hasDryLand: hasDryLandForDate(day),
                        isToday: calendar.isDateInToday(day),
                        onTap: { selectedDate = day }
                    )
                }
            }
        }
        .poolCard()
    }

    private var selectedDayTitle: String {
        DateFormatter.fullDate.string(from: selectedDate)
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedDayTitle)
                .font(.title3.bold())
                .foregroundStyle(PoolTheme.deep)

            // Training Sessions Section (supports multiple sessions per day)
            let sessions = sessionsForDate(selectedDate)
            if !sessions.isEmpty {
                ForEach(sessions) { session in
                    sessionCard(session)
                }
            } else {
                noPlanSection
            }

            // Dry Land Section
            let dryLandExercises = dryLandForDate(selectedDate)
            if !dryLandExercises.isEmpty {
                dryLandSection(dryLandExercises)
            }

            // Goals from note
            if let note = noteForDate(selectedDate) {
                goalsSection(note)
            } else {
                noGoalsSection
            }
        }
        .poolCard()
    }

    // MARK: - Dry Land Section

    private func dryLandSection(_ exercises: [DryLandExercisePlan]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.orange)
                Text("Dry Land Training")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
            }

            ForEach(exercises) { exercise in
                DryLandExerciseRow(exercise: exercise)
            }
        }
    }

    // MARK: - Session Card (using shared SessionCard component)

    private func sessionCard(_ session: DetailedSession) -> some View {
        SessionCard(
            session: session,
            isExpanded: expandedSession,
            onToggleExpand: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedSession.toggle()
                }
            },
            onDateChange: nil,
            showDatePicker: false  // Calendar already shows the date
        )
    }

    private var noPlanSection: some View {
        Button {
            appModel.selectedTab = .plan
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(PoolTheme.light)

                    Text("No training plan for this day")
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(PoolTheme.light)
                }

                Text("Generate a plan in the Plan tab")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .poolCard()
        }
        .buttonStyle(.plain)
    }

    private func goalsSection(_ note: TrainingNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(PoolTheme.mid)
                Text("Goals")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
            }

            if note.goals.isEmpty {
                Text("No goals set for this day")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(note.goals) { goal in
                    HStack(spacing: 12) {
                        GoalStatusBadge(status: goal.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.description)
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.deep)
                            if let strokeId = goal.strokeId {
                                Text(strokeId.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(PoolTheme.mid)
                            }
                        }
                    }
                }
            }
        }
    }

    private var noGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(PoolTheme.light)
                Text("Goals")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.smoke)
            }

            Text("No goals recorded for this day")
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PoolTheme.light.opacity(0.1))
        .cornerRadius(8)
    }
}


// MARK: - Previews

@MainActor
private func previewCalendarWithData() -> some View {
    let model = SwimNoteAppModel.bootstrap()
    let profile = UserProfile(
        id: "preview-user",
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
    )
    model.profileStore.activeProfile = profile

    let today = SwimNoteDateFormatting.todayShort()
    model.notes = [
        TrainingNote(
            userId: "preview-user",
            date: today,
            strokeFocus: [.freestyle],
            techniqueFocus: [],
            goals: [
                Goal(id: "g1", type: .technique, strokeId: .freestyle, description: "High elbow catch", status: .achieved, createdAt: "\(today)T00:00:00Z", updatedAt: "\(today)T00:00:00Z")
            ],
            notes: "Great session",
            createdAt: "\(today)T00:00:00Z",
            updatedAt: "\(today)T00:00:00Z"
        )
    ]

    let session = DetailedSession(
        id: "session-1",
        sessionNumber: 1,
        focus: "Freestyle Sprint Focus",
        warmUp: SessionSegment(distance: "400m", description: "Easy swim, progressive build"),
        drillSet: SessionSegment(distance: "200m", description: "6-1-6 drill", drills: ["6-1-6", "Catch-up"]),
        mainSet: SessionSegment(distance: "800m", description: "4x200m @ 85% effort"),
        coolDown: SessionSegment(distance: "200m", description: "Easy swim"),
        techniqueFocus: "High elbow catch and body rotation",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: nil,
        progressionRationale: nil,
        scheduledDate: Date()
    )
    model.weeklyPlans = [
        WeeklyTrainingPlan(
            overview: PlanOverview(
                weekFocus: "Freestyle focus week",
                pastMonthAnalysis: nil,
                technicalObjective: nil,
                physicalObjective: nil,
                strokeRotationPlan: nil,
                fundamentalRevisitPlan: nil
            ),
            schedule: [],
            detailedSessions: [session],
            dryLandProgram: nil,
            weeklyGoals: nil,
            techniqueProgressPlan: nil,
            notes: ""
        )
    ]

    return CalendarView(appModel: model)
}

@MainActor
private func previewCalendarEmpty() -> some View {
    let model = SwimNoteAppModel.bootstrap()
    let profile = UserProfile(
        id: "preview-user",
        name: "New Swimmer",
        birthday: "2000-01-01",
        sex: .female,
        skillLevel: .beginner,
        weeklySessionTarget: 2,
        preferredStrokes: [],
        personalBests: .empty(),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    model.profileStore.activeProfile = profile
    model.notes = []
    model.weeklyPlans = []
    return CalendarView(appModel: model)
}

#Preview("Calendar - With Data") {
    previewCalendarWithData()
}

#Preview("Calendar - Empty") {
    previewCalendarEmpty()
}


// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: DetailedSession
    let plan: WeeklyTrainingPlan
    let appModel: SwimNoteAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Segments
                segmentsSection

                // Technique Focus
                techniqueSection

                // Week Context
                weekContextSection
            }
            .padding()
        }
        .navigationTitle("Session \(session.sessionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Session Number Badge
            Text("\(session.sessionNumber)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(PoolTheme.mid)
                .cornerRadius(12)

            Text(session.focus)
                .font(.title2.bold())
                .foregroundStyle(PoolTheme.deep)

            if let goalRef = session.addressesGoal {
                Label("Addresses: \(goalRef)", systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
        .poolCard()
    }

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            segmentDetailRow("Warm-up", session.warmUp, color: .green.opacity(0.8))
            segmentDetailRow("Drill Set", session.drillSet, color: PoolTheme.mid)
            segmentDetailRow("Main Set", session.mainSet, color: .orange.opacity(0.8))
            segmentDetailRow("Cool-down", session.coolDown, color: .blue.opacity(0.6))
        }
        .poolCard()
    }

    private func segmentDetailRow(_ label: String, _ segment: SessionSegment, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(segment.distance)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color)
                    .cornerRadius(8)

                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(PoolTheme.deep)
            }

            Text(segment.description)
                .font(.body)
                .foregroundStyle(PoolTheme.deep)

            if let drills = segment.drills, !drills.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drills:")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    ForEach(drills, id: \.self) { drill in
                        Text("• \(drill)")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.mid)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var techniqueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Technique Focus", systemImage: "lightbulb")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            Text(session.techniqueFocus)
                .font(.body)
                .foregroundStyle(PoolTheme.deep)

            if let rationale = session.progressionRationale {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rationale")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(rationale)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.mid)
                }
            }
        }
        .poolCard()
    }

    private var weekContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Week Context", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            Text(plan.overview.weekFocus)
                .font(.subheadline)
                .foregroundStyle(PoolTheme.mid)

            if let technical = plan.overview.technicalObjective {
                Label("Technical: \(technical)", systemImage: "figure.pool.swim")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }

            if let physical = plan.overview.physicalObjective {
                Label("Physical: \(physical)", systemImage: "flame")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
        .poolCard()
    }
}