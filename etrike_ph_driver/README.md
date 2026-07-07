# Sulong Ride Apps — Driver app (`etrike_ph_driver`)

**Sulong Ride Apps** — *Smart Tricycle apps System*: Flutter driver app with a dark map-first UI, online presence + periodic location uploads, incoming trip requests via Supabase Realtime, and in-trip status controls.

## Prerequisites

- Flutter SDK (stable, Dart 3.11+)
- A Supabase project
- A Google Cloud project with **Maps SDK for Android/iOS** enabled

## 1) Configure secrets (`lib/core/constants/keys.dart`)

Set:

- `supabaseUrl`, `supabaseAnonKey`
- `googleMapsNativeApiKey`

Branding strings live in `lib/core/constants/app_strings.dart`.

## 2) Configure native Google Maps keys (required for map tiles)

- **Android**: `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
- **iOS**: `ios/Runner/Info.plist` (`GMSApiKey`)

Keep these values in sync with `googleMapsNativeApiKey` in `keys.dart`.

### Grey / white map on iOS Simulator (tiles not loading)

This is usually **API key restrictions**, not a Flutter bug.

1. In [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Credentials** → your Maps key.
2. Under **Application restrictions** → **iOS apps**, add bundle ID:
   - `com.etrikeph.etrikePhDriver` (see `ios/Runner.xcodeproj` → `PRODUCT_BUNDLE_IDENTIFIER`)
3. Under **API restrictions**, enable **Maps SDK for iOS** (and Android if you test on device).
4. For quick local dev you can set restrictions to **None** on a separate dev-only key (never ship that key to production).

Android package name for restrictions: `com.etrikeph.etrike_ph_driver` (`android/app/build.gradle.kts` → `applicationId`).

## 3) Supabase Auth (registration & email links)

Mobile apps do **not** use `http://localhost:3000`. Supabase’s default **Site URL** and confirmation links often open Safari to `localhost:3000/?error=otp_expired` with nothing listening — that does **not** complete signup in the app.

### Recommended for MVP / device testing

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. **Authentication** → **Providers** → **Email**.
3. Turn **off** **Confirm email** (save). New driver sign-ups get a session immediately; the app can upsert `public.drivers` on Register.
4. Register in the driver app, then sign in with the same email/password. No email link required.

### If you keep Confirm email on

- **Authentication** → **URL Configuration**: set **Site URL** and **Redirect URLs** to URLs you actually control (not `localhost:3000` unless you run a web app there). Email links still complete auth in the **browser**, not inside the Flutter app.
- After confirming (or if the link failed), open the driver app and **Log in** — sign-in runs `ensureDriverRowExists` and creates the missing `drivers` row from auth metadata.
- On Register, if there is no session yet, you are sent to **Login** after sign-up; use Login once email is confirmed (or disable confirm email as above).

### `drivers` row missing for an existing auth user

Run [`supabase/setup_test_driver.sql`](supabase/setup_test_driver.sql) (table + RLS), then either:

- **Log in** again in the driver app (creates the row), or
- **SQL backfill** for accounts with `role: driver` in metadata: [`supabase/backfill_drivers_from_auth.sql`](supabase/backfill_drivers_from_auth.sql)

## 4) Supabase schema

Drivers must exist in the `drivers` table with `id` matching `auth.users.id` for the same email login.

**Quick fix (recommended):** run [`supabase/apply_mvp_fixes.sql`](supabase/apply_mvp_fixes.sql) once — drivers columns, RLS, and schema cache reload.

Or run [`supabase/setup_test_driver.sql`](supabase/setup_test_driver.sql) before first Register (creates `drivers` + RLS).

### `drivers` online / location columns (fixes `PGRST204 is_online`)

If going **Online** shows *Could not find the 'is_online' column of 'drivers' in the schema cache* (`PGRST204`):

1. Adding columns is not enough — you must **reload PostgREST’s schema cache**.
2. Run the full script [`supabase/fix_drivers_schema.sql`](supabase/fix_drivers_schema.sql) in the Supabase **SQL Editor** (includes `notify pgrst, 'reload schema'`).
3. Confirm the verification `SELECT` lists `is_online`, `is_available`, `current_lat`, `current_lng`. Wait ~30 seconds, toggle **Online** again.

### Incoming trip requests (driver home)

1. Run [`supabase/setup_test_driver.sql`](supabase/setup_test_driver.sql) — includes `trips_select_requested` RLS so drivers can read open `requested` rows.
2. Enable **Realtime** on `trips` (see below). Without it, the app still **polls every 4s** while **Online** is on.
3. Test flow: driver app → toggle **Online** (green) → rider app → book trip → driver should get a snackbar (debug) + incoming sheet.

### Realtime (recommended for instant incoming trips)

In Supabase Dashboard → **Database** → **Publications** → `supabase_realtime`, add tables:

- **`trips`** — driver app subscribes to `trips` changes (filters `requested` + unassigned client-side)
- **`drivers`** — rider map can show online drivers (optional but recommended)
- **`messages`** — in-trip chat (if used)

Optional SQL (SQL Editor):

```sql
alter publication supabase_realtime add table public.trips;
```

Without **`trips`** in Realtime, polling while online still surfaces new bookings within ~4 seconds.

### `fare_config`

Use the same `fare_config` table as the rider app. See the rider `README.md` for the SQL snippet.

See **Realtime** above. Configure **RLS** for production.

## 5) Run

```bash
cd etrike_ph_driver
flutter pub get
flutter run
```

## 6) Analyze

```bash
flutter analyze
```

## Notes

- **Session after rebuild:** Supabase keeps the auth session on device. A hot restart or `flutter run` sends you to `/home` if still signed in — that is expected. Use **Profile → Sign out** (or clear the simulator app) to test login again.
- While **Online** is enabled, the app attempts a location update every **5 seconds** (best-effort; errors are swallowed to avoid spamming UI).
- Foreground local notifications fire on new trip requests (FCM wiring is stubbed with a `TODO` in `AuthRepository.saveFcmToken`).
