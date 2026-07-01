# Sulong Ride Admin — Implementation Spec (E-Trike Fleet & HR)

> **Use this document as the master build prompt.** Paste into Cursor or hand to developers.
> **Do NOT change the visual identity:** green accent (`#2E7D32`), off-white background (`#F5F7F5`), rounded cards, sidebar `NavigationRail`. Use existing `AdminTokens`, `AdminStatCard`, `AdminPanelCard`, `FlaggedAlertRow`, `StatusPill`, `DriverAvatar`, `fl_chart` (not recharts — this is Flutter web).

---

## Product context (Philippines e-trike operator)

- **Fleet model:** Company-owned electric tricycles only. Drivers do **not** bring their own units.
- **Operator provides:** vehicle, boundary/per-trip pay rules, Carmona (or depot) assignment, HR compliance tracking.
- **Driver journey:** Applicant → Interview → Hiring decision → Onboarding checklist → Contract signing → Approved & active on roster.
- **Two parallel progress tracks:**
  1. **Hiring pipeline** — where the person is in recruitment (interview, offer, contract, etc.)
  2. **Onboarding checklist** — document & compliance completion (% with reminders/deadlines)

---

## Global UI patterns (graphics & intuition)

### Progress visuals (reuse everywhere)

| Component | Use |
|-----------|-----|
| **Circular % ring** | Overall registration completeness, hiring pipeline %, document step % |
| **Horizontal step bar** | 7-step wizard; hiring stages (5–6 steps); pipeline timeline |
| **Segmented bar** | Document categories complete (e.g. 4/6 LTO docs) |
| **Timeline (vertical)** | Reminders sent, deadline changes, stage transitions on profile |
| **Donut + legend** | Driver status breakdown (existing) |
| **Bar chart** | Trip activity 7-day (existing) |

### Status badges (documents & pipeline)

| Badge | Color | Meaning |
|-------|-------|---------|
| Verified | Green | Admin verified |
| Pending review | Yellow | Uploaded, awaiting review |
| Expiring soon | Amber | ≤60 days to expiry |
| Expired | Red | Past expiry date |
| Rejected | Red outline | Must re-upload |
| Not required | Gray | N/A for this role |
| Does not expire | Gray + lock | PSA birth cert, etc. |

### Hiring pipeline stages (default order)

1. **Application received** — form submitted or admin-created draft  
2. **Interview scheduled** — date/time set; reminder can be sent  
3. **Interview completed** — outcome: pass / hold / fail  
4. **Offer & hiring** — employment terms agreed  
5. **Onboarding** — document checklist in progress (links to checklist %)  
6. **Contract signing** — contract uploaded/signed; deadline tracked  
7. **Approved & active** — `drivers.approval_status = approved`; appears on roster  

Each stage stores: `started_at`, `completed_at`, `due_date`, `assigned_admin_id`, `notes`, `reminder_sent_at`.

**Pipeline % formula:** `completed_stages / total_required_stages × 100` (weighted optional: onboarding checklist counts as sub-progress).

### Onboarding checklist % formula

```
required_items = all documents marked required for e-trike company driver
completed_items = uploaded AND (verified OR does_not_expire)
checklist_% = completed_items / required_items × 100
```

Show **dual progress on registration screen:**
- Top: Hiring pipeline ring (e.g. "Stage 3 of 7 — Interview · 43%")
- Below steps: Document checklist ring (e.g. "Documents · 68% complete")

### Reminders & deadlines (admin actions)

Per driver/applicant, admin can:

- Set **deadline** on any pipeline stage or document (date picker)
- **Send reminder** (logs to `onboarding_timeline`; future: SMS/push via driver app)
- Reminder types: `document_expiry`, `document_missing`, `stage_overdue`, `interview_scheduled`, `contract_signing`

Timeline entry format: `{ at, actor, action, summary, metadata }`

---

## SCREEN 1 — Fleet Overview (`/` tab 0)

**Keep existing layout.** Extend, do not replace.

### Top KPI row (6 cards)

1. Total active drivers — sub: `X pending approval`  
2. Trips today — delta: `+N vs yesterday`  
3. Total fares today — `₱`  
4. Average fare per trip today — `₱`  
5. Drivers on duty now — sub: `Live count`  
6. **Total payroll this period** — `₱` — sub: `X drivers included` *(requires payroll module; show `—` until wired)*  

### Two panels (existing)

- Left: **Trip activity (last 7 days)** — `BarChart`  
- Right: **Driver status breakdown** — donut: On duty / Off duty / On leave / Pending  

### Flagged items (colored left border → link)

| Flag | Color | Link |
|------|-------|------|
| Pending driver approvals | Yellow | Pending tab |
| Unapproved leave requests | Yellow | Leave tab |
| 0 trips in last 3 days | Red | Driver profile |
| Pending cash advance requests | Yellow | Driver HR tab |
| Open disciplinary (pay impact) | Red | Disciplinary tab |
| Bonuses pending approval | Yellow | Payroll |
| Documents expiring ≤30 days | Amber | Driver Documents tab |
| Documents expired | Red | Driver Documents tab |
| **Onboarding overdue** (checklist past deadline) | Amber | `/drivers/register?id=` |
| **Interview today / overdue** | Amber | Registration / pipeline |

### Drivers needing review

Sort: critical → watch → lowest rating.  
Row: avatar, name, ID, badge, one-line complaint reason, rating (red/amber), **View profile** | **See all reviews**.

### Quick actions

- Review pending drivers  
- Review leave requests  
- View top drivers this week *(render `topDriversThisWeek` — data already in repo)*  
- Approve pending bonuses  
- **Register new driver** → `/drivers/register`  
- **Onboarding pipeline** → filter directory by pipeline stage  

