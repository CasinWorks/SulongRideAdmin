# Sulong Ride Admin (Web)

Vite + React operator dashboard for the Carmona e-trike pilot. Replaces the Flutter `etrike_ph_admin` app for **Vercel deployment**.

Uses the **same Supabase project** as the rider and driver mobile apps.

## Features

- Operator login (Supabase Auth + `operators` table gate)
- Fleet overview (KPIs, 7-day chart, flagged items)
- Drivers directory & driver profile
- Pending / approved / revoked approval workflow
- Active fare editor (`fare_config`)
- Leave requests, attendance roster, audit logs
- Audit logging on admin mutations

## Setup

1. Run Supabase SQL (if not done): `etrike_ph_user/supabase/fix_carmona_pilot.sql`

2. Create an operator account in Supabase Auth, then:

```sql
insert into public.operators (id, email, full_name)
select id, email, 'Operator'
from auth.users
where email = 'ops@yourdomain.com'
on conflict (id) do update set email = excluded.email;
```

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
