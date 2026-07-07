/// Central place for Supabase and Google API configuration.
/// Must match [etrike_ph_user] `keys.dart` Supabase project.
const String supabaseUrl = 'https://litrignthoxsdvsaheev.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpdHJpZ250aG94c2R2c2FoZWV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyNzAwODgsImV4cCI6MjA5Mzg0NjA4OH0.45hy5HXK26hzdFgNi7_LopUJV7awv5XxRQDF4HGnYl4';

/// **Key 1 — Maps SDK (native map tiles).**
///
/// Copy the same value to `ios/Runner/Info.plist` (`GMSApiKey`) and
/// `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`).
///
/// Google Cloud → Credentials → this key → Application restrictions → iOS apps:
/// add `com.etrikeph.etrikePhDriver` (and `com.etrikeph.etrikePhUser` for rider).
const String googleMapsNativeApiKey = 'AIzaSyCsllZKOdGcdjm99UqdDZf_inosDYeSr-4';

/// **Key 2 — REST / web services** (only if driver app adds Places/Directions later).
const String googleMapsWebServicesApiKey =
    'AIzaSyAvn7SsAp-MxlAlXt7C9eyKh6cQQqICVms';

@Deprecated('Use googleMapsNativeApiKey')
const String googleMapsApiKey = googleMapsNativeApiKey;

/// **OAuth — Google Sign-In (Gmail).** Same Web client ID as Supabase Google provider.
const String googleOAuthWebClientId = String.fromEnvironment(
  'GOOGLE_OAUTH_WEB_CLIENT_ID',
  defaultValue: '',
);

/// iOS OAuth client ID for `com.etrikeph.etrikePhDriver`.
const String googleOAuthIosClientId = String.fromEnvironment(
  'GOOGLE_OAUTH_IOS_CLIENT_ID',
  defaultValue: '',
);

const String googleOAuthIosUrlScheme = String.fromEnvironment(
  'GOOGLE_OAUTH_IOS_URL_SCHEME',
  defaultValue: '',
);

bool get googleOAuthConfigured =>
    googleOAuthWebClientId.isNotEmpty &&
    googleOAuthWebClientId != 'PASTE_GOOGLE_WEB_CLIENT_ID';
