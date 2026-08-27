# Fueg0 iOS (native)

**No excuses. Only fire.**

Native SwiftUI iPhone shell for Fueg0. The Flutter app at `../fueg0` remains the product spec and still owns live Firebase auth, daily fire video, WODs, streak lock, tribe war room, paywall, and the rest of feature parity.

## Identity

- Display name: Fueg0
- Bundle ID: `com.azealcompany.fueg0`
- Team: `B8VKLXY4L2`
- Version: 1.0 (1)
- iOS 17+

## Milestone 1

In this native port:

- Splash, onboarding (welcome / ignite ritual / tribes / name), home
- Tab shell for Tribe, Progress, Settings (designed “coming in this native port” screens)
- San Francisco, warm black, ember used sparingly
- App icon and `GoogleService-Info.plist` copied from the Flutter iOS target

Still Flutter-only:

- Google Sign-In / Firebase Auth / Firestore
- Daily Fire YouTube, Hell Fire, streak calendar
- Tribe war room, leaderboard, feed
- 6 Daily Laws, body metrics, custom goals, achievements
- Premium paywall / StoreKit, notifications, progress reset

## Generate & build

```bash
xcodegen generate
xcodebuild -scheme Fueg0 -destination 'platform=iOS Simulator,name=iPhone 16e' -configuration Debug build
```

`GoogleService-Info.plist` is present for a future Firebase SPM add. Do not invent API keys. Live auth is a milestone 2 TODO.
