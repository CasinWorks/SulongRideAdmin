# Sulong Ride — Dev & UAT test plan

Use this checklist for the **July 2026 rollout**: OR/CR optional, rider training, fleet assignment, payroll (admin), post-approval tour, and ride E2E.

| Environment | Admin web branch | Deploy | Supabase (current) |
|-------------|------------------|--------|---------------------|
| **Dev** | `dev` | Vercel preview / dev URL | `litrignthoxsdvsaheev` |
| **UAT** | `UAT` | Vercel UAT URL | Same project until UAT DB is split |
| **Prod** | `main` | Production admin URL | Same project until prod DB is split |

**Mobile apps** (driver + rider) are installed from the monorepo (`EtrikeApp`) and always point at `keys.dart` Supabase URL unless you build with overrides.

**Two phones recommended:** one driver (iPhone 16), one rider (e.g. iPhone 12 Pro Max).

---

## 0. One-time Supabase SQL (Dev / UAT / Prod)

Run in **SQL Editor** for each Supabase project you test against. Order matters for new environments.

| # | Script | Required for |
|---|--------|----------------|
| 1 | `fix_carmona_pilot*.sql` | Core schema |
| 2 | `fix_driver_onboarding_complete.sql` | Onboarding uploads + pipeline |
| 3 | `fix_driver_training.sql` | Online training + Online gate |
| 4 | `fix_fleet_management.sql` | Fleet CRUD + unit assignment |
| 5 | `fix_payroll.sql` | Payroll + deduction config |
| 6 | `fix_admin_delete_records.sql` | Admin delete driver / fleet RPCs |
| 7 | `fix_app_maintenance.sql` | App maintenance mode |
| 8 | `fix_trips_rls.sql` | Book / accept trips |
| 9 | `fix_fare_schedules.sql` | Fare on trips |
| 10 | `fix_operator_rbac.sql` | Admin operator access |
| 11 | `fix_operator_rbac_viewer.sql` | Viewer read-only RLS |
| 12 | `fix_operator_roles_hr_dispatcher.sql` | HR + dispatcher roles |

Optional: `fix_driver_documents_or_cr_optional.sql` (documentation only if OR/CR already optional in app).

**Sign-off:** [x] Dev SQL run &nbsp; [x] UAT SQL run &nbsp; [x] Prod SQL run

---

## 1. Dev testing

### 1A. Admin web (after `dev` branch deploy)

| # | Test | Steps | Pass |
|---|------|-------|------|
| D1 | Login | Operator sign-in (email or Google) | [x] |
| D2 | Document viewer | Onboarding → driver → preview image/PDF uploads | [x] |
| D3 | OR/CR not required | Onboarding checklist shows no OR/CR; 100% without them | [x] |
| D4 | Fleet — create unit | Fleet → add e-trike, set boundary fee | [x] |
| D5 | Fleet — assign driver | Driver detail or onboarding Employment → assign unit (now or scheduled) | [x] |
| D6 | Fleet — maintenance log | Fleet → unit → log maintenance | [x] |
| D7 | Training — online | Training tab shows driver after quiz complete in app | [x] |
| D8 | Training — onsite | Mark onsite complete on driver detail | [x] |
| D9 | Driver approval | Pending → Approve; Revoke / re-approve | [x] |
| D10 | Payroll — settings | Payroll → Deduction settings → save PhilHealth/Pag-IBIG/SSS JSON | [x] |
| D11 | Payroll — generate | Pick driver + period → Preview → Save draft → Finalize → Mark paid | [x] |
| D12 | Cash advance | Issue advance → finalize payroll → balance reduced | [x] |
| D13 | Audit logs | Trip / payroll / fleet actions appear | [x] |
| D14a | Viewer read-only | Login as viewer → banner; approve/payroll/fare disabled; `/maintenance` blocked | [x] |

### 1B. Driver app (iPhone 16 — latest build)

| # | Test | Steps | Pass |
|---|------|-------|------|
| D14 | Register / login | New driver or existing test account | [x] |
| D15 | No plate on register | Registration has no plate/model fields | [x] |
| D16 | Onboarding wizard | Upload required docs (no OR/CR); progress saves | [x] |
| D17 | Assigned unit display | Employment step shows company-assigned e-trike (read-only) | [x] |
| D18 | Rider training | Step 6: 5 modules + quiz ≥80% | [x] |
| D19 | Online blocked pre-training | Toggle Online before training → blocked with message | [x] |
| D20 | Online blocked pre-approval | Training done but pending approval → blocked | [x] |
| D21 | Post-approval tour | After approval, welcome tour once; Settings → App tour replays | [x] |
| D22 | Go Online | Approved + trained + assigned unit → Online succeeds | [x] |
| D23 | Time in/out | HR attendance clock in/out | [x] |
| D24 | Accept trip | See request → Accept → lifecycle to complete | [x] |
| D25 | External nav | Waze / Google Maps to pickup/dropoff | [x] |

