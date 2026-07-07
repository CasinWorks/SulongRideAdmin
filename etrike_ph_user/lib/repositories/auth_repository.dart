import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/google_auth.dart';
import '../models/user_model.dart';
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
        throw StateError('Missing user after Google sign-in.');
      }
      final fullName = _fullNameFromGoogle(user);
      await ensureUserRowExists(fullName: fullName, email: user.email);
      if (fullName != null) {
        await _client.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }
      await _audit.log(
        action: 'auth.sign_in',
        summary: 'Rider signed in with Google',
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
      await ensureUserRowExists(
        fullName: response.user?.userMetadata?['full_name'] as String?,
        email: response.user?.email ?? email,
      );
      await _audit.log(action: 'auth.sign_in', summary: 'Rider signed in');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      await ensureUserRowExists(fullName: fullName, email: email);
      if (response.session != null) {
        await _audit.log(
          action: 'auth.sign_up',
          summary: 'Rider account registered',
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
      await _audit.log(action: 'auth.sign_out', summary: 'Rider signed out');
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

  /// Ensures [public.users] has a row for [auth.uid()] (required for trips FK).
  Future<void> ensureUserRowExists({
    String? fullName,
    String? email,
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

    await _client.from('users').upsert(
      {
        'id': user.id,
        'full_name': resolvedName,
        'email': resolvedEmail,
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
    return 'Rider';
  }

  Future<UserModel?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return null;
      return UserModel.fromJson(row);
    } catch (e) {
      rethrow;
    }
  }

  /// Stub for future push integration (OneSignal / FCM).
  Future<void> saveFcmToken(String token) async {
    final user = currentUser;
    if (user == null || token.trim().isEmpty) return;
    try {
      await _client
          .from('users')
          .update({'fcm_token': token.trim()})
          .eq('id', user.id);
    } catch (_) {}
  }
}
