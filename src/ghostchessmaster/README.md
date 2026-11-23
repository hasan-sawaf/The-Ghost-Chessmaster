# GhostChessMaster — Flutter Mobile Application

The cross-platform Flutter companion app for **The Ghost Chessmaster**, providing:
- QR code board pairing & live Firebase Realtime Database / Firestore sync
- Remote match settings & control (timer, increment, Stockfish ELO, play style)
- 3-island progressive training campaign with local Stockfish analysis
- Post-match PGN review with move classification badges & accuracy breakdown
- Arabic (`ar`) and English (`en`) localization

## Setup & Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

To enable Firebase Authentication, Firestore, and Realtime Database with your own project, configure `lib/firebase_options.dart` and `android/app/google-services.json` (or run `flutterfire configure`).
