# Sulong Ride — Full test matrix (3 apps)

Use this as the **master manual QA guide** for **Admin web**, **Driver app**, and **Rider app**.

| Document | Purpose |
|----------|---------|
| **This file** (`tools/FULL_TEST_MATRIX.md`) | Steps, inputs, expected results, good + bad routes |
| [`DEV_UAT_TEST_CHECKLIST.md`](./DEV_UAT_TEST_CHECKLIST.md) | Dev / UAT / Prod sign-off checklist (shorter) |
| [`RIDE_TEST.md`](./RIDE_TEST.md) | Ride booking E2E detail (two-phone flow) |

**Supabase project (current):** `litrignthoxsdvsaheev`  
**Service area:** Carmona, Cavite (center ~ `14.3132, 121.0565`)  
**Recommended devices:** iPhone 16 = driver, second phone = rider (or swap for single-phone partial tests)

---

## App route maps (“where to go”)

### Admin web (browser)

| Route | Screen | Who can access |
|-------|--------|----------------|
| `/login` | Operator login | Public |
| `/invite/:token` | Accept team invite | Invited user |
| `/` | Overview | Approved operator |
| `/drivers` | Driver list | Operator |
| `/drivers/:id` | Driver detail | Operator |
| `/drivers/onboarding` | Onboarding pipeline | Operator |
| `/drivers/onboarding/:driverId` | Single driver onboarding | Operator |
| `/training` | Training status | Operator |
| `/fleet` | Fleet units | Operator |
| `/fleet/:id` | Unit detail + maintenance log | Operator |
| `/pending` | Pending approval | Operator |
| `/approved` | Approved drivers | Operator |
| `/revoked` | Revoked drivers | Operator |
| `/attendance` | HR attendance | Operator |
| `/payroll` | Payroll + deductions | Operator |
| `/leave` | Leave requests | Operator |
| `/fare` | Fare schedules | Operator |
| `/audit` | Audit logs | Operator |
| `/maintenance` | App maintenance mode | **Admin / super_admin only** |
| `/team` | Operator team | **Admin / super_admin only** |

**Bad routes (admin):**

| Try | Expected |
|-----|----------|
| Open `/maintenance` as **viewer** operator | Redirect to `/` |
| Open `/team` as viewer | Redirect to `/` |
| Login with driver account email | “Driver account” block screen |
| Login with non-invited email | “Not invited” screen |
| Login with revoked operator | Pending / revoked access page |

---

### Driver app (screens)

| Route | Screen |
|-------|--------|
| `/splash` | Boot |
| `/login`, `/register` | Auth |
| `/onboarding`, `/onboarding/apply?step=N` | Document wizard |
| `/training` | Rider protocol training + quiz |
| `/welcome-approved` | Post-approval tour |
| `/home` | Map + Online toggle + trip requests |
| `/hub` | Profile, stats, shortcuts |
| `/attendance`, `/leave` | HR |
| `/history` | Trip history |
| `/trip/:id` | Active trip |
| `/trip/:id/completed` | Trip completed |
| `/chat/:tripId` | In-trip chat |
| `/settings` | Settings + replay tour |
| `/maintenance` | **Block screen** when maintenance active |

**Bad routes (driver — eligibility gates):**

Driver cannot go **Online** or **Accept trips** until ALL are true:

1. Operator **approved**
2. Onboarding documents **100%** (OR/CR not required)
3. Training **completed** (quiz ≥ 80% or admin marked onsite)
4. **Fleet unit assigned**

| State | Action | Expected |
|-------|--------|----------|
| Pending approval | Toggle Online | Blocked — pending approval message |
| Revoked | Toggle Online | Blocked — not approved message |
| Docs incomplete | Toggle Online | Blocked — complete documents message |
| Training incomplete | Toggle Online | Blocked — complete training message |
| No fleet unit | Toggle Online | Blocked — no e-trike assigned message |
| Offline / not Online | Rider books | Driver does **not** receive request |
| Ineligible | Incoming trip (if any) | Accept disabled / sheet not shown |
| Maintenance **active** + block on | Open app | `/maintenance` full-screen block |
| Maintenance **scheduled** + notify on | Open home | Banner with start time |

