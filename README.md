# Sulong Ride Apps

**Smart Tricycle apps System** — ride-hailing platform for e-trike operators in Carmona, Cavite (Philippines).

This monorepo contains the **rider app**, **driver app**, **operator admin web**, and shared Supabase backend for the July 2026 Carmona pilot rollout.

---

## Repository structure

| Folder | App | Stack | Purpose |
|--------|-----|-------|---------|
| [`etrike_ph_user/`](etrike_ph_user/) | Rider | Flutter (iOS/Android) | Book rides, live tracking, chat, history, ratings |
| [`etrike_ph_driver/`](etrike_ph_driver/) | Driver | Flutter (iOS/Android) | Go online, accept trips, onboarding, training, HR |
| [`etrike_ph_admin_web/`](etrike_ph_admin_web/) | Admin | React 19 + Vite | Operator dashboard (primary admin UI) |
| [`etrike_ph_admin/`](etrike_ph_admin/) | Admin (legacy) | Flutter Web | Superseded by admin web; Chrome-only |
| [`design-reference:/`](design-reference:/) | Prototype | React + Vite | UI reference only — not connected to backend |
| [`tools/`](tools/) | QA & sync | Markdown + Python | Test checklists, Notion sync |
| [`docs/`](docs/) | Documentation | Markdown | [`PROJECT_GUIDE.md`](docs/PROJECT_GUIDE.md) · [`TUTORIAL_HANDBOOK.md`](docs/TUTORIAL_HANDBOOK.md) |

---

## Quick start

### Prerequisites

- Flutter SDK ≥ 3.38 (`dart ^3.11`)
- Node.js 18+ (admin web)
- Supabase project access
- Google Maps API keys (native + web services)
- Xcode / Android Studio for mobile builds

### Admin web (local)

```bash
cd etrike_ph_admin_web
cp .env.example .env.local   # set VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install && npm run dev
```

### Mobile apps

```bash
cd etrike_ph_user   # or etrike_ph_driver
flutter pub get
flutter run
```

Configure Supabase and Google keys in `lib/core/constants/keys.dart` (see [Configuration](docs/PROJECT_GUIDE.md#9-configuration--secrets)).

### Supabase SQL (new environment)

Run the 12 core scripts in order — see [`docs/PROJECT_GUIDE.md` § Database](docs/PROJECT_GUIDE.md#6-database--supabase) or [`tools/DEV_UAT_TEST_CHECKLIST.md`](tools/DEV_UAT_TEST_CHECKLIST.md).

---

## Environments

| Environment | Admin branch | Deploy |
|-------------|--------------|--------|
| Dev | `dev` | Vercel preview |
| UAT | `UAT` | Vercel UAT URL |
| Prod | `main` | Production admin URL |

**Current active environment:** **Dev** (`dev`)

**Supabase:** single project `litrignthoxsdvsaheev` (Dev/UAT/Prod share DB until split).

Mobile apps point at Supabase via `keys.dart` unless built with overrides.

---

## Documentation

| Document | Contents |
|----------|----------|
| **[`docs/PROJECT_GUIDE.md`](docs/PROJECT_GUIDE.md)** | Full project documentation — architecture, apps, auth, database, ops, deployment, roadmap |
| **[`docs/TUTORIAL_HANDBOOK.md`](docs/TUTORIAL_HANDBOOK.md)** | **User tutorials** — step-by-step guides for rider, driver, and admin web |
| [`tools/DEV_UAT_TEST_CHECKLIST.md`](tools/DEV_UAT_TEST_CHECKLIST.md) | Dev / UAT / Prod QA sign-off checklist |
| [`tools/FULL_TEST_MATRIX.md`](tools/FULL_TEST_MATRIX.md) | Detailed manual QA matrix (3 apps) |
| [`tools/RIDE_TEST.md`](tools/RIDE_TEST.md) | Two-phone ride E2E flow |
| [`Sulong_Ride_Project_Tracker.csv`](Sulong_Ride_Project_Tracker.csv) | Task tracker (synced to Notion) |

Per-app READMEs: [`etrike_ph_user/README.md`](etrike_ph_user/README.md), [`etrike_ph_driver/README.md`](etrike_ph_driver/README.md), [`etrike_ph_admin_web/README.md`](etrike_ph_admin_web/README.md).

---

## Current status (Jul 5, 2026)

- **Phase 0 + 1:** ~95% complete — iOS + Android QA passed on `dev`, `UAT`, `main`
- **Pilot blockers:** driver recruitment, TestFlight, GCash (Phase 2)
- **Deferred:** FCM push notifications (pending budget; Realtime + local notifications used for pilot)

See [`docs/PROJECT_GUIDE.md` § Roadmap](docs/PROJECT_GUIDE.md#12-roadmap--phases) for details.
