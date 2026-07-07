import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/google_auth.dart';
import '../models/driver_model.dart';
import 'audit_repository.dart';

class AuthRepository {
  AuthRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithGoogle() async {
    try {
      final tokens = await GoogleAuth.signIn();
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      final user = response.user;
      if (user == null) {
        throw StateError('Missing user after sign-in.');
      }
      final metadata = user.userMetadata ?? {};
      await ensureDriverRowExists(
        fullName: _fullNameFromGoogle(user),
        email: user.email,
        phone: metadata['phone'] as String?,
        trikePlateNumber: metadata['trike_plate_number'] as String?,
        trikeModel: metadata['trike_model'] as String?,
      );
      final row = await _client
          .from('drivers')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        await _client.auth.signOut();
        await GoogleAuth.signOut();
        throw StateError(
          'This Google account is not registered as a driver. '
          'Register in this app first with email, then you can use Google sign-in.',
        );
      }
      await _audit.log(
        action: 'auth.sign_in',
        summary: 'Driver signed in with Google',
        metadata: {'provider': 'google'},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw StateError('Missing user after sign-in.');
      }
      final metadata = user.userMetadata ?? {};
      // Recover `drivers` row when email-confirm flow skipped signUp upsert (no session).
      await ensureDriverRowExists(
        fullName: metadata['full_name'] as String?,
        email: user.email ?? email,
        phone: metadata['phone'] as String?,
        trikePlateNumber: metadata['trike_plate_number'] as String?,
        trikeModel: metadata['trike_model'] as String?,
      );
      final row = await _client
          .from('drivers')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        await _client.auth.signOut();
        throw StateError('This account is not registered as a driver.');
      }
      await _audit.log(action: 'auth.sign_in', summary: 'Driver signed in');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? trikePlateNumber,
    String? trikeModel,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'driver',
          if (trikePlateNumber != null && trikePlateNumber.trim().isNotEmpty)
            'trike_plate_number': trikePlateNumber.trim(),
          if (trikeModel != null && trikeModel.trim().isNotEmpty)
            'trike_model': trikeModel.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
      // When email confirmation is off, session exists and we can upsert immediately.
      // When confirmation is on, session is null until the user confirms and signs in.
      await ensureDriverRowExists(
        fullName: fullName,
        email: email,
        phone: phone,
        trikePlateNumber: trikePlateNumber,
        trikeModel: trikeModel,
      );
      if (response.session != null) {
        await _audit.log(
          action: 'auth.sign_up',
          summary: 'Driver account registered',
          metadata: {'email': email},
        );
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _audit.log(action: 'auth.sign_out', summary: 'Driver signed out');
      await GoogleAuth.signOut();
      await _client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  String? _fullNameFromGoogle(User user) {
    final metadata = user.userMetadata ?? {};
    final fromMeta = (metadata['full_name'] as String?)?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;

    final given = (metadata['given_name'] as String?)?.trim();
    final family = (metadata['family_name'] as String?)?.trim();
    if (given != null && given.isNotEmpty) {
      return [given, family].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    }

    final display = (metadata['name'] as String?)?.trim();
    if (display != null && display.isNotEmpty) return display;

    return null;
  }

  /// Ensures [public.drivers] has a row for [auth.uid()] (required for trips FK).
  Future<void> ensureDriverRowExists({
    String? fullName,
    String? email,
    String? phone,
    String? trikePlateNumber,
    String? trikeModel,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? {};
    final fromMeta = (metadata['full_name'] as String?)?.trim();
    final resolvedName = _nonEmpty(fullName) ??
        _nonEmpty(fromMeta) ??
        _defaultFullName(user);
    final resolvedEmail = _nonEmpty(email) ??
        _nonEmpty(user.email) ??
        '${user.id}@placeholder.local';
    final resolvedPhone =
        _nonEmpty(phone) ?? _nonEmpty(metadata['phone'] as String?);
    final resolvedPlate = _nonEmpty(trikePlateNumber) ??
        _nonEmpty(metadata['trike_plate_number'] as String?);
    final resolvedModel =
        _nonEmpty(trikeModel) ?? _nonEmpty(metadata['trike_model'] as String?);

    await _client.from('drivers').upsert(
      {
        'id': user.id,
        'full_name': resolvedName,
        'email': resolvedEmail,
        'phone': ?resolvedPhone,
        'trike_plate_number': ?resolvedPlate,
        'trike_model': ?resolvedModel,
        'is_online': false,
        'is_available': false,
      },
      onConflict: 'id',
    );
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _defaultFullName(User user) {
    final addr = user.email;
    if (addr != null && addr.contains('@')) {
      return addr.split('@').first;
    }
    return 'Driver';
  }

  Future<DriverModel?> fetchDriverProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('drivers')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return null;
      final model = DriverModel.fromJson(row);
      final authEmail = user.email?.trim();
      if (authEmail != null &&
          authEmail.isNotEmpty &&
          model.email.toLowerCase() != authEmail.toLowerCase()) {
        await _client.from('drivers').update({'email': authEmail}).eq('id', user.id);
        return DriverModel.fromJson({...row, 'email': authEmail});
      }
      return model;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveFcmToken(String token) async {
    final user = currentUser;
    if (user == null || token.trim().isEmpty) return;
    try {
      await _client
          .from('drivers')
          .update({'fcm_token': token.trim()})
          .eq('id', user.id);
    } catch (_) {}
  }

  Future<void> updateDriverProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');
    await _client.from('drivers').update({
      'full_name': fullName.trim(),
      'phone': phone?.trim(),
    }).eq('id', user.id);
    await _client.auth.updateUser(
      UserAttributes(data: {'full_name': fullName.trim()}),
    );
    await _audit.log(
      action: 'driver.profile_update',
      entityType: 'drivers',
      entityId: user.id,
      summary: 'Driver updated profile',
      actorName: fullName.trim(),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    await _audit.log(action: 'auth.password_change', summary: 'Driver changed password');
  }
}