---

### Rider app (screens)

| Route | Screen |
|-------|--------|
| `/splash` | Boot |
| `/login`, `/register` | Auth |
| `/onboarding` | First-run onboarding |
| `/home` | Map + book ride |
| `/trip/:id` | Active trip tracking |
| `/trip/:id/completed` | Completion + rating |
| `/chat/:tripId` | In-trip chat |
| `/history` | Ride history |
| `/profile`, `/settings` | Account |
| `/maintenance` | **Block screen** when maintenance active |

**Bad routes (rider):**

| Try | Expected |
|-----|----------|
| Book with no pickup/dropoff | Validation error / cannot book |
| Book outside Carmona area | No drivers / geocode bias limits results |
| Book while maintenance **active** + block on | Block screen (cannot reach home booking) |
| No driver Online nearby | Request may sit in `requested` or timeout |
| Logged out | Redirect to `/login` (except splash/onboarding) |

---

## Test accounts & inputs

Create **separate accounts** for each role. Do not reuse the same email across roles.

| Role | Sample inputs | Notes |
|------|---------------|-------|
| **Super admin** | `admin+test@yourdomain.com` + password | `operators.role = super_admin`, approved |
| **Viewer operator** | `viewer+test@yourdomain.com` | For negative admin route tests |
| **Driver** | `driver+test@yourdomain.com`, name `Test Driver`, phone `09XX…` | Register in driver app |
| **Rider** | `rider+test@yourdomain.com`, name `Test Rider` | Register in rider app |

**Fleet unit (admin inputs):**

| Field | Example |
|-------|---------|
| Plate | `CVM-1234` |
| Model | `BEMAC e-trike` |
| Boundary fee | `50` |
| Status | `available` |

**Ride booking (rider inputs — Carmona):**

| Field | Example |
|-------|---------|
| Pickup | `Carmona Public Market` or pin near `14.3132, 121.0565` |
| Dropoff | `Carmona City Hall` or nearby barangay |
| Payment | Cash (MVP default) |

**Maintenance schedule (admin — `/maintenance`):**

| Field | Example |
|-------|---------|
| Title | `Scheduled maintenance` |
| Message | `We are upgrading Sulong Ride. Please try again later.` |
| Starts | Now + 5 min (for notify test) or Now (for immediate block test) |
| Ends | Starts + 2 hours |
| Block apps | ✅ on for halt test |
| Notify users | ✅ on for banner test |
| Password | Your operator password (required on confirm) |

---

## SQL prerequisites (run once per Supabase project)

Run in order in **SQL Editor**:

1. `fix_carmona_pilot*.sql`
2. `fix_driver_onboarding_complete.sql`
3. `fix_driver_training.sql`
4. `fix_fleet_management.sql`
5. `fix_payroll.sql`
6. `fix_admin_delete_records.sql`
7. `fix_app_maintenance.sql`
8. `fix_trips_rls.sql`
9. `fix_fare_schedules.sql`
10. `fix_operator_rbac.sql`
11. `fix_operator_rbac_viewer.sql` — viewer read-only RLS
12. `fix_operator_roles_hr_dispatcher.sql` — hr + dispatcher roles

---

## Master test matrix

**Legend:** ✅ = expected pass &nbsp;|&nbsp; ❌ = expected fail / block

### A. Admin web

