# Fueg0 iOS (native)

**No excuses. Only fire.**

Native SwiftUI iPhone app for Fueg0. The Flutter app at `../fueg0` remains the product spec.

## Identity

- Display name: Fueg0
- Bundle ID: `com.azealcompany.fueg0`
- Team: `B8VKLXY4L2`
- Version: 1.0 (1)
- iOS 17+

## Milestone 3

In this native port:

- Firebase Auth (email/password + Google Sign-In) and Firestore `users/{uid}`
- Session: signed-out → login; signed-in + not onboarded → onboarding; else home
- Splash, onboarding, home
- Ignite ritual: today’s WOD (daily rotation), lock the chain, local XP/streak
- Tribe tab: pick one of seven tribes, weekly leaderboard, membership feed
- Tab shell with the iOS 18 `Tab` API, system tab bar (Liquid Glass on iOS 26)
- Progress: native Daily Laws checklist (Flutter prefs + tribe awards)
- StoreKit 2 paywall for `fueg0_premium_monthly` (7-day intro offer from the store)
- Account deletion in Settings (Firestore `users/{uid}` + Auth user, with password or Google reauth)

Still Flutter-only:

- Daily Fire YouTube (no API key in this repo)
- Hell Fire canvas, streak calendar
- Body metrics, custom goals editor, achievements
- Notifications, progress reset

## Generate & build

```bash
xcodegen generate
xcodebuild -scheme Fueg0 -destination 'platform=iOS Simulator,name=iPhone 16e' -configuration Debug build
```

`GoogleService-Info.plist` is copied from the Flutter iOS target. Do not invent API keys.

`Fueg0.storekit` is a local StoreKit configuration (monthly + 7-day free intro). Device purchases still need the product in App Store Connect. Entitlement comes from StoreKit 2 `Transaction.currentEntitlement`, not a local trial flag.
