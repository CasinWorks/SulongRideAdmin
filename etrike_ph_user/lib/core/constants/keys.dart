/// Central place for Supabase and Google API configuration.
///
/// **Two Google keys are required** — they must be different values.
///
/// | Key | GCP APIs | Where in this repo | Application restriction |
/// |-----|----------|-------------------|-------------------------|
/// | Maps SDK (native) | Maps SDK for iOS, Maps 3D SDK for iOS, Maps SDK for Android | [googleMapsNativeApiKey] below **and** `ios/Runner/Info.plist` (`GMSApiKey`) **and** `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`) | iOS: `com.etrikeph.etrikePhUser`; Android: `com.etrikeph.etrike_ph_user` (+ SHA-1) |
/// | REST / web services | Places API, Places API (New), Geocoding API, Directions API | [googleMapsWebServicesApiKey] below only (used by `trip_repository.dart`) | **None** (API-restrict only) |
const String supabaseUrl = 'https://litrignthoxsdvsaheev.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpdHJpZ250aG94c2R2c2FoZWV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyNzAwODgsImV4cCI6MjA5Mzg0NjA4OH0.45hy5HXK26hzdFgNi7_LopUJV7awv5XxRQDF4HGnYl4';

/// **Key 1 — Maps SDK (native map tiles).**
///
/// Paste your Maps SDK key here, then copy the same value to:
/// - `ios/Runner/Info.plist` → `GMSApiKey`
/// - `android/app/src/main/AndroidManifest.xml` → `com.google.android.geo.API_KEY`
///
/// Google Cloud → Credentials → this key:
/// - Application restrictions → iOS apps: `com.etrikeph.etrikePhUser`
///   (add `com.etrikeph.etrikePhDriver` if driver app shares this key)
/// - API restrictions → **Maps SDK for iOS**, **Maps 3D SDK for iOS**, **Maps SDK for Android**
///
/// Replace with your Maps SDK key before shipping.
const String _mapsSdkKeyPlaceholder = 'AIzaSyB1pJmXS4nw0HvPWEOZfk-IR1j2QJlcX1E ';

/// Do **not** use this key for Dart HTTP calls (Places/Directions/Geocoding).
const String googleMapsNativeApiKey = 'AIzaSyCsllZKOdGcdjm99UqdDZf_inosDYeSr-4';

/// **Key 2 — REST / web services (Places, Geocoding, Directions).**
///
/// Used only by Dart HTTP in `trip_repository.dart`. Never put in Info.plist or AndroidManifest.
///
/// Google Cloud → Credentials → this key:
/// - Application restrictions → **None**
/// - API restrictions → Places API, Places API (New), Geocoding API, Directions API
const String googleMapsWebServicesApiKey =
    'AIzaSyAvn7SsAp-MxlAlXt7C9eyKh6cQQqICVms';

/// True when native and REST keys are configured as two distinct values.
bool get googleMapsKeysConfigured =>
    googleMapsNativeApiKey.isNotEmpty &&
    googleMapsNativeApiKey != _mapsSdkKeyPlaceholder &&
    googleMapsNativeApiKey != googleMapsWebServicesApiKey;

/// **OAuth — Google Sign-In (Gmail).**
///
/// Use the **Web application** client ID from Google Cloud — the same value
/// pasted in Supabase → Authentication → Providers → Google → Client ID.
///
/// Also create iOS and Android OAuth clients for each app bundle ID, then set
/// [googleOAuthIosClientId] and add the reversed iOS client ID to Info.plist
/// (`CFBundleURLSchemes`).
const String googleOAuthWebClientId = String.fromEnvironment(
  'GOOGLE_OAUTH_WEB_CLIENT_ID',
  defaultValue: '',
);

/// iOS OAuth client ID (`*.apps.googleusercontent.com`) for `com.etrikeph.etrikePhUser`.
const String googleOAuthIosClientId = String.fromEnvironment(
  'GOOGLE_OAUTH_IOS_CLIENT_ID',
  defaultValue: '',
);

/// Reversed iOS client ID for Info.plist URL scheme (without `.apps.googleusercontent.com`).
/// Example: `com.googleusercontent.apps.123456789-abcdef`
const String googleOAuthIosUrlScheme = String.fromEnvironment(
  'GOOGLE_OAUTH_IOS_URL_SCHEME',
  defaultValue: '',
);

bool get googleOAuthConfigured =>
    googleOAuthWebClientId.isNotEmpty &&
    googleOAuthWebClientId != 'PASTE_GOOGLE_WEB_CLIENT_ID';
