import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AuthService {
  AuthService._();
  static final _auth = LocalAuthentication();

  static Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) { return false; }
  }

  static Future<List<BiometricType>> availableBiometrics() async {
    try { return await _auth.getAvailableBiometrics(); } catch (_) { return []; }
  }

  static Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access Vaastu PMC',
        options: const AuthenticationOptions(
          stickyAuth:    true,
          biometricOnly: false, // allow device PIN as fallback
        ),
      );
    } on PlatformException { return false; }
  }
}
