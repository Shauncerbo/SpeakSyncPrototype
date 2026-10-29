# How to Run SpeakSync

This guide is for teammates who want to run the current SpeakSync Flutter app on an Android phone. Use Android for complete testing because the rehearsal flow depends on the device camera, microphone, and Android MediaPipe integration.

## 1. Required software

Install the following before opening the project:

- [Git](https://git-scm.com/downloads)
- [Flutter](https://docs.flutter.dev/get-started/install) **3.41.5 stable** (or a compatible newer stable version)
- Android Studio with the Android SDK, platform tools, and an Android SDK platform installed
- Java/JDK **17** (Android Studio's bundled JDK 17 is suitable)
- A physical Android phone is recommended

The project currently uses Dart `3.11.3` and requires Dart `^3.11.3`.

Check the setup:

```powershell
flutter --version
flutter doctor -v
```

Resolve any Android toolchain errors reported by `flutter doctor` before continuing. If Android licenses are pending, run:

```powershell
flutter doctor --android-licenses
```

## 2. Get the project

For a new copy:

```powershell
git clone https://github.com/Shauncerbo/SpeakSyncPrototype.git
cd SpeakSyncPrototype
```

If the project is already on the computer, open a terminal in its root directory and update it:

```powershell
git checkout main
git pull origin main
```

The correct directory contains `pubspec.yaml`, `lib`, and `android`.

## 3. Install Flutter dependencies

From the project root, run:

```powershell
flutter pub get
```

Do not run `flutter pub upgrade` unless the team has agreed to update dependencies, because it can introduce incompatible package versions.

## 4. Create the local Groq configuration

SpeakSync reads its Groq key from a local `.env.json` file through Flutter's `--dart-define-from-file` option. The real key must not be placed in Dart code or committed to Git.

Create the local file from the included template:

```powershell
Copy-Item .env.json.example .env.json
```

Open `.env.json` and use this valid JSON structure:

```json
{
  "GROQ_API_KEY": "paste-your-development-key-here",
  "GROQ_FINAL_TRANSCRIPTION_MODEL": "whisper-large-v3",
  "GROQ_TRANSCRIPTION_CONTEXT_ENABLED": true
}
```

Important:

- Ask the project owner for a development key through a private channel, or create an authorized Groq development key.
- Do not add comments, trailing commas, or Markdown formatting to the JSON file.
- Do not commit or send `.env.json` in chat. It is already excluded by `.gitignore`.
- `whisper-large-v3` is the current final-transcription model. Live feedback continues to use Turbo as configured by the app.
- Set the context value to the JSON boolean `true` or `false`, not the text `"true"`.

Without a valid key, the UI can open, but Groq-dependent transcription and rehearsal analysis will report that Groq is not configured or unavailable.

> Security limitation: `--dart-define` embeds the value in the compiled app. This is acceptable only for controlled prototype testing; it is not secure API-key storage for a public APK. Use a restricted development key, do not publicly distribute a keyed APK, and rotate the key if it is exposed.

## 5. Connect an Android phone

On the phone:

1. Open **Settings > About phone** and tap **Build number** seven times to enable Developer options.
2. Open **Developer options** and enable **USB debugging**.
3. Connect the phone by USB and choose a data-transfer connection if prompted.
4. Accept the **Allow USB debugging** prompt on the phone.

On the computer, verify that Flutter sees the phone:

```powershell
flutter devices
```

The output will show a device ID, for example:

```text
A8UVB21C28001776 • android-arm64 • Android 12 (API 31)
```

If Windows does not detect the phone, install the manufacturer's USB driver, reconnect it, and run `flutter devices` again.

## 6. Run SpeakSync

Replace `<DEVICE_ID>` with the ID shown by `flutter devices`:

```powershell
flutter run -d <DEVICE_ID> --dart-define-from-file=.env.json
```

Example:

```powershell
flutter run -d A8UVB21C28001776 --dart-define-from-file=.env.json
```

On the first launch:

- Allow camera access.
- Allow microphone access.
- Keep Wi-Fi or mobile data enabled for Groq transcription.
- Use a well-lit area and keep the face, shoulders, and upper body visible for visual analysis.

Press `r` in the running terminal for hot reload, `R` for hot restart, or `q` to stop the app.

## 7. Build a debug APK

To create a debug APK with the local configuration:

```powershell
flutter build apk --debug --dart-define-from-file=.env.json
```

The APK is generated at:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

The debug APK contains the supplied development key. Share it only with approved testers and do not upload it publicly.

## 8. Run project checks

Before giving changes to another teammate, run:

```powershell
dart format .
flutter analyze --no-pub
flutter test --no-pub
```

Formatting can modify source files. Review `git status` afterward before committing anything.

## Common problems

### `Groq not configured` or `Transcript unavailable`

- Confirm `.env.json` exists in the same directory as `pubspec.yaml`.
- Confirm its property is exactly `GROQ_API_KEY`.
- Validate that the file contains proper JSON and a current authorized key.
- Stop and rerun the app with `--dart-define-from-file=.env.json`; hot reload cannot add a missing compile-time define.
- Confirm the phone has working internet access.

### No Android device appears

- Unlock the phone and accept the USB-debugging prompt.
- Try another data-capable USB cable or USB port.
- Confirm USB debugging is enabled.
- Install the phone manufacturer's Windows USB driver.
- Run `flutter doctor -v` and `flutter devices` again.

### Camera or microphone is unavailable

- Open Android **Settings > Apps > SpeakSync > Permissions**.
- Allow Camera and Microphone.
- Close and reopen the app.
- Make sure another application is not exclusively using the camera or microphone.

### Gradle or Java error

- Confirm Java 17 is active with `java -version`.
- In Android Studio, select its bundled JDK 17 for Gradle.
- Run `flutter clean`, then `flutter pub get`, and retry the run command.

### Dependency or generated-file error

Run:

```powershell
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Only regenerate Hive adapters when the source models require it. Do not manually renumber Hive type IDs or field indexes.

## Quick command summary

```powershell
git pull origin main
flutter pub get
flutter devices
flutter run -d <DEVICE_ID> --dart-define-from-file=.env.json
```

For functional phone-testing steps after the app runs, see [`docs/test-this.md`](docs/test-this.md).
