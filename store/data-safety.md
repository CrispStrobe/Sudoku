# Data safety & privacy questionnaire answers

CrispSudoku collects **no data**. Below are the exact answers for each store's
privacy questionnaire.

## Apple — App Privacy ("nutrition labels", App Store Connect)

Select: **Data Not Collected.**

> "We do not collect any data from this app."

- Tracking: **No.** The app does not track users and contacts no tracking
  domains (see `ios/Runner/PrivacyInfo.xcprivacy`, `NSPrivacyTracking = false`).
- The bundled **`PrivacyInfo.xcprivacy`** declares the two required-reason APIs
  used: `UserDefaults` (CA92.1, via `shared_preferences`) and `SystemBootTime`
  (35F9.1, via Dart's `Stopwatch`). Neither involves data collection.

## Google Play — Data safety form

- **Does your app collect or share any of the required user data types?** → **No.**
- **Is all of the user data encrypted in transit?** → N/A (no data is collected
  or transmitted).
- **Do you provide a way for users to request that their data is deleted?** →
  N/A (no data collected; uninstalling removes all local data).
- **Has your app's data collection been independently verified?** → No.

On-device-only storage (game progress, stats, settings via `shared_preferences`)
is **not** "collected or shared" under Play's definition because it never leaves
the device and is not transmitted off-device.

## Permissions

CrispSudoku requests **no runtime permissions** (no internet permission is
required for gameplay; no location, camera, microphone, contacts, or storage
permissions). `url_launcher` only opens the OS mail/browser on an explicit tap.
