# Sulong Ride — End-to-end ride test (staging / dev)

**Full Dev & UAT checklist:** see [`DEV_UAT_TEST_CHECKLIST.md`](./DEV_UAT_TEST_CHECKLIST.md) (training, fleet, payroll, onboarding, and ride E2E).

Use this document for the **ride booking flow** detail. All apps must point at the **same Supabase project** (`litrignthoxsdvsaheev` / dev).

## Prerequisites

### 1. Supabase SQL (run once in SQL Editor)

| Script | Purpose |
|--------|---------|
| `fix_carmona_pilot*.sql` | Core tables, drivers, trips |
| `fix_driver_onboarding_complete.sql` | Driver onboarding RLS + storage |
| `fix_driver_training.sql` | Training table + RLS |
| `fix_fleet_management.sql` | Fleet units, assignments, maintenance logs |
| `fix_payroll.sql` | Payroll records, cash advances, deduction config |
| `fix_trips_rls.sql` | Trip request/accept policies |
| `fix_fare_schedules.sql` | Fare calculation |
| `fix_trip_ratings.sql` | Post-ride ratings |

### 2. Test accounts

| Role | How to create | Notes |
|------|---------------|-------|
| **Operator** | Admin web invite or `fix_operator_rbac.sql` | Must be `approval_status = approved` |
| **Driver** | Driver app Register → complete onboarding + **training** → admin approves + assigns unit | `approval_status = approved`, training `completed` |
| **Rider** | Rider app Register | Email confirm off in Supabase Auth for MVP |

### 3. Test driver must be activatable

- [ ] Documents checklist 100% (no OR/CR required — company fleet)
- [ ] Rider protocol training **completed** (online quiz ≥80% or admin marked onsite)
- [ ] Operator **approved** driver in admin
- [ ] **Assigned e-trike unit** in onboarding Employment step
- [ ] Driver app: post-approval welcome tour done (optional)

### 4. Location & maps

- Driver and rider devices need **location permission**
- Google Maps keys in `keys.dart` + native iOS/Android config
- Test in **Carmona** service area (see `map_regions.dart`)

### 5. Payment method

- MVP uses **cash** fare in app; wallet/card if configured in rider app
- No Stripe required for basic E2E if fare is recorded on trip completion

---

## E2E flow (two physical devices recommended)

### A. Driver goes online

1. Driver app → sign in → complete training if prompted
2. **Driver Hub → Time In** (HR, optional for trip test)
3. **Home map → toggle Online**
4. Confirm no snackbar errors (RLS / training / approval)

### B. Rider books

1. Rider app → sign in → set pickup + dropoff in Carmona
2. Tap **Book ride**
3. Trip row created in Supabase `trips` with status `requested`

### C. Driver accepts

1. Driver receives incoming trip sheet (app foreground + Online)
2. **Accept** → navigates to active trip screen
3. Status: `accepted` → `driver_arrived` → `in_progress`

### D. Complete ride

1. Driver taps through trip milestones (arrived, start, complete)
2. Rider sees live status updates (realtime)
3. Fare computed from `fare_schedules` / trip record
4. Trip status `completed`; `completed_at` set

### E. Rating

1. Rider: rate trip on completion screen
2. Driver: view rating in Hub / history

---

## Verify in admin web

- **Drivers** → driver online flag
- **Audit logs** → trip lifecycle events
- **Training** → driver training completed
- Supabase **Table Editor** → `trips` row statuses and fare

---

## Common blockers

| Symptom | Fix |
|---------|-----|
| Driver can't go Online | Run training SQL; complete training; check approval |
| RLS 42501 on trips | Run `fix_trips_rls.sql` |
| No incoming requests | Driver Online + location + rider in range |
| Documents stuck | Run `fix_driver_onboarding_complete.sql` |
| Admin can't see uploads | Storage bucket `driver-documents` public read + RLS |

---

## Automated tests (future)

- Unit: fare calculation, checklist %, training quiz score
- Integration: Supabase trip state machine with test JWT
- Manual E2E above remains source of truth until CI devices are wired
