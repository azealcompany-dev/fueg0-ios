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
- Tab shell for Progress and Settings

Still Flutter-only:

- Daily Fire YouTube (no API key in this repo)
- Hell Fire canvas, streak calendar
- 6 Daily Laws, body metrics, custom goals, achievements
- Premium paywall / StoreKit, notifications, progress reset

## Generate & build

```bash
xcodegen generate
xcodebuild -scheme Fueg0 -destination 'platform=iOS Simulator,name=iPhone 16e' -configuration Debug build
```

`GoogleService-Info.plist` is copied from the Flutter iOS target. Do not invent API keys.
