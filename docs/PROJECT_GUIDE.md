# Sulong Ride — Project Guide

Complete reference for the **Sulong Ride Apps** (*Smart Tricycle apps System*) monorepo: architecture, applications, backend, operations, deployment, and roadmap.

**Last updated:** July 5, 2026  
**Current environment:** **Dev** (`dev`)  
**Supabase project:** `litrignthoxsdvsaheev`  
**Service area:** Carmona, Cavite (~ `14.3132, 121.0565`)

---

## Table of contents

1. [Product overview](#1-product-overview)
2. [System architecture](#2-system-architecture)
3. [Monorepo structure](#3-monorepo-structure)
4. [Technology stack](#4-technology-stack)
5. [Applications](#5-applications)
6. [Database & Supabase](#6-database--supabase)
7. [Authentication & authorization](#7-authentication--authorization)
8. [Core business flows](#8-core-business-flows)
9. [Configuration & secrets](#9-configuration--secrets)
10. [Realtime & notifications](#10-realtime--notifications)
11. [Third-party services](#11-third-party-services)
12. [Deployment & environments](#12-deployment--environments)
13. [Testing & QA](#13-testing--qa)
14. [Roadmap & phases](#14-roadmap--phases)
15. [Troubleshooting](#15-troubleshooting)
16. [Related documents](#16-related-documents)

---

## 1. Product overview

Sulong Ride is a ride-hailing platform built for **e-trike fleet operators**. It connects:

- **Riders** — book trips in Carmona via a map-first mobile app (cash payment MVP at ₱40 flat fare)
- **Drivers** — company-employed e-trike drivers who go Online, receive requests, and complete trips
- **Operators** — fleet admins who approve drivers, assign vehicles, manage payroll, HR, and compliance

### MVP scope (Phase 0–1)

- Email/Google auth (no email confirmation for MVP)
- Map booking with Places autocomplete (Carmona-biased)
- Live trip tracking, in-trip chat, ride history
- Driver onboarding (documents, training quiz), operator approval, fleet assignment
- Admin web: drivers, fleet, payroll, attendance, leave, audit, maintenance mode
- iOS + Android verified; admin web on Vercel (`dev` / `UAT` / `main`)

### Out of scope until later phases

- GCash digital payments (Phase 2)
- FCM background push (deferred pending budget — see §10)
- TestFlight / App Store distribution (Phase 3, Nov 2026)
- Carmona pilot with 5 live drivers (Phase 4, Dec 2026)

---

## 2. System architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT APPLICATIONS                            │
├──────────────────┬──────────────────┬──────────────────────────────────┤
│  Rider App       │  Driver App      │  Admin Web (Vercel)              │
│  Flutter iOS/    │  Flutter iOS/    │  React 19 + Vite + Tailwind      │
│  Android         │  Android         │  react-router-dom                │
│  etrike_ph_user  │  etrike_ph_driver│  etrike_ph_admin_web             │
└────────┬─────────┴────────┬─────────┴──────────────┬───────────────────┘
         │                  │                        │
         └──────────────────┼────────────────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   Supabase (PostgreSQL)    │
              │   • Auth (JWT)             │
              │   • Row Level Security     │
              │   • Realtime (trips,       │
              │     drivers, messages)     │
              │   • Storage (driver docs)  │
              │   • Edge Functions         │
              └─────────────┬─────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────▼────┐      ┌──────▼──────┐    ┌─────▼─────┐
    │ Google  │      │  Firebase   │    │  Waze /   │
    │ Maps    │      │  FCM        │    │  Google   │
    │ Places  │      │  (deferred) │    │  Maps     │
    │ Direct. │      └─────────────┘    └───────────┘
    └─────────┘
```

### Design principles

- **Single Supabase project** shared by all apps (split per-env DB is future work)
- **Realtime-first** for trip state, driver location, and chat (reduces need for push in pilot)
- **RLS everywhere** — riders see own trips; drivers see assigned trips; operators scoped by role
- **Gate-heavy driver flow** — approval, documents, training, and fleet assignment before going Online
- **SQL migrations in-repo** — run manually in Supabase SQL Editor (not CLI migrations)

---

## 3. Monorepo structure

```
EtrikeApp/
├── README.md                    ← Monorepo entry point
├── docs/
│   └── PROJECT_GUIDE.md         ← This document
├── Sulong_Ride_Project_Tracker.csv
├── etrike_ph_user/              ← Rider Flutter app
│   ├── lib/
│   ├── supabase/                ← Primary SQL scripts + edge functions
│   └── README.md
├── etrike_ph_driver/            ← Driver Flutter app
│   ├── lib/
│   ├── supabase/                ← Driver-specific SQL
│   └── README.md
├── etrike_ph_admin_web/         ← Operator admin (production UI)
│   ├── src/
│   ├── vercel.json
│   └── README.md
├── etrike_ph_admin/             ← Legacy Flutter admin (Chrome)
├── design-reference:/           ← UI prototype (no backend)
└── tools/
    ├── DEV_UAT_TEST_CHECKLIST.md
    ├── FULL_TEST_MATRIX.md
    ├── RIDE_TEST.md
    └── notion-sync/             ← CSV → Notion tracker sync
```

There is **no root workspace config** — each app is built and deployed independently.

---

## 4. Technology stack

### Flutter apps (rider + driver)

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Declarative routing |
| `supabase_flutter` | Auth, DB, Realtime, Storage |
| `google_maps_flutter` | Map display |
| `dio` | Places / Directions HTTP (rider) |
| `geolocator` | GPS location |
| `flutter_local_notifications` | Foreground / active-trip alerts |
| `live_activities` | iOS Dynamic Island trip widget |
| `google_sign_in` | OAuth sign-in |
| `url_launcher` | Waze / Google Maps (driver) |

**Versions:** Rider `1.1.0+3`, Driver `1.2.0+6`  
**Dart:** `^3.11.4` · **Flutter:** `>=3.38.4`

**Bundle IDs:**
- Rider: `com.etrikeph.etrikePhUser` (iOS) / `com.etrikeph.etrike_ph_user` (Android)
- Driver: `com.etrikeph.etrikePhDriver` (iOS) / `com.etrikeph.etrike_ph_driver` (Android)

Mobile apps **refuse to run on web** (`kIsWeb` → blocking screen).

### Admin web

| Package | Purpose |
|---------|---------|
| React 19 | UI |
| Vite 6 | Build tool |
| TypeScript 5.8 | Types |
| Tailwind CSS 4 | Styling |
| `@supabase/supabase-js` | Backend client |
| `react-router-dom` 7 | Routing |
| `recharts` | Dashboard charts |
| Vitest | Unit tests |

### Backend

- **Supabase** — PostgreSQL 15, Auth, Realtime, Storage, Edge Functions (Deno)
- **No custom server** — business logic in app clients + RLS + optional Edge Functions

---

## 5. Applications

### 5.1 Rider app (`etrike_ph_user`)

**Entry:** `lib/main.dart` → `goRouterProvider`  
**Initial route:** `/splash`

| Route | Screen |
|-------|--------|
| `/splash` | Bootstrap |
| `/maintenance` | App maintenance block |
| `/onboarding` | First-run onboarding |
| `/login`, `/register` | Auth |
| `/home` | Map + book ride |
| `/trip/:id` | Active trip tracking |
| `/trip/:id/completed` | Rating + completion |
| `/chat/:tripId` | In-trip chat |
| `/history` | Ride history |
| `/profile`, `/settings` | Profile (read-only), settings stub |

**Launch resolution** (`lib/core/rider_launch_route.dart`):
1. Maintenance active → `/maintenance`
2. No session → `/onboarding` or `/login`
3. Active trip in DB → `/trip/:id`
4. Else → `/home`

**Key features:**
- Carmona-biased Places autocomplete (35 km radius)
- Route polyline + fare estimate from `fare_config`
- Custom pickup (book for others)
- Live driver marker via Realtime
- Chat with delivery/read status
- iOS Live Activities (Dynamic Island)
- Post-trip star rating

---

### 5.2 Driver app (`etrike_ph_driver`)

**Entry:** `lib/main.dart`  
**Initial route:** `/splash`

| Route | Screen |
|-------|--------|
| `/splash` | Bootstrap |
| `/maintenance` | Maintenance block |
| `/login`, `/register` | Auth (no plate/model on register) |
| `/welcome` | Pre-approval welcome |
| `/welcome-approved` | Post-approval tour (once; replay in Settings) |
| `/onboarding` | Onboarding hub |
| `/onboarding/apply?step=N` | 7-step document wizard |
| `/training` | 5 modules + quiz (≥80% to pass) |
| `/home` | Map + Online toggle + trip requests |
| `/hub` | Profile hub |
| `/attendance`, `/leave` | HR clock in/out, leave requests |
| `/trip/:id` | Active trip controls |
| `/trip/:id/completed` | Trip completed |
| `/chat/:tripId` | In-trip chat |
| `/history` | Trip history |
| `/settings` | Settings + tour replay |

**Post-auth gate chain** (`lib/core/driver_route_guard.dart`):

```
Register/Login
    → Onboarding docs (100%, OR/CR not required)
    → Welcome (pending approval)
    → Welcome-approved tour (after operator approve)
    → Training quiz
    → Home (still blocked from Online until fleet assigned)
```

**Online eligibility** — ALL must be true:

1. Operator **approved** (`drivers.approval_status = 'approved'`)
2. Onboarding documents **100%**
3. Training **complete** (quiz ≥80% or admin marked onsite)
4. **Fleet unit assigned** via admin

**Trip lifecycle:** `requested` → `accepted` → `ongoing` → `completed`  
Cash flow: End trip → Collect cash → Payment received → Slide to confirm → Complete

**Location broadcast:** every 5s while Online; every 2s during active trip.

---

### 5.3 Admin web (`etrike_ph_admin_web`) — primary operator UI

**Entry:** `src/App.tsx`  
**Deploy:** Vercel via `CasinWorks/SulongRideAdmin`

#### Public routes

| Route | Purpose |
|-------|---------|
| `/login` | Operator sign-in (email or Google) |
| `/invite/:token` | Accept team invite |

#### Protected routes (inside `DashboardLayout`)

| Route | Module | Purpose |
|-------|--------|---------|
| `/` | — | Overview KPIs + chart |
| `/drivers` | drivers | Driver directory |
| `/drivers/:id` | drivers | Driver detail + actions |
| `/drivers/onboarding` | drivers | Onboarding pipeline |
| `/drivers/onboarding/:driverId` | drivers | Single driver onboarding review |
| `/training` | drivers | Training status dashboard |
| `/fleet` | fleet | Fleet unit list |
| `/fleet/:id` | fleet | Unit detail + maintenance log |
| `/pending` | drivers | Pending approval queue |
| `/approved` | drivers | Approved drivers |
| `/revoked` | drivers | Revoked drivers |
| `/attendance` | hr | Month calendar + roster |
| `/leave` | hr | Leave approve/deny |
| `/payroll` | payroll | Deductions, preview, draft, finalize, paid |
| `/fare` | fare | Fare schedule editor |
| `/audit` | — | Searchable audit log |
| `/maintenance` | platform | Schedule/end app maintenance |
| `/team` | platform | Operator invites & roles |

#### Operator roles & access

Defined in `src/lib/operatorPermissions.ts`:

| Role | Write scope |
|------|-------------|
| `super_admin` | Everything + team governance |
| `admin` | Full ops + maintenance/team |
| `viewer` | All pages read-only |
| `hr` | Attendance, leave, payroll write; drivers read-only |
| `dispatcher` | Drivers, fleet, training write; no payroll/fare |

**Admin-only routes:** `/maintenance`, `/team` — redirect others to `/`.

**Danger zone actions** (password confirm): permanent delete driver/fleet, schedule maintenance.

---

### 5.4 Legacy Flutter admin (`etrike_ph_admin`)

Chrome-only operator dashboard. **Superseded by admin web.** Kept for reference; run with `flutter run -d chrome`.

---

### 5.5 Design reference (`design-reference:/`)

Static React prototype for UI exploration. **Not connected to Supabase.** Do not deploy as production.

---

## 6. Database & Supabase

### 6.1 SQL script locations

| Path | Contents |
|------|----------|
| `etrike_ph_user/supabase/` | **Primary** — ~45 scripts: schema, RLS, RBAC, payroll, fleet, onboarding |
| `etrike_ph_driver/supabase/` | Driver MVP fixes, messages, cash payment, stuck trips |

Scripts are run **manually** in Supabase Dashboard → SQL Editor.

### 6.2 Bootstrap order (new environment)

Run in this order:

| # | Script | Purpose |
|---|--------|---------|
| 1 | `fix_carmona_pilot*.sql` | Core schema, fare, operators |
| 2 | `fix_driver_onboarding_complete.sql` | Document uploads + pipeline |
| 3 | `fix_driver_training.sql` | Training + Online gate |
| 4 | `fix_fleet_management.sql` | Fleet CRUD + assignment |
| 5 | `fix_payroll.sql` | Payroll + deduction config |
| 6 | `fix_admin_delete_records.sql` | Delete driver/fleet RPCs |
| 7 | `fix_app_maintenance.sql` | Maintenance mode |
| 8 | `fix_trips_rls.sql` | Book / accept trips |
| 9 | `fix_fare_schedules.sql` | Fare on trips |
| 10 | `fix_operator_rbac.sql` | Operator access |
| 11 | `fix_operator_rbac_viewer.sql` | Viewer read-only RLS |
| 12 | `fix_operator_roles_hr_dispatcher.sql` | HR + dispatcher roles |

Optional: `fix_driver_documents_or_cr_optional.sql`, `fix_messages_realtime.sql`, `fix_trip_cash_payment.sql`, etc.

### 6.3 Core tables

| Table | Purpose |
|-------|---------|
| `users` | Rider profiles, `fcm_token` |
| `drivers` | Driver profiles, `is_online`, location, `approval_status`, `fcm_token` |
| `trips` | Bookings, status, fare, ratings, `cash_payment_confirmed_at` |
| `messages` | In-trip chat |
| `fare_config` | Active fare (₱40 flat pilot) |
| `operators` | Operator accounts + roles |
| `operator_invites` | Team invite tokens |
| `vehicles` | Fleet e-trike units |
| `vehicle_assignments` | Driver ↔ unit (immediate or scheduled) |
| `vehicle_maintenance_logs` | Fleet maintenance history |
| `driver_documents` | Uploaded compliance docs |
| `driver_hiring_pipeline` | Onboarding pipeline state |
| `driver_training` | Training/quiz progress |
| `driver_attendance` | Clock in/out records |
| `leave_requests` | Driver leave |
| `payroll_deduction_configs` | PhilHealth/Pag-IBIG/SSS JSON |
| `cash_advances` | Driver cash advances |
| `payroll_records` | Generated payroll runs |
| `audit_logs` | Operator action audit trail |
| `app_maintenance` | Scheduled maintenance windows |

### 6.4 Realtime publications

Enable in Dashboard → Database → Replication for:

- `trips`
- `drivers`
- `messages`

See `fix_messages_realtime.sql` for chat-specific setup.

### 6.5 Storage

- Bucket: **`driver-documents`** — onboarding uploads (images/PDFs)
- RLS policies in `fix_driver_documents_storage.sql` / onboarding scripts

### 6.6 Edge functions

| Function | Path | Status |
|----------|------|--------|
| `notify-chat-message` | `etrike_ph_user/supabase/functions/notify-chat-message/` | Implemented; **not deployed** (requires Firebase). Skips gracefully if `FIREBASE_SERVICE_ACCOUNT_JSON` unset. |

Deploy (when budget approved):

```bash
cd etrike_ph_user
supabase functions deploy notify-chat-message --no-verify-jwt
```

Then add Database Webhook: `messages` INSERT → `notify-chat-message`.

---

## 7. Authentication & authorization

### 7.1 Rider

1. Email/password or Google OAuth via Supabase Auth
2. `AuthRepository.ensureUserRowExists()` upserts `public.users`
3. No operator involvement
4. Email confirmation **disabled** for MVP
5. Router redirects unauthenticated users to `/login`

### 7.2 Driver

1. Register with email → metadata `role: driver` → upsert `public.drivers`
2. Google sign-in **only** (must register with email first)
3. Must have `drivers` row or forced sign-out
4. Post-auth gates: onboarding → approval → tour → training → home
5. `approval_status`: `pending` | `approved` | `rejected`

### 7.3 Operator (admin web)

1. Sign in at `/login` (email or Google)
2. `ProtectedRoute` checks (`src/App.tsx`):
   - No session → `/login`
   - Has `drivers` row (non-dual-role) → driver block screen
   - No `operators` row → not invited screen
   - `pending` / `revoked` → access pending/revoked pages
   - Approved → dashboard
3. **Invite flow:** admin sends invite → `/invite/:token` → `claimOperatorInvite()`
4. **Dual-role exception:** `VITE_OPERATOR_DUAL_ROLE_EMAIL` env var for test accounts

### 7.4 Row Level Security (RLS)

- Riders: read/write own `users` row and own `trips`
- Drivers: read/write own `drivers` row; trip access when assigned
- Operators: scoped by role via `fix_operator_rbac*.sql` policies
- Viewer role: SELECT only on operational tables

---

## 8. Core business flows

### 8.1 Ride booking (golden path)

```
Rider sets pickup + dropoff (Carmona)
    → Fare estimated from fare_config (₱40)
    → Trip inserted (status: requested)
    → Driver Online receives Realtime event
    → Driver Accept (status: accepted)
    → Driver Arrived → Start (status: ongoing)
    → Driver Complete (cash slide confirm)
    → Trip status: completed, fare recorded
    → Rider rates trip
    → Visible in admin audit + payroll preview
```

See [`tools/RIDE_TEST.md`](../tools/RIDE_TEST.md) for two-phone test steps.

### 8.2 Driver onboarding (admin + app)

```
Driver registers in app
    → 7-step document wizard (OR/CR optional)
    → Admin reviews docs at /drivers/onboarding
    → Admin approves at /pending
    → Admin assigns fleet unit (Employment step)
    → Driver completes training quiz (or admin marks onsite)
    → Driver goes Online
```

**Require documents:** Admin can send approved driver back to pending with reason → driver re-uploads in app.

### 8.3 Payroll (semi-monthly)

```
Admin → /payroll
    → Configure deduction settings (PhilHealth, Pag-IBIG, SSS JSON)
    → Select driver + period → Preview
    → Save draft → Finalize → Mark paid
    → Cash advances deducted from net pay
    → Boundary fee from fleet assignment included
    → Audit log entry created
```

### 8.4 App maintenance

```
Admin → /maintenance
    → Schedule window (start, end, block apps, notify users)
    → Password confirm
    → Before start: banner on rider/driver home
    → During window: full-screen /maintenance block
    → End now: apps restore within ~20s
```

---

## 9. Configuration & secrets

### 9.1 Flutter — `lib/core/constants/keys.dart`

Present in all three Flutter apps:

| Constant | Purpose |
|----------|---------|
| `supabaseUrl` | Supabase project URL |
| `supabaseAnonKey` | Supabase anon key |
| `googleMapsNativeApiKey` | Map tiles (also in `Info.plist` / `AndroidManifest.xml`) |
| `googleMapsWebServicesApiKey` | Places, Geocoding, Directions (rider) |
| `googleOAuthWebClientId` | Google Sign-In |
| `googleOAuthIosClientId` | Google Sign-In iOS |

Google OAuth IDs passed via `--dart-define` at build time.

**Security note:** Keys are hardcoded today. Phase 3 task: move to build-time injection / secure storage before TestFlight.

### 9.2 Admin web — `.env.local`

```env
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
# Optional:
# VITE_OPERATOR_EMAIL_DOMAIN=yourcompany.com
# VITE_OPERATOR_DUAL_ROLE_EMAIL=test@gmail.com
```

Client: `src/lib/supabase.ts`

### 9.3 Google Maps — two-key setup

| Key type | Restrictions | Used for |
|----------|--------------|----------|
| **Native** | iOS bundle ID + Android package + SHA-1 | Map tiles in app |
| **Web services** | None (server-side style calls from app) | Places autocomplete, Directions |

Grey map troubleshooting: see `etrike_ph_user/README.md`.

### 9.4 Notion sync — `tools/notion-sync/.env`

```env
NOTION_API_KEY=secret_...
NOTION_PARENT_PAGE_ID=...
```

Run: `python sync.py` to push `Sulong_Ride_Project_Tracker.csv` to Notion.

---

## 10. Realtime & notifications

### Current approach (pilot — no Firebase required)

| Mechanism | When it works |
|-----------|---------------|
| **Supabase Realtime** | App open or background with connection — trip updates, chat, new requests |
| **Local notifications** | Realtime event + active trip + chat not open → `flutter_local_notifications` |
| **iOS Live Activities** | Dynamic Island trip status widget |

This covers the Carmona pilot when drivers stay **Online with app open**.

### FCM / Firebase (deferred)

**Status:** Deferred pending budget approval (Jul 5, 2026).

| Component | State |
|-----------|-------|
| `fcm_token` columns | ✅ In DB |
| `saveFcmToken()` in auth repos | ✅ Defined (not called at startup) |
| `firebase_messaging` package | ❌ Not in pubspec |
| `GoogleService-Info.plist` / `google-services.json` | ❌ Not in repo |
| Edge function `notify-chat-message` | ✅ Code ready; not deployed |
| Firebase project | ❌ Not created |

**Why defer:** FCM itself is free, but project budget not approved yet. Realtime + local notifications sufficient for pilot.

**When to add:** Before scaling beyond pilot, or when lock-screen alerts with app killed are required.

**Architecture when enabled:**

```
DB event (new message/trip)
    → Supabase webhook
    → Edge Function
    → Read fcm_token from Supabase
    → FCM API → device
```

Supabase orchestrates; Firebase delivers. There is no Supabase-only mobile push.

---

## 11. Third-party services

| Service | Status | Purpose |
|---------|--------|---------|
| **Supabase** | Active | Auth, DB, Realtime, Storage |
| **Google Maps (native)** | Active | Map tiles |
| **Google Places / Directions** | Active | Search, routes, ETA |
| **Google Sign-In** | Active | OAuth (rider, driver, admin) |
| **Firebase / FCM** | Deferred | Background push |
| **Waze / Google Maps app** | Active | Driver external navigation |
| **Vercel** | Active | Admin web hosting |
| **Notion** | Active | Project tracker sync |
| **GCash** | Not started (Phase 2) | Digital payments |
| **Apple Developer** | Active | iOS builds, TestFlight (planned Nov) |

---

## 12. Deployment & environments

### 12.1 Admin web (Vercel)

| Branch | Environment |
|--------|-------------|
| `dev` | Dev preview |
| `UAT` | UAT |
| `main` | Production |

Repo: `CasinWorks/SulongRideAdmin`  
Config: `etrike_ph_admin_web/vercel.json` (SPA rewrite)  
Build: `npm run build` → `dist/`

### 12.2 Mobile apps

No CI/CD in repo. Manual builds:

```bash
# Driver
cd etrike_ph_driver
flutter build ios --release
flutter build apk --release   # Android

# Rider
cd etrike_ph_user
flutter build ios --release
flutter build apk --release
```

Install to device:

```bash
flutter install -d <DEVICE_ID>
```

### 12.3 Supabase

Single project for all environments today. SQL scripts applied manually per checklist sign-off (Dev, UAT, Prod — all verified Jul 5, 2026).

### 12.4 Keeping Dev / UAT / Prod the same

**Goal:** Dev, UAT, and Prod should behave identically. The only differences should be the **deployment URL** and (eventually) **separate Supabase projects**.

#### Source of truth

- **Supabase schema/RLS source of truth:** SQL scripts in `etrike_ph_user/supabase/` (plus any driver-specific scripts in `etrike_ph_driver/supabase/`)
- **Execution order (baseline bundle):** the 12 scripts listed in [`tools/DEV_UAT_TEST_CHECKLIST.md`](../tools/DEV_UAT_TEST_CHECKLIST.md)
- **Admin deployments:** Vercel branches `dev`, `UAT`, `main`

#### If you are still using a single Supabase project

You are already “in sync” at the database level because Dev/UAT/Prod all point to the same Supabase project. In this setup, consistency mainly means:

- **Deploy the same commit** (or keep changes merged) across `dev` → `UAT` → `main`
- **Do not run one-off SQL changes** in Supabase without committing them to a `.sql` file in the repo

#### If/when you split Supabase per environment

To keep environments identical:

- **Run the same SQL bundle** (same scripts, same order) on Dev, UAT, and Prod projects
- **Re-run `notify pgrst, 'reload schema';`** after schema changes
- **Smoke test pricing:** `select * from public.effective_fare_config;` returns 1 row
- **Smoke test app gating:** driver Online gates (docs/training/approval/fleet) still block correctly

#### Quick “same-ness” checklist

- **Schema:** all 12 baseline SQL scripts applied
- **Policies:** operator RBAC scripts applied; viewer/hr/dispatcher behave correctly
- **Fare:** `effective_fare_config` is `security_invoker=true` (no Security Definer view)
- **Realtime:** publications enabled for `trips`, `drivers`, `messages`
- **Storage:** `driver-documents` bucket exists with correct policies

---

## 13. Testing & QA

### Documents

| File | Purpose |
|------|---------|
| [`tools/DEV_UAT_TEST_CHECKLIST.md`](../tools/DEV_UAT_TEST_CHECKLIST.md) | Dev / UAT / Prod sign-off (D1–D33, U1–U14, P1–P6) |
| [`tools/FULL_TEST_MATRIX.md`](../tools/FULL_TEST_MATRIX.md) | Detailed QA matrix with bad routes |
| [`tools/RIDE_TEST.md`](../tools/RIDE_TEST.md) | Two-phone E2E ride flow |

### QA status (Jul 5, 2026)

- ✅ Dev admin web (D1–D14a)
- ✅ Driver app iOS (D14–D25)
- ✅ Rider + ride E2E iOS (D26–D29)
- ✅ Android rider + driver (D30–D33)
- ✅ UAT critical path (U1–U14)
- ✅ Prod smoke (P1–P6)
- ✅ All 12 Supabase SQL scripts

**Recommended devices:** iPhone 16 (driver), iPhone 12 Pro Max (rider), Android device.

### Unit tests

- Admin web: Vitest in `etrike_ph_admin_web/src/**/*.test.ts`
- Flutter: default widget tests only

---

## 14. Roadmap & phases

From `Sulong_Ride_Project_Tracker.csv` (97 tasks):

### Phase 0 — MVP ✅ (100%)

Rider/driver auth, maps, booking, tracking, chat, trip lifecycle, cash payment, iOS Live Activities, core Supabase, two-phone E2E.

### Phase 1 — Ops platform (~95%)

**Done:** Admin web, RBAC, onboarding, fleet, payroll, training, attendance, leave, audit, maintenance, Android QA, full checklist sign-off.

**Deferred:** FCM push (budget).

**Optional:** Trip list dashboard (P2, not started).

### Phase 2 — Payments (Sep–Oct 2026)

GCash hold/capture/release, `trips.payment_status`, cancellation rules/fees, rider profile edit.

### Phase 3 — Production readiness (Nov 2026)

Move secrets out of `keys.dart`, TestFlight distribution, production QA.

### Phase 4 — Carmona pilot (Dec 2026)

Recruit 5 drivers, live pilot launch.

### Progress snapshot (Jul 5, 2026)

| Metric | Value |
|--------|-------|
| Overall project | **84%** (81/97 tasks) |
| Phase 0 + 1 rollout | **95%** (79/83) |
| Admin web | **95%** |
| Rider + driver apps | **~90%** each |

### Immediate next steps (no budget required)

1. Recruit and onboard 5 Carmona drivers
2. TestFlight when Apple pipeline ready
3. Continue ops using Realtime + local notifications

### Blocked on budget

1. FCM / Firebase setup
2. GCash merchant integration

---

## 15. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Driver can't go Online | Missing gate | Complete training; get admin approval; assign fleet unit; run `fix_driver_training.sql` |
| Onboarding upload 42501 | RLS | Run `fix_driver_onboarding_complete.sql` |
| Payroll page error | Missing schema | Run `fix_payroll.sql` |
| Fleet assign fails | Missing schema | Run `fix_fleet_management.sql` |
| No trip requests | Driver offline or wrong area | Driver Online + GPS on + Carmona service area |
| Admin can't preview docs | Storage RLS | Check `driver-documents` bucket + policies |
| Grey map | Wrong API key | Verify native key in `Info.plist` / `AndroidManifest.xml` matches `keys.dart` |
| Chat not realtime | Publication missing | Run `fix_messages_realtime.sql`; enable Replication |
| Maintenance page error | Missing schema | Run `fix_app_maintenance.sql` |
| Operator can't access page | RBAC | Run `fix_operator_rbac.sql` + viewer/HR/dispatcher scripts |

---

## 16. Related documents

| Document | Location |
|----------|----------|
| Monorepo README | [`../README.md`](../README.md) |
| **Tutorial handbook** | [`TUTORIAL_HANDBOOK.md`](TUTORIAL_HANDBOOK.md) |
| Rider app README | [`../etrike_ph_user/README.md`](../etrike_ph_user/README.md) |
| Driver app README | [`../etrike_ph_driver/README.md`](../etrike_ph_driver/README.md) |
| Admin web README | [`../etrike_ph_admin_web/README.md`](../etrike_ph_admin_web/README.md) |
| Google Sign-In setup | [`../etrike_ph_user/GOOGLE_SIGNIN.md`](../etrike_ph_user/GOOGLE_SIGNIN.md) |
| FCM edge function | [`../etrike_ph_user/supabase/functions/notify-chat-message/README.md`](../etrike_ph_user/supabase/functions/notify-chat-message/README.md) |
| Notion sync | [`../tools/notion-sync/README.md`](../tools/notion-sync/README.md) |
| Project tracker CSV | [`../Sulong_Ride_Project_Tracker.csv`](../Sulong_Ride_Project_Tracker.csv) |

---

*For questions or updates to this guide, edit `docs/PROJECT_GUIDE.md` and sync the tracker CSV to Notion after milestone changes.*
