class AppConstants {
  AppConstants._();

  static const String appName    = 'Vaastu PMC';
  static const String appTagline = 'Construction Management Suite';

  /// ← CHANGE THIS to your production domain
  static const String baseUrl    = 'https://pixelforge.lt/vaastupmc/public/login';

  /// Deep-link scheme (must match AndroidManifest + Info.plist)
  static const String deepLinkScheme = 'vaastupmc';

  /// Shared-prefs keys
  static const String keyOnboardingDone  = 'onboarding_done';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyFcmToken        = 'last_fcm_token';

  /// Secure-storage keys
  static const String secureSessionToken = 'session_token';
  static const String secureUserEmail    = 'user_email';
}