---

## SCREEN 2 — Driver Registration (`/drivers/register`)

Multi-step wizard. **Company e-trike context:**

- Step 2C **CR / plate** → select from **company vehicles** (`vehicles` table), not driver's personal vehicle  
- Step 6 **Assigned vehicle** → dropdown of unassigned company units only  
- Remove any "bring your own tricycle" copy  

### Step indicator (7 steps)

1. Personal Info  
2. License & LTO Documents  
3. Government Clearances  
4. Health & Drug Test  
5. Government Contributions  
6. Employment Setup  
7. Review & Submit  

Each step: green check / current highlight / gray incomplete.  
**Step header shows checklist %** for steps 2–5.

### Hiring pipeline banner (top of page, always visible)

Horizontal pipeline graphic:

`Application → Interview → Hiring → Onboarding → Contract → Active`

- Click stage to jump (admin only)  
- Show % complete ring  
- **Set deadline** + **Send reminder** buttons on current stage  

### Document card template (steps 2–4)

- Upload PDF/JPG (max 5MB)  
- Document number, issue date, expiry date  
- Status: Pending → Verified / Rejected  
- Admin notes (rejection reason)  
- **Expiry warnings:** 60d amber, 30d dashboard flag, 0d expired  

### Step 7 actions

- Approve registration *(all required docs present, none rejected)*  
- Approve with exceptions *(notes required)*  
- Request more info  
- Reject application  

### Post-approval

Documents tracked for life of employment. Renewal upload → history log.

---

## SCREEN 3 — Driver Profile (`/drivers/:id`)

### Header

Avatar, name, driver ID, status badge, joined, **assigned company unit #**, employment type.

### Warning banners (conditional)

- Red: expired documents (list)  
- Red: open suspension  
- Amber: expiring soon (list)  

### Tabs

| Tab | Content |
|-----|---------|
| **Overview** | Performance summary, 30-day trip chart, recent trips table |
| **Performance** | Weekly bar chart, best day, peak heatmap, vs fleet avg |
| **Ratings & Feedback** | Existing ratings section |
| **Documents** | Card grid + expiry + renew |
| **HR & Payroll** | Employment, contributions, payroll table, cash advance, leave balance |
| **Disciplinary** | Incident list + Add incident |
| **Activity Log** | Audit timeline |

### Documents tab

Card grid per document: name, badge, number, dates, days until expiry, View file, Upload renewal, notes, verified by.

### Onboarding tab (optional 8th tab or section under Documents)

- Hiring pipeline timeline graphic  
- Checklist % ring  
- Reminder/deadline history  

---

## Data model (Supabase)

Run after existing HR SQL:

1. `fix_driver_onboarding.sql` — vehicles, documents, pipeline, timeline, reminders  

### Tables (summary)

- `vehicles` — company e-trikes: plate, unit_number, status, assigned_driver_id  
- `driver_documents` — type, file_url, numbers, dates, status, verified_by  
- `driver_hiring_pipeline` — driver_id, stage, status, due_date, completed_at  
- `onboarding_timeline` — audit-style events + reminders  
- `driver_registration_drafts` — JSON blob for in-progress wizard (optional)  

### Document types (enum)

`pdl`, `lto_or`, `lto_cr`, `ltfrb_cpc`, `nbi`, `police_clearance`, `barangay_clearance`, `psa_birth`, `medical_cert`, `drug_test`, `sss`, `philhealth`, `pagibig`, `tin`, `valid_id`, `profile_photo`, `contract_signed`

---

## Implementation phases

| Phase | Scope | Status |
|-------|--------|--------|
| **P0** | Spec + SQL + `/drivers/register` shell + pipeline/checklist progress widgets | Done |
| **P1** | Fleet overview extensions (payroll placeholder, extra flags, top drivers, onboarding pipeline filter) | Done |
| **P2** | Wizard steps 1–7 forms + Supabase persistence (`onboarding_repository`) | Done |
| **P3** | Profile tabs + Documents tab (upload/verify/view) + Performance weekly chart | Done |
| **P4** | Payroll, disciplinary, bonuses, cash advance tables + live flagged items | Not started |
| **P5** | Reminder push/SMS to driver app | Not started |

---

## Files to extend (existing)

```
lib/core/theme/admin_tokens.dart
lib/widgets/admin_ui.dart
lib/screens/overview/fleet_overview_tab.dart
lib/screens/drivers/driver_detail_screen.dart
lib/repositories/admin_repository.dart
lib/models/admin_models.dart
```

## New files

```
lib/screens/drivers/driver_register_screen.dart
lib/widgets/onboarding_progress.dart
lib/widgets/document_status_badge.dart
lib/models/onboarding_models.dart
lib/repositories/onboarding_repository.dart   ← implemented
etrike_ph_user/supabase/fix_driver_onboarding.sql
etrike_ph_user/supabase/fix_driver_documents_storage.sql
```

### Supabase run order

1. `fix_driver_onboarding.sql`
2. `fix_driver_documents_storage.sql`
3. Optional seed vehicles:

```sql
insert into public.vehicles (unit_number, plate_number, model, status, boundary_fee)
values
  ('ET-001', 'ABC 1234', 'Electric trike', 'available', 350),
  ('ET-002', 'DEF 5678', 'Electric trike', 'available', 350)
on conflict do nothing;
```

---

## Copy guidelines

- Say **"company e-trike"** / **"assigned unit"**, not "owner's tricycle"  
- Boundary system = **per-trip / boundary fee** for company fleet  
- Station = Carmona Central (or configured depot)  

---

*Last updated: product spec for Sulong Ride Admin — e-trike fleet operator, Philippines.*
