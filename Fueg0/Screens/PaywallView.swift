import SwiftUI

struct PaywallView: View {
    @Environment(StoreService.self) private var store
    var onClose: (() -> Void)? = nil

    var body: some View {
        Group {
            if store.isLoading && store.product == nil && !store.isPremium {
                loading
            } else if store.isPremium {
                subscribed
            } else {
                offer
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("FUEG0 Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
        .task { await store.refresh() }
        .preferredColorScheme(.dark)
    }

    private var loading: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Palette.ember)
            Text("Loading premium…")
                .font(.system(size: 15))
                .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subscribed: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Palette.ember)
            Text("You are Premium")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text(store.isOnTrial
                 ? "\(store.trialDaysRemaining) trial days remaining"
                 : "Full access unlocked")
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .fueg0ScreenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var offer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Unlock the work.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .tracking(-0.5)

                Text(trialHeadline)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 8)

                if !store.storeAvailable {
                    Text("Store unavailable — price shown is an estimate.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.top, 8)
                }

                VStack(spacing: 0) {
                    ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                        if index > 0 {
                            Rectangle()
                                .fill(Palette.hairline)
                                .frame(height: 1)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.ember)
                                .padding(.top, 2)
                            Text(feature)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                        .stroke(Palette.hairline, lineWidth: 1)
                )
                .padding(.top, 28)

                EmberButton(
                    title: ctaTitle,
                    enabled: store.storeAvailable && !store.isPurchasing,
                    loading: store.isPurchasing
                ) {
                    Task {
                        let success = await store.purchase()
                        if success { onClose?() }
                    }
                }
                .padding(.top, 32)

                Button("Restore purchases") {
                    Task { await store.restore() }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .disabled(store.isPurchasing)

                if let message = store.lastMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }

                legalCopy
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.lg)
        }
    }

    private var trialHeadline: String {
        if store.showsIntroOffer {
            return "\(store.trialDaysFromStore)-day free trial, then \(store.priceLabel)/month"
        }
        return "\(store.priceLabel)/month, auto-renewable"
    }

    private var ctaTitle: String {
        if store.showsIntroOffer {
            return "Start \(store.trialDaysFromStore)-day free trial"
        }
        return "Subscribe for \(store.priceLabel)/month"
    }

    private var legalCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(legalSentence)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
                .lineSpacing(3)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: LegalLinks.privacy)
                Link("Terms of Use", destination: LegalLinks.terms)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.textSecondary)
            .underline()
        }
    }

    /// Apple 3.1.2 auto-renewable subscription disclosure.
    private var legalSentence: String {
        let title = store.productTitle
        let price = store.priceLabel
        let days = store.trialDaysFromStore
        return "\(title). Auto-renewable subscription. Length: 1 month. "
            + "Price: \(price) per month after a \(days)-day free trial "
            + "(if you are eligible for the introductory offer). "
            + "Payment will be charged to your Apple ID at confirmation of purchase. "
            + "The subscription automatically renews unless it is canceled at least "
            + "24 hours before the end of the current period. Your account will be "
            + "charged for renewal within 24 hours prior to the end of the current "
            + "period at the same price. You can manage or cancel the subscription "
            + "in your store account settings."
    }

    static let features = [
        "Predictive Progress — goal timeline from your stats",
        "TDEE-based calorie, training, and sleep insights",
        "Consistency score with weekly trend",
        "Actionable tips to hit your target faster"
    ]
}

extension View {
    func fueg0PaywallSheet(_ presented: Binding<Bool>) -> some View {
        sheet(isPresented: presented) {
            NavigationStack {
                PaywallView(onClose: { presented.wrappedValue = false })
            }
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
        }
    }
}
