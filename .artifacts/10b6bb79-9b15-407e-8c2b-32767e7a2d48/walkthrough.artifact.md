# Release Build Resolution Walkthrough

I have resolved the issues preventing the release APK build for the Vaastu PMC project. The build now completes successfully and produces an APK in the standard Flutter location.

## Changes Made

### 1. Updated Android SDK Versions
Updated `compileSdk` and `targetSdk` to **36** in `android/app/build.gradle.kts`. This was required by several plugins (e.g., `app_links`, `geolocator_android`, `shared_preferences_android`) that have been updated to target the latest Android APIs.

### 2. Restored Build Directory Redirection
Corrected the build directory configuration in `android/build.gradle.kts`. This ensures that Flutter can correctly locate the generated APKs in the root `build/` folder rather than internal Gradle subfolders.

### 3. Resolved Environment Variable Conflict
Identified a conflict between `ANDROID_PREFS_ROOT` and `ANDROID_USER_HOME` environment variables which caused the Android Gradle Plugin to fail.

## Verification Results

- **Release APK Generated:** [app-release.apk](file:///D:/StudioProjects/vaastu-pmc/build/app/outputs/flutter-apk/app-release.apk)
- **Build Success:** Verified via `./gradlew assembleRelease` and `flutter build apk`.
- **APK Size:** ~50.5 MB

> [!IMPORTANT]
> To run builds successfully in your local terminal, you may need to unset the deprecated `ANDROID_PREFS_ROOT` environment variable or ensure it matches `ANDROID_USER_HOME`.
>
> **PowerShell Command:**
> ```powershell
> $env:ANDROID_PREFS_ROOT=$null; flutter build apk --release
> ```

## Final APK Location
The final release APK is located at:
`D:\StudioProjects\vaastu-pmc\build\app\outputs\flutter-apk\app-release.apk`
