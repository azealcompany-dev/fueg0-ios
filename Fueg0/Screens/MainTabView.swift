import SwiftUI

enum AppTab: Hashable {
    case home, tribe, progress, settings
}

struct MainTabView: View {
    @State private var tab: AppTab = .home

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabs
            } else {
                legacyTabs
            }
        }
        .tint(Palette.ember)
    }

    @available(iOS 18.0, *)
    private var modernTabs: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView(onOpenSettings: { tab = .settings })
            }
            Tab("Tribe", systemImage: "person.3", value: AppTab.tribe) {
                NavigationStack {
                    TribeHubView()
                }
            }
            Tab("Progress", systemImage: "checklist", value: AppTab.progress) {
                NavigationStack {
                    ProgressHubView()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsHubView()
                }
            }
        }
    }

    private var legacyTabs: some View {
        TabView(selection: $tab) {
            HomeView(onOpenSettings: { tab = .settings })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            NavigationStack {
                TribeHubView()
            }
            .tabItem { Label("Tribe", systemImage: "person.3") }
            .tag(AppTab.tribe)

            NavigationStack {
                ProgressHubView()
            }
            .tabItem { Label("Progress", systemImage: "checklist") }
            .tag(AppTab.progress)

            NavigationStack {
                SettingsHubView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
    }
}
