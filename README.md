# AI Home Brain

AI Home Brain is a Flutter smart-home app supporting both Web and mobile with Firebase Authentication, simulated room and appliance controls, and a Gemini-powered voice assistant.

## Authentication

- **Web & Mobile Firebase Setup**: Connected to the provisioned Firebase project (`shining-talent-pq7xb`) via `firebase-applet-config.json` and `FirebaseConfig` in `lib/app/firebase_config.dart`.
- **Google Sign-In**: Supports 1-click **Continue with Google** via `signInWithPopup` on Web (`signInWithProvider` on mobile).
- **Email & Password**: Supports sign-in, registration, password reset, and profile sign-out (enable **Email/Password** in Firebase Console → Authentication → Sign-in method if using email accounts).

## Features

- **Home Dashboard**: Time-aware greeting, dark/light theme toggle, slide-out drawer, My Scenes (`Home`, `Away`, `Sleep`, `Morning`), and Favorite Devices.
- **Simulated Devices**: Living room Light, Bedroom Fan (with 1–5 speed slider in Bedroom Detail), and Front Door lock/sensor (with explicit confirmation before unlocking).
- **Voice Assistant**: Speech recognition (`speech_to_text`) and Gemini natural-language command classification (`firebase_ai`). Voice commands never unlock the door.

## Running Locally

```sh
flutter pub get
flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0
```
