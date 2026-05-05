import SwiftUI

struct ToolsView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var showingProfileMenu = false
    @State private var showingUserSelection = false
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    toolCardsSection
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingUserSelection) {
                UserSelectionView(appModel: appModel)
            }
            .sheet(isPresented: $showingEditProfile) {
                if let profile = appModel.activeProfile {
                    PersonalBestsEditor(appModel: appModel, profile: profile)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TOOLS")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)
                Text("Video analysis & performance tracking")
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

    private var toolCardsSection: some View {
        VStack(spacing: 16) {
            // Video Review Card
            ToolCard(
                icon: "video.fill",
                iconColor: PoolTheme.mid,
                title: "Video Review",
                subtitle: "Import and analyze swim footage",
                badge: appModel.videoRecords.isEmpty ? nil : "\(appModel.videoRecords.count)"
            ) {
                VideoReviewView(appModel: appModel)
            }

            // Technique Measurements Card
            ToolCard(
                icon: "chart.bar.xaxis",
                iconColor: PoolTheme.mid,
                title: "Technique Measurements",
                subtitle: "Track stroke efficiency metrics",
                badge: appModel.measurements.isEmpty ? nil : "\(appModel.measurements.count)"
            ) {
                TechniqueMeasurementView(appModel: appModel)
            }

            // PB Tracker Card
            let pbCount = appModel.activeProfile?.pbHistory?.currentBests().count ?? 0
            ToolCard(
                icon: "medal",
                iconColor: PoolTheme.mid,
                title: "PB Tracker",
                subtitle: "Personal best progression",
                badge: pbCount > 0 ? "\(pbCount)" : nil
            ) {
                PBTrackerView(appModel: appModel)
            }

            // CSS Tools Card
            let hasCSS = appModel.activeProfile?.cssHistory?.latestTest != nil
            ToolCard(
                icon: "speedometer",
                iconColor: PoolTheme.mid,
                title: "CSS Tools",
                subtitle: "Critical Swim Speed analysis",
                badge: hasCSS ? "✓" : nil
            ) {
                CSSToolsView(appModel: appModel)
            }
        }
    }
}

// MARK: - Tool Card Component

struct ToolCard<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(PoolTheme.deep)

                        if let badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PoolTheme.mid)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PoolTheme.smoke)
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: PoolTheme.deep.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

private func makePreviewModel(withCSS: Bool = false, withRecords: Bool = false, withMeasurements: Bool = false) -> SwimNoteAppModel {
    let model = SwimNoteAppModel.bootstrap()
    model.activeProfile = UserProfile(
        id: "preview-user",
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
    )
    if withCSS {
        model.activeProfile?.cssHistory = CSSHistory(
            tests: [
                CSSTestResult(
                    date: "2024-04-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 135,
                    time400m: 285,
                    cssMetersPerSecond: 1.33,
                    cssPaceSecondsPer100m: 75.2
                )
            ]
        )
    }
    if withRecords {
        model.videoRecords = [
            VideoAnalysisRecord(
                id: "record-1",
                videoFilename: "freestyle_session_01.mov",
                strokeId: .freestyle,
                createdAt: "2024-01-15T10:00:00Z",
                metrics: PoseAnalysisMetrics(
                    strokeRatePerMinute: 30.0,
                    strokeRateHz: 0.5,
                    kickRatePerMinute: 45.0,
                    kickRateHz: 0.75,
                    kickRateConfidence: 0.8,
                    bodyAngleAverage: 15.0,
                    bodyAngleMin: 10.0,
                    bodyAngleMax: 20.0,
                    armEntryAngleAverage: 45.0,
                    elbowHeightAverage: 0.8
                ),
                frames: []
            )
        ]
    }
    if withMeasurements {
        model.measurements = [
            TechniqueMeasurement(
                userId: "preview-user",
                date: "2024-05-05",
                strokeId: .freestyle,
                poolLength: 25,
                distanceUnit: .meters,
                strokeCount: 18,
                lapTime: 22.5,
                effortZone: 3
            )
        ]
    }
    return model
}

#Preview("Tools - Empty") {
    ToolsView(appModel: makePreviewModel())
}

#Preview("Tools - With Data") {
    ToolsView(appModel: makePreviewModel(withCSS: true, withRecords: true, withMeasurements: true))
}