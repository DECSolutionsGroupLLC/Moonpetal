# Moonpetal

Moonpetal is a private, on-device period tracker. It helps you record how you feel, understand your own patterns, and get a useful sense of what is coming next — without putting your health data on a server, behind an account, or into analytics.

Moonpetal runs on Android, with a Linux build for using and testing the app on a desktop.

## Features

- **Quick daily logging.** Mark today as a period day in one tap, or set a specific start date for an earlier bleed. Mark a period ended when it is over.
- **Flow levels.** Record spotting, light, medium, or heavy flow in one tap, and change or clear it later.
- **Symptoms.** Log common symptoms — cramps, mood, energy, headaches, and sleep — with an optional severity or value, and add your own custom symptom names.
- **Notes and tags.** Write a free-text note for any day and attach your own labels to group entries your way.
- **Next-period Estimate.** See an estimated next period as a date inside a visible range rather than a single promised day. The range widens when your cycles vary, and every estimate is labelled as an estimate, not medical advice.
- **Cycle calendar.** See estimated menstrual, follicular, ovulatory, and luteal phases, each clearly marked as an estimate.
- **Pattern insights.** Plain-language summaries next to readable charts for cycle length, bleed duration, symptom frequency, and variability — with no medical claims.
- **Corrections and history.** Edit any past entry; previous values are kept with timestamps and you can review what changed and when. Estimates recompute from your corrected data.
- **Optional fertility view.** Off by default. Turn it on to see an ovulation estimate and fertile window, accompanied by a permanent notice that these estimates are not reliable contraception. No day is ever coloured "safe".
- **Reminders.** On Android, get a local reminder before your estimated period and a configurable daily logging prompt. The Linux build clearly notes that notifications are Android-only. All reminder settings stay on your device.
- **Export and restore.** Save all your log entries and Settings into one human-readable JSON text file, in a location you choose, and restore from that file when you need to.
- **A pink theme** with readable contrast and text sizing, designed for a phone screen.

## Privacy

Your log entries and Settings never leave your device. The app has no account and no cloud, contains no analytics or crash-reporting code of its own, and requests no network permission. Data is stored locally on your device and is only exported when you explicitly choose to export it. Moonpetal makes no network calls.

Because Moonpetal is distributed through the Google Play Store, Google Play gives the developer a small amount of store-level information: generic app install and uninstall counts, plus crash reports so that app issues can be spotted and fixed. This is collected by Google Play as part of distributing the app — Moonpetal itself has no analytics code, sends no data, and never reports on your log entries, Settings, or health information. These are generic metrics rather than identifiable information about you; no health data is included.

## Open source

Moonpetal is open source — anyone can inspect the code behind the privacy promise:

<https://github.com/DECSolutionsGroupLLC/Moonpetal>

## Getting started

### Prerequisites

- **Flutter 3.47.7** (which bundles **Dart 3.13.5**). Install the Flutter SDK by following the [official Flutter installation guide](https://docs.flutter.dev/get-started/install) and make sure `flutter` is on your `PATH`. Check your installation with `flutter --version`.
- For Android: Android Studio with an Android SDK, and either a connected device or an emulator.
- For Linux: the [Linux desktop build prerequisites](https://docs.flutter.dev/platform-integration/linux/building) (CMake, GTK 3, and the other development libraries).

From the project root, fetch the dependencies:

```sh
flutter pub get
```

### Run the tests

```sh
flutter test
```

### Build and run on Android

Connect a device or start an emulator, then check that Flutter sees it with `flutter devices`. Run the app on a connected device:

```sh
flutter run -d <device-id>
```

To build a release APK:

```sh
flutter build apk
```

### Build and run on Linux

If Linux desktop support is not already enabled, enable it once:

```sh
flutter config --enable-linux-desktop
```

Then run or build the desktop app:

```sh
flutter run -d linux
flutter build linux
```

The Linux build cannot deliver notifications; the reminder settings screen shows a clear note that notifications are Android-only. Your reminder settings are still saved on the device and included in your export.
