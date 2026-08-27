import GoogleSignIn
import SwiftUI

@main
struct Fueg0App: App {
    @State private var session: AppSession
    @State private var store: StoreService

    init() {
        FirebaseBootstrap.configure()
        Self.configureChrome()
        _session = State(initialValue: AppSession())
        _store = State(initialValue: StoreService())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Palette.ember)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await NotificationService.scheduleIfEnabled()
                }
        }
    }

    private static func configureChrome() {
        UITabBar.appearance().unselectedItemTintColor = UIColor(Palette.textMuted)
        UINavigationBar.appearance().tintColor = UIColor(Palette.ember)

        let nav = UINavigationBarAppearance()
        if #available(iOS 26.0, *) {
            nav.configureWithTransparentBackground()
        } else {
            nav.configureWithOpaqueBackground()
            nav.backgroundColor = UIColor(Palette.background)
            nav.shadowColor = .clear
        }
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(Palette.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Palette.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        if #available(iOS 26.0, *) {
            // Keep the system tab bar so Liquid Glass can draw.
        } else {
            let tab = UITabBarAppearance()
            tab.configureWithOpaqueBackground()
            tab.backgroundColor = UIColor(Palette.background)
            tab.shadowColor = UIColor(Palette.hairline)
            UITabBar.appearance().standardAppearance = tab
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
    }
}