| ID | Feature | Steps | Inputs | Expected ✅ | Bad route | Expected ❌ |
|----|---------|-------|--------|-------------|-----------|-------------|
| A1 | Login | `/login` → sign in | Valid operator creds | Dashboard loads | Wrong password | Error message, stay on login |
| A2 | Viewer RBAC | Login as viewer → open `/maintenance` | Viewer account | Redirect `/` | — | — |
| A3 | Team invite | `/team` → invite | Email + role | Invite sent / link works | Viewer opens `/team` | Redirect `/` |
| A4 | Onboarding review | `/drivers/onboarding/:id` | Open each doc | Image/PDF previews load | Missing storage policy | Preview fails / 403 |
| A5 | Approve driver | `/pending` → Approve | Test driver | Moves to Approved; driver can proceed | Approve without docs | Driver still blocked in app |
| A6 | Revoke driver | `/approved` → Revoke | Test driver | Status rejected; app blocks Online | — | — |
| A6b | Require documents | Driver detail or `/approved` → **Require documents** | Reason + optional doc checkboxes | Driver → pending, offline; appears on `/pending` | Viewer / HR tries action | Button hidden |
| A7 | Assign fleet | Driver detail or onboarding Employment | Unit `CVM-1234` | Assigned unit shows in driver app | Assign retired unit | Error or unit unavailable |
| A8 | Training onsite | Driver detail → mark onsite | Test driver | Training complete without app quiz | — | — |
| A9 | Payroll settings | `/payroll` → Deduction settings | Edit Pag-IBIG JSON → Save | Preview uses new values | Invalid JSON | Validation error |
| A10 | Payroll run | Preview → Draft → Finalize → Paid | Driver + semi-month period | Record saved; audit log entry | Finalize twice carelessly | Idempotency / error handled |
| A11 | Cash advance | Issue advance → payroll | Amount `500` | Deducted from net pay | Advance > net pay | Blocked / error |
| A12 | Audit | `/audit` | After A5, A10 | Actions listed with actor + summary | — | — |
| A13 | Maintenance schedule | `/maintenance` → Schedule | Starts +5m, Ends +2h, block+notify on, password | Window in history; live status “Upcoming” | Wrong password | Modal error, no schedule |
| A14 | Maintenance notify | Wait until 5m before start | — | Rider + driver home show **banner** | Notify off | No banner |
| A15 | Maintenance block | Wait until start time | — | Both apps → `/maintenance` block screen | Block off | Apps usable; optional message only |
| A16 | Maintenance end | Admin → End now + password | Open window | Apps unblock within ~20s | — | — |
| A17 | Delete driver | Driver detail → Danger zone | Password + confirm name | Driver removed from DB/auth | Wrong password | No delete |
| A18 | Delete fleet unit | `/fleet/:id` → Danger zone | Password + plate confirm | Unit permanently removed | Unit assigned active trip | Error / blocked |

---

### B. Driver app

| ID | Feature | Steps | Inputs | Expected ✅ | Bad route | Expected ❌ |
|----|---------|-------|--------|-------------|-----------|-------------|
| B1 | Register | Register flow | New email, name, phone | Account created → onboarding | Duplicate email | Error |
| B2 | Onboarding docs | `/onboarding/apply` steps | Upload required docs (no OR/CR) | Checklist → 100% | Skip required doc | < 100%, blocked at B6 |
| B3 | Training quiz | `/training` → modules + quiz | Score ≥ 80% | Training complete | Score < 80% | Must retake |
| B4 | Online blocked (pre-approval) | `/home` → Online | Before admin approve | Snackbar / block reason | — | Online stays off |
| B4b | Require documents recall | Admin A6b on approved driver | Driver app open on `/home` | Within ~25s redirect `/onboarding`; operator reason shown | Driver tries Online | Blocked; pushed to upload wizard |
| B5 | Online blocked (no unit) | After approve, no fleet assign | Toggle Online | “No e-trike assigned” | — | — |
| B6 | Go Online | All gates pass | Toggle Online | Online ON; location updates | Maintenance active | Maintenance screen |
| B7 | Time in/out | `/attendance` | Clock in → out | Records in admin Attendance | — | — |
| B8 | Accept trip | Stay Online on home | Rider books (see C3) | Incoming sheet → Accept → `/trip/:id` | Offline | No incoming sheet |
| B9 | Trip lifecycle | Active trip buttons | Arrived → Start → Complete | Status syncs to rider; no button spam | Rapid tap Arrived | Single transition; loading state |
| B10 | External nav | Trip screen → Waze/Maps | Pickup/dropoff | External app opens | — | — |
| B11 | Chat | `/chat/:tripId` | Send message | Rider receives | — | — |
| B12 | Post-approval tour | After first approval | Complete tour | Shown once; replay in Settings | — | — |
| B13 | Revoked mid-session | Admin revokes while Online | — | Next Online toggle fails / block message | — | — |

