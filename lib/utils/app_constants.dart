class AppConstants {
  AppConstants._();

  static const String appName    = 'v connect';
  static const String appTagline = 'Construction Management Suite';

  /// Single Source of Truth Production Domain
  static const String baseUrl    = 'https://vaastuapp.vaastupmc.in';

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
