# Google (Gmail) sign-in — rider & driver apps

Both mobile apps support **Continue with Google** using the same Supabase Google provider as admin-web.

## 1. Google Cloud Console

Create OAuth clients (same GCP project as Maps):

| Type | Bundle / package | Purpose |
|------|------------------|---------|
| **Web application** | — | Client ID goes in **Supabase** and `googleOAuthWebClientId` |
| **iOS** | `com.etrikeph.etrikePhUser` / `com.etrikeph.etrikePhDriver` | `googleOAuthIosClientId` |
| **Android** | `com.etrikeph.etrike_ph_user` / `com.etrikeph.etrike_ph_driver` | SHA-1 from debug/release keystore |

Web client redirect URI (required for Supabase):

```
https://litrignthoxsdvsaheev.supabase.co/auth/v1/callback
```

## 2. Supabase

Authentication → Providers → **Google** → enable, paste Web client ID + secret.

## 3. App configuration

Set in `lib/core/constants/keys.dart` **or** pass at build time:

```bash
flutter run \
  --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com \
  --dart-define=GOOGLE_OAUTH_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com \
  --dart-define=GOOGLE_OAUTH_IOS_URL_SCHEME=com.googleusercontent.apps.YOUR_IOS_CLIENT_PREFIX
```

### iOS — Info.plist

Add a URL scheme (reversed iOS client ID) under `CFBundleURLTypes`:

```xml
<string>com.googleusercontent.apps.123456789-abcdef</string>
```

Rider app already has `sulongride://` for deep links; Google needs its own scheme entry.

## 4. Behavior

| App | Google sign-in |
|-----|----------------|
| **Rider** | Sign in or sign up — creates `auth.users` + `public.users` |
| **Driver** | Sign in only — must have registered with email first (needs plate number). No driver row → blocked. |

Admin-web remains **invite-only** for operators; drivers with Gmail can use the **driver app** but are blocked from admin-web.