---

### C. Rider app

| ID | Feature | Steps | Inputs | Expected ✅ | Bad route | Expected ❌ |
|----|---------|-------|--------|-------------|-----------|-------------|
| C1 | Register / login | Auth screens | Rider test account | Lands on `/home` | Wrong password | Error |
| C2 | Set pickup/dropoff | `/home` map + sheet | Carmona pickup + dropoff | Route line + fare estimate | Empty fields | Cannot book |
| C3 | Book ride | Tap Book | Cash payment | Trip `requested` in Supabase | No Online drivers | Stuck requested / no accept |
| C4 | Live tracking | `/trip/:id` | Driver accepts + moves | Map + status updates | Driver cancels | Status reflects cancel |
| C5 | Chat | Chat from trip | Message text | Driver sees message | — | — |
| C6 | Complete + rate | `/trip/:id/completed` | 5-star + optional comment | Rating saved | Skip rating | Can still complete trip |
| C7 | History | `/history` | After C6 | Completed trip listed | — | — |
| C8 | Maintenance banner | Home during scheduled window | — | Banner with start time | Maintenance inactive | No banner |
| C9 | Maintenance block | During active maintenance | Open app | Full block screen | — | Cannot book |

---

### D. Cross-app E2E (golden path)

Run in order on **two phones** + **admin browser**.

| Step | App | Action | Expected |
|------|-----|--------|----------|
| 1 | Admin | Create fleet unit + assign to driver | Unit visible in driver onboarding |
| 2 | Driver | Register → docs 100% → training pass | Training complete in admin Training tab |
| 3 | Admin | Approve driver | Driver sees welcome tour / can reach home |
| 4 | Driver | Go **Online** | `is_online = true` in Supabase |
| 5 | Rider | Book Carmona ride | Trip `requested` |
| 6 | Driver | **Accept** | Trip `accepted` |
| 7 | Both | Arrived → In progress → Complete | Trip `completed`, fare set |
| 8 | Rider | Rate trip | Rating in DB |
| 9 | Admin | Audit + Payroll preview | Trip + driver activity visible |
| 10 | Admin | Schedule maintenance (5m) → wait | Banner → block → end now → apps restore |

**Golden path sign-off:** _________________ Date: _________

---

### E. Cross-app negative scenarios

| ID | Scenario | Setup | Action | Expected |
|----|----------|-------|--------|----------|
| E1 | Unapproved driver ride | Driver pending approval | Rider books | No accept; driver blocked Online |
| E2 | Untrained driver | Docs done, no quiz | Toggle Online | Training block message |
| E3 | Unassigned unit | Approved + trained, no fleet | Toggle Online | Fleet assignment block |
| E4 | Revoked driver | Admin revokes | Driver toggles Online | Blocked |
| E5 | Driver offline | Driver Online OFF | Rider books | Request not accepted |
| E6 | Maintenance halt | Admin active maintenance, block on | Rider opens app | Maintenance screen |
| E7 | Wrong admin password | Schedule maintenance | Bad password | No change |
| E8 | Overlapping maintenance | Schedule second overlapping window | Second schedule | Admin error “overlaps” |
| E9 | Trip button spam | Driver on active trip | Rapid tap Complete | One completion only; no duplicate status |
| E10 | Viewer admin actions | Viewer login | Open `/maintenance`, `/team` | Redirect to `/` |

---

