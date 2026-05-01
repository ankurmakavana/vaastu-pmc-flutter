import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Keychain / Keystore ───────────────────────────────────────
  static Future<void>    secureWrite(String key, String val) => _secure.write(key: key, value: val);
  static Future<String?> secureRead(String key)              => _secure.read(key: key);
  static Future<void>    secureDelete(String key)            => _secure.delete(key: key);
  static Future<void>    secureClear()                       => _secure.deleteAll();

  // ── SharedPreferences ─────────────────────────────────────────
  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  static Future<void>    prefSet(String k, String v) async => (await _prefs).setString(k, v);
  static Future<String?> prefGet(String k)            async => (await _prefs).getString(k);
  static Future<void>    prefSetBool(String k, bool v) async => (await _prefs).setBool(k, v);
  static Future<bool>    prefGetBool(String k, {bool def=false}) async =>
      (await _prefs).getBool(k) ?? def;
}
