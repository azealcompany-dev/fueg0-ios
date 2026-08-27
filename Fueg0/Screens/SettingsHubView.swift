import SwiftUI

struct SettingsHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(StoreService.self) private var store
    @State private var showTribeSelection = false
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showPasswordConfirm = false
    @State private var deletePassword = ""
    @State private var isDeleting = false
    @State private var deleteMessage: String?
    @State private var notificationsOn = NotificationService.isEnabled
    @State private var reminderTime = Calendar.current.date(
        from: DateComponents(hour: NotificationService.hour, minute: NotificationService.minute)
    ) ?? Date()
    @State private var showResetConfirm = false
    @State private var resetMessage: String?

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
                Text("Signed in with email or Google. Your warrior name stays on this iPhone and syncs when you’re online.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textMuted)
                    .lineSpacing(3)
                    .fueg0RowSurface()
            } header: {
                Text("Account")
            }

            Section {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fueg0 Premium")
                                .foregroundStyle(Palette.textPrimary)
                            Text(store.isPremium
                                 ? (store.isOnTrial ? "Trial active" : "Subscription active")
                                 : "Predictive Progress and insights")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textMuted)
                        }
                        Spacer()
                        Text(store.isPremium ? "Active" : store.priceLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.ember)
                    }
                }
                .fueg0RowSurface()
            } header: {
                Text("Premium")
            } footer: {
                Text("Purchases go through Apple. Restore from the paywall if you already subscribed.")
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
                Toggle("Daily reminder", isOn: $notificationsOn)
                    .tint(Palette.ember)
                    .fueg0RowSurface()
                    .onChange(of: notificationsOn) { _, enabled in
                        Task { await saveReminder(enabled: enabled) }
                    }
                if notificationsOn {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .fueg0RowSurface()
                        .onChange(of: reminderTime) { _, _ in
                            Task { await saveReminder(enabled: true) }
                        }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Fueg0 will remind you to ignite at this time each day. Don’t break the chain.")
            }

            Section {
                NavigationLink {
                    StreakCalendarView()
                } label: {
                    Text("Streak calendar")
                        .foregroundStyle(Palette.textPrimary)
                }
                .fueg0RowSurface()
                NavigationLink {
                    AchievementsView()
                } label: {
                    Text("Achievements")
                        .foregroundStyle(Palette.textPrimary)
                }
                .fueg0RowSurface()
                NavigationLink {
                    CustomGoalsView()
                } label: {
                    Text("My daily goals")
                        .foregroundStyle(Palette.textPrimary)
                }
                .fueg0RowSurface()

                Button("Replay onboarding") {
                    session.replayOnboarding()
                }
                .foregroundStyle(Palette.textPrimary)
                .fueg0RowSurface()

                Button("Reset progress", role: .destructive) {
                    showResetConfirm = true
                }
                .fueg0RowSurface()

                Button("Sign out", role: .destructive) {
                    session.signOut()
                }
                .fueg0RowSurface()

                Button(isDeleting ? "Deleting Account…" : "Delete Account", role: .destructive) {
                    showDeleteConfirm = true
                }
                .disabled(isDeleting || session.isBusy)
                .fueg0RowSurface()
            } footer: {
                Text("Reset clears streak, XP, laws, metrics, and achievements on this iPhone. Deleting your account does not cancel Fueg0 Premium.")
            }

            if let resetMessage {
                Section {
                    Text(resetMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ember)
                        .fueg0RowSurface()
                }
            }

            if let deleteMessage {
                Section {
                    Text(deleteMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.error)
                        .fueg0RowSurface()
                }
            }

            Section {
                Link("Privacy Policy", destination: LegalLinks.privacy)
                    .foregroundStyle(Palette.textPrimary)
                    .fueg0RowSurface()
                Link("Terms of Use", destination: LegalLinks.terms)
                    .foregroundStyle(Palette.textPrimary)
                    .fueg0RowSurface()
            } header: {
                Text("Legal")
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
        .fueg0PaywallSheet($showPaywall)
        .confirmationDialog(
            "Reset progress?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset Progress", role: .destructive) {
                session.resetProgress()
                notificationsOn = false
                resetMessage = "Progress reset on this iPhone."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears streak, XP, burned days, daily laws completions, warrior stats, and achievements. Your account and tribe stay.")
        }
        .confirmationDialog(
            "Delete Account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await runDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Your profile, streak, XP, tribe membership, and cloud data will be permanently deleted. This does not cancel Fueg0 Premium.")
        }
        .alert("Confirm it’s you", isPresented: $showPasswordConfirm) {
            SecureField("Password", text: $deletePassword)
            Button("Delete Account", role: .destructive) {
                Task { await runDelete(afterPassword: deletePassword) }
            }
            Button("Cancel", role: .cancel) {
                deletePassword = ""
            }
        } message: {
            Text("Enter your password to permanently delete this account.")
        }
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

    private func saveReminder(enabled: Bool) async {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let ok = await NotificationService.reschedule(
            enabled: enabled,
            hour: parts.hour ?? 7,
            minute: parts.minute ?? 0
        )
        notificationsOn = ok
    }

    private func runDelete(afterPassword password: String? = nil, google: Bool = false) async {
        isDeleting = true
        deleteMessage = nil
        defer { isDeleting = false }
        do {
            if google || password != nil {
                try await session.reauthenticateAndDelete(password: password, google: google)
            } else {
                try await session.deleteAccount()
            }
            deletePassword = ""
        } catch let failure as AuthFailure {
            switch failure {
            case .requiresRecentLogin(let isGoogle):
                if google {
                    deleteMessage = "Confirm it’s you, then try Delete Account again."
                } else if isGoogle {
                    await runDelete(google: true)
                } else {
                    deletePassword = ""
                    showPasswordConfirm = true
                }
            case .message(let text):
                deleteMessage = text
            }
        } catch {
            deleteMessage = error.localizedDescription
        }
    }
}
