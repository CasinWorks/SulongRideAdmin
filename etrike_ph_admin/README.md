# Sulong Ride Admin (`etrike_ph_admin`)

Operator web dashboard for the Carmona pilot:

- **Driver approval queue** — approve / reject pending drivers
- **Approved drivers** — view and revoke
- **Fare editor** — update active `fare_config` (₱40 flat default)

## Setup

1. Run SQL in Supabase (same project as mobile apps):

   `etrike_ph_user/supabase/fix_carmona_pilot.sql`

2. Create an operator account:
   - Supabase Dashboard → **Authentication** → add user (email + password)
   - SQL Editor:

   ```sql
   insert into public.operators (id, email, full_name)
   values ('YOUR_AUTH_USER_UUID', 'ops@yourdomain.com', 'Operator Name');
   ```

3. Run the admin app (**web only** — rider/driver apps crash in Chrome):

   ```bash
   cd etrike_ph_admin
   flutter clean
   flutter pub get
   flutter run -d chrome
   ```

   Use only `etrike_ph_admin`. Do not run `etrike_ph_user` or `etrike_ph_driver` in the browser.

## Notes

- Uses the same `supabaseUrl` / `supabaseAnonKey` as the rider and driver apps (`lib/core/constants/keys.dart`).
- Drivers with `approval_status = pending` cannot go online in the driver app until approved here.
- FCM push delivery still requires Firebase project setup (tokens are saved to `users.fcm_token` / `drivers.fcm_token` when wired).
