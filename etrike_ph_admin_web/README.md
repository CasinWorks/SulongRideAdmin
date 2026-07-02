# Sulong Ride Admin (Web)

Vite + React operator dashboard for the Carmona e-trike pilot. Replaces the Flutter `etrike_ph_admin` app for **Vercel deployment**.

Uses the **same Supabase project** as the rider and driver mobile apps.

## Features

- Operator login (Supabase Auth + `operators` table gate)
- **Google sign-in** (OAuth) or email/password
- Fleet overview (KPIs, 7-day chart, flagged items)
- Drivers directory & driver profile
- Pending / approved / revoked approval workflow
- Active fare editor (`fare_config`)
- Leave requests, attendance roster, audit logs
- Audit logging on admin mutations

## Setup

1. Run Supabase SQL (if not done): `etrike_ph_user/supabase/fix_carmona_pilot.sql`

2. Create an operator account — **email/password** or **Google**:

```sql
-- After the user signs in once (email or Google), grant operator access:
insert into public.operators (id, email, full_name)
select id, email, coalesce(raw_user_meta_data->>'full_name', 'Operator')
from auth.users
where email = 'ops@gmail.com'
on conflict (id) do update set email = excluded.email;
```

### Google sign-in (Gmail)

1. **Google Cloud Console** → OAuth client (Web) → redirect URI:
   `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
2. **Supabase** → Authentication → Providers → **Google** → enable, paste Client ID + Secret.
3. **Supabase** → URL Configuration → redirect URLs:
   - `http://localhost:5173`
   - `https://your-admin.vercel.app`
4. Optional: set `VITE_OPERATOR_EMAIL_DOMAIN` in `.env.local` / Vercel to restrict to one domain.

Google users still need a row in `operators` (same SQL as above).

3. Configure environment:

```bash
cp .env.example .env.local
# Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY (same as mobile apps)
```

4. Install & run:

```bash
npm install
npm run dev
```

Open http://localhost:5173

## Deploy to Vercel

1. Import this folder (`etrike_ph_admin_web`) as a new Vercel project
2. Framework preset: **Vite**
3. Add environment variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. Build command: `npm run build`
5. Output directory: `dist`

`vercel.json` includes SPA rewrites for React Router.

In Supabase → Authentication → URL Configuration, add your Vercel URL to **Redirect URLs**.

## Project layout

```
src/
  lib/          Supabase client, formatting
  services/     admin + audit API (mirrors Flutter repositories)
  hooks/        auth context
  pages/        route screens
  components/   layout + UI primitives
```

## Notes

- Rider (`etrike_ph_user`) and driver (`etrike_ph_driver`) apps remain **Flutter mobile only**.
- Flutter `etrike_ph_admin` can be retired once this web app is deployed.
- 7-step driver registration wizard is **not yet ported** — use Flutter admin or add in a follow-up.
