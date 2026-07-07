import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import 'constants/keys.dart';

/// Native Google Sign-In → Supabase `signInWithIdToken`.
class GoogleAuth {
  GoogleAuth._();

  static GoogleSignIn? _instance;

  static GoogleSignIn get _googleSignIn {
    _instance ??= GoogleSignIn(
      serverClientId:
          googleOAuthWebClientId.isNotEmpty ? googleOAuthWebClientId : null,
      clientId: Platform.isIOS && googleOAuthIosClientId.isNotEmpty
          ? googleOAuthIosClientId
          : null,
      scopes: const ['email', 'profile'],
    );
    return _instance!;
  }

  static Future<({String idToken, String? accessToken})> signIn() async {
    if (!googleOAuthConfigured) {
      throw StateError(
        'Google sign-in is not configured. Set googleOAuthWebClientId (and '
        'googleOAuthIosClientId on iOS) in lib/core/constants/keys.dart — use '
        'the same Web client ID as Supabase → Authentication → Google.',
      );
    }

    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw StateError('Google sign-in was cancelled.');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an ID token. On Android, set serverClientId to '
        'your Web OAuth client ID. On iOS, add the reversed client ID URL '
        'scheme to Info.plist.',
      );
    }

    return (idToken: idToken, accessToken: auth.accessToken);
  }

  static Future<void> signOut() async {
    if (_instance != null) {
      await _instance!.signOut();
    }
  }
}
