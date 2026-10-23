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
- Ignite ritual: Hell Fire canvas → Daily Fire YouTube, today’s WOD, lock the chain, local XP/streak
- Streak calendar + share (Home streak pill and Settings)
- Tribe tab: pick one of seven tribes, weekly leaderboard, membership feed
- Tab shell with the iOS 18 `Tab` API, system tab bar (Liquid Glass on iOS 26)
- Progress: native Daily Laws checklist (Flutter prefs + tribe awards)
- StoreKit 2 paywall for `fueg0_premium_monthly` (7-day intro offer from the store)
- Account deletion in Settings (Firestore `users/{uid}` + Auth user, with password or Google reauth)
- Custom daily laws editor, achievements, warrior stats / TDEE prediction
- Daily reminder notifications and local progress reset

Still Flutter-only:

- Profile photo, Sign in with Apple

## Generate & build

```bash
xcodegen generate
xcodebuild -scheme Fueg0 -destination 'platform=iOS Simulator,name=iPhone 16e' -configuration Debug build
```

`GoogleService-Info.plist` is copied from the Flutter iOS target. Do not invent API keys.

### YouTube Daily Fire

Ignite plays a shuffled feed of motivational videos in the official YouTube IFrame player (streamed, not downloaded). Each app session and each calendar day gets a new order. The video you just finished is not the first one next time.

Search uses the YouTube Data API v3 when a key is configured. Without a key, or when YouTube returns a quota error, a network error, or nothing playable, Ignite plays the bundled list in `MotivationalCatalog` (`Fueg0/Services/DailyFireEngine.swift`). Removed or embed-restricted videos are skipped. If playback itself cannot reach YouTube, the player shows a retry message instead of a blank screen.

Do not commit a key. Copy the example plist and paste a key restricted to the iOS bundle `com.azealcompany.fueg0` and to the YouTube Data API:

```bash
cp Secrets.example.plist Fueg0/Config/Secrets.plist
```

`Fueg0/Config/Secrets.plist` is gitignored. Set `YouTubeAPIKey` in that file. A local build can also set the `YOUTUBE_API_KEY` environment variable, which wins over the plist. Requests send `X-Ios-Bundle-Identifier: com.azealcompany.fueg0`, which an iOS-restricted key requires. The feed still plays from the bundled list when the key is missing.

`Fueg0.storekit` is a local StoreKit configuration (monthly + 7-day free intro). Device purchases still need the product in App Store Connect. Entitlement comes from StoreKit 2 `Transaction.currentEntitlement`, not a local trial flag.
