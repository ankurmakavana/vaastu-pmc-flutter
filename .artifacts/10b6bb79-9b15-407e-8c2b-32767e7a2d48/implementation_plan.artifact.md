# Change Application Name to "v connect"

The goal is to rename the application from "Vaastu PMC" to "v connect" across all platforms and relevant code constants.

## Proposed Changes

### [Flutter Constants & UI]

#### [MODIFY] [app_constants.dart](file:///D:/StudioProjects/vaastu-pmc/lib/utils/app_constants.dart)
Update `appName` constant to `"v connect"`.

#### [MODIFY] [splash_screen.dart](file:///D:/StudioProjects/vaastu-pmc/lib/screens/splash_screen.dart)
Update the display text to `"V CONNECT"`.

#### [MODIFY] [onboarding_screen.dart](file:///D:/StudioProjects/vaastu-pmc/lib/screens/onboarding_screen.dart)
Update welcome and descriptive text.

#### [MODIFY] [notification_service.dart](file:///D:/StudioProjects/vaastu-pmc/lib/services/notification_service.dart)
Update notification channel name and default title.

#### [MODIFY] [auth_service.dart](file:///D:/StudioProjects/vaastu-pmc/lib/services/auth_service.dart)
Update biometric authentication reason string.

### [Android Configuration]

#### [MODIFY] [AndroidManifest.xml](file:///D:/StudioProjects/vaastu-pmc/android/app/src/main/AndroidManifest.xml)
Update `android:label` to `"v connect"`.

### [iOS Configuration]

#### [MODIFY] [Info.plist](file:///D:/StudioProjects/vaastu-pmc/ios/Runner/Info.plist)
Update `CFBundleDisplayName` and usage descriptions for Camera, Photo Library, Location, and Face ID.

### [Project Metadata]

#### [MODIFY] [pubspec.yaml](file:///D:/StudioProjects/vaastu-pmc/pubspec.yaml)
Update the `description` field.

#### [MODIFY] [package.json](file:///D:/StudioProjects/vaastu-pmc/package.json)
Update the `description` field.

#### [MODIFY] [app.json](file:///D:/StudioProjects/vaastu-pmc/app.json)
Update the `name` field.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no issues were introduced.

### Manual Verification
- Check the splash screen in the app.
- Verify the app name in the Android launcher and iOS home screen (after deployment).
- Verify the biometric prompt text.
