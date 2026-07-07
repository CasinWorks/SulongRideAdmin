# Sulong Ride Apps — Rider app (`etrike_ph_user`)

**Sulong Ride Apps** — *Smart Tricycle apps System*: Flutter rider app with map-first booking, Supabase auth/data/realtime, and Google Maps + Places + Directions (via `dio`).

## Prerequisites

- Flutter SDK (stable, Dart 3.11+)
- A Supabase project
- A Google Cloud project with **Maps SDK for Android/iOS**, **Places API**, **Directions API**, and **Geocoding API** enabled

## 1) Configure secrets (`lib/core/constants/keys.dart`)

Set:

- `supabaseUrl`, `supabaseAnonKey`
- `googleMapsNativeApiKey` — map tiles only (see step 2)
- `googleMapsWebServicesApiKey` — Places / Geocoding / Directions from Dart (see below)

Branding strings live in `lib/core/constants/app_strings.dart`.

### Two Google API keys (required)

The app uses Google in two different ways:

| Use | Where | Key constant | Application restriction in Google Cloud |
|-----|--------|--------------|----------------------------------------|
| Map tiles | `Info.plist` / Android manifest | `googleMapsNativeApiKey` | **iOS apps** → `com.etrikeph.etrikePhUser` (and Android package + SHA-1) |
| Search & routes | Dart HTTP (`trip_repository.dart`) | `googleMapsWebServicesApiKey` | **None** (restrict by **API** only) |

If you restrict the same key to **iOS apps only**, search fails with:

> *This IP, site or mobile application is not authorized to use this API key … empty referer*

HTTP calls from the app are not signed with your bundle ID, so they need a key with **no application restriction**.

**Setup in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):**

1. Enable billing and APIs: **Maps SDK for iOS**, **Places API**, **Geocoding API**, **Directions API**.
2. **Key A (native):** Application → iOS apps → `com.etrikeph.etrikePhUser`. API → Maps SDK for iOS (+ Android SDK if needed). Put in `googleMapsNativeApiKey` and `ios/Runner/Info.plist` (`GMSApiKey`).
3. **Key B (web services):** Application → **None**. API → Places, Geocoding, Directions only. Put in `googleMapsWebServicesApiKey` only (not in Info.plist).
4. Rebuild and reinstall the app.

### Grey / white map on iPhone (tiles not loading)

Typical on **Trip • requested** (`lib/views/screens/trip/trip_active_screen.dart`) or home map: you see pins and the Google logo but no map tiles.

This is almost always **Google Cloud**, not app code. `AppDelegate` and `Info.plist` already pass `GMSApiKey`.

1. **APIs & Services → Library** — enable **Maps SDK for iOS** (and Android if needed). Billing must be on.
2. **Credentials → your native key (Key A)** → **API restrictions** → allow **Maps SDK for iOS** (and Android). If the key is restricted to Places/Geocoding/Directions only, search/booking can work while the map stays white.
3. **Application restrictions → iOS apps** — bundle ID must match Xcode exactly: `com.etrikeph.etrikePhUser`. If one key is shared with the driver app, **also** add `com.etrikeph.etrikePhDriver` (do not remove the rider bundle).
4. Rebuild after GCP changes: `flutter clean && flutter run` (simulator is fine).

**One native key for both apps is OK** — list both iOS bundle IDs (and both Android package names) on Key A. Use a **second** key (Key B) with no application restriction for Places/Geocoding/Directions in `googleMapsWebServicesApiKey` only.

## 3) Supabase schema

Create the tables described in the product spec (`users`, `drivers`, `trips`, `messages`).

### `fare_config` (required for fare loading)

```sql
create extension if not exists "pgcrypto";

create table if not exists public.fare_config (
  id uuid primary key default gen_random_uuid(),
  base_fare numeric not null default 40.00,
  per_km_rate numeric not null default 0.00,
  minimum_fare numeric not null default 40.00,
  currency text not null default 'PHP',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Seed a single active row (adjust numbers in Supabase as needed)
insert into public.fare_config (base_fare, per_km_rate, minimum_fare, currency, is_active)
values (40.00, 0.00, 40.00, 'PHP', true);
```

Enable **Realtime** for the tables you want live updates on (at minimum: `drivers`, `trips`, `messages`).

### Row Level Security — `public.users` (fixes “violates row-level security policy” on Register)

After `signUp`, the app upserts a row into `public.users` with `id = auth.uid()`. RLS must allow that. In the Supabase **SQL Editor**, run [`supabase/fix_users_rls.sql`](supabase/fix_users_rls.sql).

If users already signed up before RLS was fixed (booking fails with `trips_rider_id_fkey`), run [`supabase/backfill_users_from_auth.sql`](supabase/backfill_users_from_auth.sql) as well.

### `trips` (required for Book ride — fixes `PGRST204 distance_km`)

If booking shows *Could not find the 'distance_km' column of 'trips' in the schema cache* (`PGRST204`):

1. Adding the column is not enough — you must **reload PostgREST’s schema cache**.
2. Run the full script [`supabase/fix_trips_distance_km.sql`](supabase/fix_trips_distance_km.sql) in the Supabase **SQL Editor** (includes `notify pgrst, 'reload schema'`).
3. Confirm the last `SELECT` lists `distance_km`. Wait ~30 seconds, then book again.

Full table + RLS policies: [`supabase/trips.sql`](supabase/trips.sql).

If booking shows *violates row-level security policy for table "trips"* (`42501`), run [`supabase/fix_trips_rls.sql`](supabase/fix_trips_rls.sql).

Enable **Realtime** on `public.trips` for live trip updates.

You will need similar **RLS policies** on `drivers` and `messages`.

### Email confirmation & `localhost:3000` links

Supabase confirmation emails use **Site URL** / **Redirect URLs** from the dashboard (often `http://localhost:3000`). That URL is for **web** apps, not Flutter on a phone — opening the link in Safari does not finish signup inside the rider app.

**MVP testing (recommended):**

1. Dashboard → **Authentication** → **Providers** → **Email** → disable **Confirm email** → Save.
2. Register in the app; you get a session and the `users` row is created immediately.

If confirm email stays on, sign in after confirming (or use [`supabase/backfill_users_from_auth.sql`](supabase/backfill_users_from_auth.sql) if `users` is missing). Driver app: see `etrike_ph_driver/README.md` § Supabase Auth.

## 4) Run

```bash
cd etrike_ph_user
flutter pub get
flutter run
```

## 5) Analyze

```bash
flutter analyze
```

## Notes

- Foreground local notifications are implemented for “driver accepted” (FCM wiring is stubbed with a `TODO` in `AuthRepository.saveFcmToken`).
- Fare is loaded from Supabase on startup via `fareConfigProvider` — update values in `fare_config` to change pricing without shipping a new app binary.
