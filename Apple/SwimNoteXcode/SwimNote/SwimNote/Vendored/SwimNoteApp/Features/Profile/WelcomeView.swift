import SwiftUI

struct WelcomeView: View {
    var appModel: SwimNoteAppModel
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo/Header
            VStack(spacing: 16) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 80))
                    .foregroundStyle(PoolTheme.deep)

                Text("SwimNote")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)

                Text("Track your training. Improve your technique.")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.mid)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Action button
            VStack(spacing: 16) {
                Button {
                    profileStore.showingUserSetup = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [PoolTheme.surface, PoolTheme.light.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Previews

#Preview("Welcome View") {
    let model = SwimNoteAppModel.bootstrap()
    WelcomeView(appModel: model)
        .environment(model.profileStore)
}

#Preview("Welcome View - Dark Mode") {
    let model = SwimNoteAppModel.bootstrap()
    WelcomeView(appModel: model)
        .environment(model.profileStore)
        .preferredColorScheme(.dark)
}