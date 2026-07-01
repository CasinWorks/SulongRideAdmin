# SulongRideAdmin

Operator admin for the Sulong Ride / Carmona e-trike pilot.

This repo contains two admin clients that share the same Supabase backend as the rider and driver mobile apps:

| Folder | Stack | Use |
|--------|-------|-----|
| [`etrike_ph_admin_web/`](etrike_ph_admin_web/) | Vite + React + TypeScript | **Production** — deploy to Vercel |
| [`etrike_ph_admin/`](etrike_ph_admin/) | Flutter Web | Legacy / reference — local Chrome only |

## Quick start (Vercel web admin)

```bash
cd etrike_ph_admin_web
cp .env.example .env.local
# Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

Open http://localhost:5173

## Deploy to Vercel

1. Import this GitHub repo in [Vercel](https://vercel.com/new).
2. Set **Root Directory** to `etrike_ph_admin_web`.
3. Framework preset: **Vite**
4. Environment variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. Build command: `npm run build`
6. Output directory: `dist`

`etrike_ph_admin_web/vercel.json` includes SPA rewrites for React Router.

In Supabase → Authentication → URL Configuration, add your Vercel URL to **Redirect URLs**.

## Operator account

Run SQL in Supabase (if not done already), then create an operator:

```sql
insert into public.operators (id, email, full_name)
select id, email, 'Operator'
from auth.users
where email = 'ops@yourdomain.com'
on conflict (id) do update set email = excluded.email;
```

Pilot SQL migrations live in the main EtrikeApp repo under `etrike_ph_user/supabase/`.

## Flutter admin (optional)

```bash
cd etrike_ph_admin
flutter pub get
flutter run -d chrome
```

Uses `lib/core/constants/keys.dart` for Supabase credentials (same project as mobile apps).

## Features

- Operator login (Supabase Auth + `operators` table)
- Fleet overview, drivers directory, approval workflow
- Fare editor, leave requests, attendance roster, audit logs
