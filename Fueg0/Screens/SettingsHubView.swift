import SwiftUI

struct SettingsHubView: View {
    @Environment(AppSession.self) private var session
    @State private var showTribeSelection = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.displayName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    if let email = session.userEmail {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                    }
                    if let tribe = session.tribe {
                        Text(tribe.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.ember)
                    } else {
                        Text("No tribe yet")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                .padding(.vertical, 6)
                .fueg0RowSurface()
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Signed in with email or Google. Warrior name lives on this iPhone and in Firestore users/{uid}.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textMuted)
                        .lineSpacing(3)
                }
                .fueg0RowSurface()
            } header: {
                Text("Account")
            }

            if session.tribe == nil {
                Section {
                    Text("You have not pledged a pack yet. Join one of the seven tribes to earn points together.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textMuted)
                        .fueg0RowSurface()
                    Button("Choose a tribe") {
                        showTribeSelection = true
                    }
                    .foregroundStyle(Palette.ember)
                    .fueg0RowSurface()
                } header: {
                    Text("Tribe")
                }
            } else {
                Section {
                    Button("Switch tribe") {
                        showTribeSelection = true
                    }
                    .foregroundStyle(Palette.ember)
                    .fueg0RowSurface()
                } header: {
                    Text("Tribe")
                }
            }

            Section {
                Button("Replay onboarding") {
                    session.replayOnboarding()
                }
                .foregroundStyle(Palette.textPrimary)
                .fueg0RowSurface()

                Button("Sign out", role: .destructive) {
                    session.signOut()
                }
                .fueg0RowSurface()
            }

            Section {
                Text("Version 1.0 (1)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .fueg0ListChrome()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTribeSelection) {
            NavigationStack {
                TribeSelectionView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showTribeSelection = false }
                        }
                    }
            }
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
        }
    }
}