## F. Admin web RBAC (roles and access)

Run **`fix_operator_rbac_viewer.sql`** then **`fix_operator_roles_hr_dispatcher.sql`** in Supabase.

### Roles

| Role | Who | Nav / write scope |
|------|-----|-------------------|
| `super_admin` | Platform owner | Everything + team governance |
| `admin` | Ops lead | Full ops + maintenance/team (limited team vs super) |
| `viewer` | Auditor / trainee | All pages read-only |
| `hr` | HR / payroll clerk | Drivers/training **read**; attendance, leave, payroll **write** |
| `dispatcher` | Floor dispatcher | Drivers, fleet, training **write**; attendance/leave **read**; no payroll/fare |

### Access matrix

| Area | super_admin | admin | viewer | hr | dispatcher |
|------|:-----------:|:-----:|:------:|:--:|:----------:|
| Overview, audit | R | R | R | R | R |
| Drivers / onboarding / training | W | W | R | R | W |
| Fleet assign / maintenance log | W | W | R | — | W |
| Pending / approved / revoked | W | W | R | — | W |
| Attendance / leave | W | W | R | W | R |
| Payroll / cash advance / deductions | W | W | R | W | — |
| Fare schedules | W | W | R | — | — |
| `/maintenance`, `/team`, delete | W* | W* | — | — | — |

\* Admin/super_admin only; password confirm in UI.

### Role filter tests (admin web)

| ID | Role | Steps | Expected |
|----|------|-------|----------|
| R1 | viewer | Login | Role banner; sidebar shows all ops pages; writes disabled |
| R2 | hr | Login | Sidebar: no Fleet, Pending, Fare; Payroll writes work |
| R3 | hr | Open `/fleet` or `/fare` | Redirect to `/` |
| R4 | dispatcher | Login | Sidebar: Fleet + driver ops; no Payroll, Fare |
| R5 | dispatcher | Open `/payroll` | Redirect to `/` |
| R6 | dispatcher | Approve driver + assign unit | Succeeds |
| R7 | hr | Finalize payroll | Succeeds |
| R8 | hr | Approve driver | Button hidden / RLS blocks |
| R9 | viewer / hr / dispatcher | Open `/maintenance` | Redirect to `/` |
| R10 | super_admin | Team → invite **hr** + **dispatcher** | Invite links work |

---

## Recommended test order (single session)

1. **SQL** — confirm all scripts applied  
2. **Admin A1–A8** — fleet + driver approval path  
3. **Driver B1–B6** — register through Online  
4. **Rider C1–C7** + **Driver B8–B9** — full ride ([`RIDE_TEST.md`](./RIDE_TEST.md))  
5. **Admin A9–A12** — payroll + audit  
6. **Admin A13–A16** + **C8–C9** + **Driver B6 block** — maintenance  
7. **E*** — negative / edge cases  
8. **Admin A17–A18** — permanent delete (use disposable test records only)

---

## Common blockers

| Symptom | Fix |
|---------|-----|
| Driver can't go Online | Training SQL; complete training; approve; assign unit |
| No trip requests | Driver Online + location on + Carmona area |
| Maintenance page error | Run `fix_app_maintenance.sql` |
| Delete fails | Run `fix_admin_delete_records.sql` |
| Payroll empty | Run `fix_payroll.sql` |
| Onboarding upload 42501 | Run `fix_driver_onboarding_complete.sql` |
| Admin can't preview docs | Storage bucket `driver-documents` + RLS |

---

## Build / install reference

```bash
# Driver → iPhone 16
cd etrike_ph_driver
flutter build ios --release -d 00008140-000005003C50401C
flutter install -d 00008140-000005003C50401C

# Rider → second phone (or same for partial tests)
cd etrike_ph_user
flutter build ios --release -d <DEVICE_ID>
flutter install -d <DEVICE_ID>
```

Admin web: `CasinWorks/SulongRideAdmin` → Vercel (`main` / `dev` / `UAT`).
