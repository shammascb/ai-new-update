# AI Home Brain: Learning Guide for Prompts 1-3

This guide explains what the first three prompts created, how the main pieces
work together, how to try them, and which behaviors are still demos.

## What exists so far

| Prompt | What it added | Real or demo? |
| --- | --- | --- |
| 1. Project foundation | Flutter app structure, Material 3 themes, reusable widgets, and a starter dashboard | App UI is real; initial device information was illustrative |
| 2. Login system | Registration, sign-in, password reset, profile, logout, and protected dashboard | Real Firebase Authentication on Android |
| 3. Home dashboard | Home/device status, Light/Fan/Door cards, automation modes, voice button, and recent activity | Dashboard controls and activity are demo-only |

## How the app is organized

The project is split into **features** so that each part has a clear job:

- `lib/app/` contains app startup, global theme, and Firebase setup messages.
- `lib/features/auth/` contains authentication operations and login/profile
  screens.
- `lib/features/dashboard/` contains the home dashboard and its demo controls.
- `lib/shared/` contains widgets that can be reused by multiple screens.
- `test/` contains automated widget tests.
- `android/` contains Android-specific build and Firebase configuration.

## What happens when the app starts

1. `lib/main.dart` is the Dart entry point. On Android it initializes Firebase
   and creates the authentication service.
2. `android/app/google-services.json` supplies this Android app's Firebase
   client settings. It is local configuration and is excluded from Git.
3. `lib/app/ai_home_brain_app.dart` creates the Material app and chooses the
   current dark or light theme.
4. `lib/features/auth/presentation/auth_gate.dart` listens to Firebase's
   signed-in user state:
   - If nobody is signed in, it shows the login screen.
   - If Firebase reports a signed-in user, it shows the protected dashboard.
5. Signing out changes Firebase's user state, so the gate returns to login.

This gate is why the dashboard does not open before a user signs in. It is not
a fake login or a button that simply skips authentication.

## Prompt 1: the foundation

The first prompt set up the app shell and a maintainable structure before
adding all product features.

- `lib/main.dart` starts the Flutter application.
- `lib/app/ai_home_brain_app.dart` configures the app and changes themes.
- `lib/app/theme/app_theme.dart` defines the dark and light Material 3 themes.
- `lib/shared/widgets/section_heading.dart` and
  `lib/shared/widgets/device_status_card.dart` are reusable UI building blocks.
- `pubspec.yaml` declares Flutter and the Firebase packages used by the app.

**Learn:** In Flutter, a screen is built from widgets. Smaller reusable widgets
make it easier to keep different screens visually consistent.

## Prompt 2: authentication

The app uses the Firebase Authentication service, not a local fake account.

- `lib/features/auth/data/firebase_auth_service.dart` calls Firebase to create
  accounts, sign in, send password-reset emails, and sign out.
- `lib/features/auth/presentation/auth_screen.dart` shows the forms and
  validates fields before sending a request.
- `lib/features/auth/presentation/auth_gate.dart` protects the dashboard based
  on Firebase's actual user state.
- `lib/features/auth/presentation/profile_screen.dart` displays the signed-in
  user's details and provides sign-out.

**Learn:** A form validates user input first. The authentication service then
sends it to Firebase. Firebase decides whether the account can be created or
the user can sign in; the UI displays success or an error.

Family members can have separate accounts. They are **not yet linked to one
shared household**, and there are no family roles or invitations yet.

## Prompt 3: dashboard

`lib/features/dashboard/presentation/dashboard_screen.dart` lays out:

- A personalized welcome and home-connection status.
- Separate Light, Fan, and Door cards with connection indicators.
- Light and fan switches, plus a fan-speed slider.
- Home, Morning, Sleep, and Away selection chips.
- A voice-assistant button and recent-activity examples.
- A profile button and dark/light theme toggle.

**Important:** Light and fan switches, speed, and automation selection only
change local demo UI state. They send no appliance commands. The displayed
activity is example data, and the door remains locked with no unlock control.
The voice button does not listen for speech. ESP32 hardware is not connected.

## Technologies in simple terms

- **Flutter** is the toolkit that builds the app screens for mobile.
- **Dart** is the programming language used to write the Flutter app.
- **Material 3** is the UI component and visual design system used here.
- **Firebase Authentication** is Google's online account service. It handles
  real email/password registration and sign-in for the configured Android app.
- **Cloud Firestore** is a Firebase database, but it is not connected yet.
- **MQTT over TLS** is a possible secure messaging method for future ESP32
  communication; it is not connected yet.

The Android project applies the Google Services Gradle plugin. If setting up
another checkout, register its Android package `com.example.ai_home_brain` in
your Firebase project, download `google-services.json` into
`android/app/google-services.json`, and enable Email/Password in Firebase
Authentication. Do not put Firebase service-account credentials in a mobile
app.

## Try the app

From the project directory:

```sh
flutter pub get
flutter run -d emulator-5554
```

In the app, create an account or sign in. After Firebase confirms sign-in, the
dashboard appears. Try the Light/Fan controls, fan speed, and mode chips; the
demo notice explains that no device was changed. Use the profile button to
sign out.

## Run the tests

```sh
flutter test
```

The widget tests check that:

- Firebase setup status and theme switching display correctly when no auth
  service is provided to the test.
- Empty login fields show validation errors.
- Registration rejects mismatched passwords.
- The dashboard displays its main sections and labels local control changes
  as demo-only.

## What is not built yet

- Family invitations, shared households, and member permissions.
- Voice recognition and voice profiles.
- Firestore storage for homes, devices, routines, or activity history.
- Real device status and commands.
- ESP32 integration through MQTT over TLS.
- Door-unlock confirmation with a phone PIN or biometrics.
- Notifications and persistent automation routines.
- iOS Firebase setup. The current Firebase config is for Android.
