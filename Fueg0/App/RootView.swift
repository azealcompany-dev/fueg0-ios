import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            switch session.phase {
            case .splash:
                SplashView {
                    session.finishSplash()
                }
            case .login:
                LoginView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.phase)
    }
}
