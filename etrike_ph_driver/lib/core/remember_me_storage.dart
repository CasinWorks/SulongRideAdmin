import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberMeState {
  const RememberMeState({
    required this.enabled,
    required this.email,
    required this.password,
  });

  final bool enabled;
  final String email;
  final String password;
}

/// Stores last login credentials securely (Keychain/Keystore).
///
/// Notes:
/// - This is opt-in (driver must toggle Remember me).
/// - Stored on-device only.
abstract final class RememberMeStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kEnabled = 'remember_me_enabled';
  static const _kEmail = 'remember_me_email';
  static const _kPassword = 'remember_me_password';

  static Future<RememberMeState> read() async {
    final enabledRaw = await _storage.read(key: _kEnabled);
    final enabled = enabledRaw == 'true';
    final email = (await _storage.read(key: _kEmail)) ?? '';
    final password = (await _storage.read(key: _kPassword)) ?? '';
    return RememberMeState(enabled: enabled, email: email, password: password);
  }

  static Future<void> write({
    required bool enabled,
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kEnabled, value: enabled ? 'true' : 'false');
    await _storage.write(key: _kEmail, value: email.trim());
    await _storage.write(key: _kPassword, value: password);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
  }
}

