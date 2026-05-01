import SwiftUI

struct WelcomeView: View {
    @Bindable var appModel: SwimNoteAppModel

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
                    appModel.showingUserSetup = true
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
    WelcomeView(appModel: SwimNoteAppModel.bootstrap())
}

#Preview("Welcome View - Dark Mode") {
    WelcomeView(appModel: SwimNoteAppModel.bootstrap())
        .preferredColorScheme(.dark)
}