### 1C. Rider app + ride E2E (Dev)

See [`RIDE_TEST.md`](./RIDE_TEST.md) for full flow. Summary:

| # | Test | Pass |
|---|------|------|
| D26 | Book ride in Carmona | [x] |
| D27 | Live tracking + chat | [x] |
| D28 | Trip completes + fare recorded | [x] |
| D29 | Admin shows trip / driver online | [x] |

**Dev sign-off:** Date: **2026-07-05** — all tests passed (iOS + Android)

### 1D. Android (rider + driver)

| # | Test | Pass |
|---|------|------|
| D30 | Rider app — login, map, book ride | [x] |
| D31 | Driver app — login, Online, accept trip | [x] |
| D32 | Maps + location on Android | [x] |
| D33 | Trip lifecycle completes on Android | [x] |

**Android sign-off:** Date: **2026-07-05** — working properly on device

---

## 2. UAT testing

Repeat **critical path** on UAT admin deploy (`UAT` branch). Same Supabase until a dedicated UAT project exists.

### UAT must-pass (regression + new features)

| # | Area | Test | Pass |
|---|------|------|------|
| U1 | Auth | Operator login; driver/rider login | [x] |
| U2 | Onboarding | Full new driver: docs → training → admin approve → assign unit | [x] |
| U3 | Training gate | Driver cannot go Online until training complete | [x] |
| U4 | Fleet | Assign/reassign unit; boundary fee visible in payroll preview | [x] |
| U5 | Ride E2E | Two-phone book → accept → complete → fare in Supabase | [x] |
| U6 | Payroll | Generate semi-monthly payroll for driver with trips + attendance | [x] |
| U7 | Cash advance | Deduction on finalize; cannot over-deduct net pay | [x] |
| U8 | Deduction config | Change Pag-IBIG cap in settings → preview reflects change | [x] |
| U9 | Revoke driver | Revoked driver blocked from Online | [x] |
| U10 | Document viewer | Admin previews all uploaded doc types | [x] |

### UAT nice-to-have

| # | Test | Pass |
|---|------|------|
| U11 | Scheduled fleet assignment | Future effective date applies on that date | [x] |
| U12 | Onsite training path | Admin marks onsite without app quiz | [x] |
| U13 | Leave / attendance admin | HR pages load and actions work | [x] |
| U14 | Fare schedule | Active schedule used on new trips | [x] |

**UAT sign-off:** Date: **2026-07-05** — all tests passed (`UAT` branch)

---

## 3. Prod smoke test (after `main` deploy)

Minimal smoke before wider pilot:

| # | Test | Pass |
|---|------|------|
| P1 | Admin login | [x] |
| P2 | View drivers + onboarding | [x] |
| P3 | Fleet list loads | [x] |
| P4 | Training tab loads | [x] |
| P5 | Payroll tab loads (after SQL) | [x] |
| P6 | Driver Online + one test trip (staging accounts only) | [x] |

**Prod smoke sign-off:** Date: **2026-07-05** — all tests passed (`main` branch)

---

## Test accounts (Dev / UAT)

| Role | Notes |
|------|--------|
| Operator | Approved in `operators`; use admin invite or RBAC SQL |
| Driver | Register in app → complete onboarding + training → admin approves + assigns unit |
| Rider | Register in rider app; email confirm off for MVP |

---

## Common blockers

| Symptom | Fix |
|---------|-----|
| Driver can't go Online | Run `fix_driver_training.sql`; complete training; approve driver; assign fleet unit |
| Onboarding upload 42501 | Run `fix_driver_onboarding_complete.sql` |
| Payroll page empty / error | Run `fix_payroll.sql` |
| Fleet assign fails | Run `fix_fleet_management.sql` |
| No trip requests | Driver Online, location on, Carmona service area |
| Admin can't see docs | Storage bucket `driver-documents` + RLS |

---

## Build / install reference

```bash
# Driver app → iPhone 16 (wireless)
cd etrike_ph_driver
flutter build ios --release
xcrun devicectl device install app --device <DEVICE_ID> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <DEVICE_ID> com.etrikeph.etrikePhDriver
```

Admin web: push `dev` / `UAT` / `main` on `CasinWorks/SulongRideAdmin` → Vercel auto-deploy.
