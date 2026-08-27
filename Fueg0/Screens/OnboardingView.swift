import SwiftUI

struct OnboardingView: View {
    @Environment(AppSession.self) private var session

    @State private var page = 0
    @State private var name = ""
    @State private var selectedTribe: Tribe?
    @State private var didPrefill = false

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                welcomePage.tag(0)
                ritualPage.tag(1)
                tribesPage.tag(2)
                namePage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut(duration: 0.35), value: page)

            indicator
                .padding(.vertical, Spacing.md)

            footer
                .fueg0ScreenPadding()
                .padding(.bottom, Spacing.lg)
        }
        .background(Palette.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            if name.isEmpty, session.displayName != "Warrior" {
                name = session.displayName
            }
            if selectedTribe == nil {
                selectedTribe = session.tribe
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Fueg0")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            if page < pageCount - 1 {
                Button("Skip") {
                    page = pageCount - 1
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.textMuted)
            }
        }
        .fueg0ScreenPadding()
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private var welcomePage: some View {
        OnboardingCopy(
            kicker: "Fueg0",
            title: "Welcome, warrior.",
            copy: "Not a fitness app. A daily war against weakness.\nEvery sunrise is your call to battle."
        )
    }

    private var ritualPage: some View {
        OnboardingCopy(
            kicker: "The ritual",
            title: "Ignite each day.",
            copy: "Watch the fire speech. Crush the WOD.\nBurn the excuses to ash."
        )
    }

    private var tribesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                OnboardingCopy(
                    kicker: "Tribe",
                    title: "Rise together.",
                    copy: "Pick a pack. Earn points together. Fall alone.",
                    padded: false
                )

                LazyVStack(spacing: 8) {
                    ForEach(Tribe.all) { tribe in
                        TribeRow(tribe: tribe, selected: selectedTribe?.id == tribe.id) {
                            selectedTribe = tribe
                        }
                    }
                }
            }
            .fueg0ScreenPadding()
            .padding(.bottom, Spacing.md)
        }
    }

    private var namePage: some View {
        OnboardingCopy(
            kicker: "Name",
            title: "Who walks in?",
            copy: "Claim the name you bring into the fire."
        ) {
            TextField("Your name", text: $name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.ember)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                        .fill(Palette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                        .stroke(name.isEmpty ? Palette.hairline : Palette.emberBorder, lineWidth: 1)
                )
        }
    }

    private var indicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Palette.ember : Palette.textMuted.opacity(0.35))
                    .frame(width: index == page ? 18 : 6, height: 6)
                    .animation(.easeOut(duration: 0.25), value: page)
            }
        }
    }

    private var footer: some View {
        Group {
            if page == pageCount - 1 {
                EmberButton(title: "Enter the fire") {
                    session.completeOnboarding(name: name, tribe: selectedTribe)
                }
            } else {
                EmberButton(title: "Continue") {
                    page += 1
                }
            }
        }
    }
}

private struct OnboardingCopy<Extra: View>: View {
    let kicker: String
    let title: String
    let copy: String
    var padded: Bool = true
    @ViewBuilder var extra: Extra

    init(
        kicker: String,
        title: String,
        copy: String,
        padded: Bool = true,
        @ViewBuilder extra: () -> Extra
    ) {
        self.kicker = kicker
        self.title = title
        self.copy = copy
        self.padded = padded
        self.extra = extra()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: padded ? 24 : 8)
            Text(kicker)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ember)
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Spacing.md)
            Text(copy)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(5)
                .padding(.top, Spacing.lg)
            extra
                .padding(.top, Spacing.xl)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, padded ? Spacing.screen : 0)
    }
}

extension OnboardingCopy where Extra == EmptyView {
    init(kicker: String, title: String, copy: String, padded: Bool = true) {
        self.init(kicker: kicker, title: title, copy: copy, padded: padded) {
            EmptyView()
        }
    }
}
