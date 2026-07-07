# Sulong Ride — Tutorial Handbook

Step-by-step guides for **Riders**, **Drivers**, and **Operators** using Sulong Ride Apps.

**Product:** Sulong Ride Apps (*Smart Tricycle apps System*)  
**Pilot area:** Carmona, Cavite  
**Last updated:** July 5, 2026

---

## How to use this handbook

| Section | Audience | App |
|---------|----------|-----|
| [Part 1 — Rider app](#part-1--rider-app-tutorial) | Passengers booking e-trike rides | iOS / Android |
| [Part 2 — Driver app](#part-2--driver-app-tutorial) | Company e-trike drivers | iOS / Android |
| [Part 3 — Admin web](#part-3--admin-web-tutorial) | Fleet operators & staff | Browser (Vercel) |
| [Part 4 — End-to-end scenario](#part-4--complete-ride-scenario) | QA / training demo | All three |
| [Quick reference](#quick-reference--common-issues) | Everyone | — |

**Related docs:** [`PROJECT_GUIDE.md`](PROJECT_GUIDE.md) (technical architecture) · [`../tools/RIDE_TEST.md`](../tools/RIDE_TEST.md) (QA ride flow)

---

# Part 1 — Rider app tutorial

Install the **Sulong Ride Apps** rider app on your phone. The app is mobile-only (not available on web).

---

## 1.1 First launch — App tutorial

1. Open the app. You may see a short **eco onboarding** slideshow:
   - *Ride clean. Ride smart.* → **Next**
   - Steps about search, booking, and payment → **Next**
   - Final screen → **Get started** or **Create an account**
2. Tap **Skip** (top-right) anytime to go straight to login/register.
3. To replay later: **Settings → App tutorial**.

---

## 1.2 Create an account

**Path:** Register screen

1. Tap **Create an account** (from login or onboarding).
2. Optional: tap **Sign up with Google**.
3. Or use email:
   - Enter **Full name**, **Email**, **Password**
   - Tap **Register**
4. You land on the **Home** map after sign-in.

> **Note:** Email confirmation is off for the MVP — you can sign in immediately after registering.

---

## 1.3 Sign in

**Path:** Login screen — *Magandang araw*

1. Enter **Email** and **Password**, or use **Google** sign-in.
2. Tap **Sign in**.
3. If you have an **active trip**, the app opens that trip automatically.
4. Otherwise you go to **Home**.

---

## 1.4 Book a ride

**Path:** Home → bottom sheet **Ride Commute** tab

### Set pickup

1. On the map screen, open the bottom sheet.
2. Under **Pickup**:
   - The app uses your **current location** by default (*Locating…* then your address).
   - Tap **Change** to search: **Search pickup in Carmona / Cavite**
   - Or tap **Pin pickup on map** and tap the map.
   - Or tap **Use my current location**.
3. If location fails: **Retry location** or **Open Settings** (enable GPS).

### Set drop-off

1. Tap **Drop-off** → **Set** or **Change**.
2. Search: **Search destination in Carmona / Cavite**.
3. A route line and fare estimate appear on the map.

### Choose vehicle & confirm

1. Scroll to **Choose your eco-ride**.
2. Select a vehicle type (e.g. **EcoTrike Commuter**, **EcoTrike Solo**, etc.).
3. Optional: enter an **Eco-promo code** → **Apply**.
4. Check **Total fare** (MVP default: **₱40 flat**).
5. Tap **Confirm eco-ride**.

You are taken to the **Trip Active** screen. Status: *Finding your trike*.

---

## 1.5 Track your trip

**Path:** Trip Active (`/trip/:id`)

| Status | What you see |
|--------|--------------|
| Finding driver | *Finding your trike* — matching nearest driver |
| Driver assigned | Driver name, trike model, plate — *Driver is on the way* |
| En route | *En route* — heading to drop-off |

**Progress:** Assigned → Arrived → En route

**Actions on this screen:**
- **Recenter map** — center map on you or driver
- **Phone icon** — call driver (if available)
- **Chat icon** — open secure chat (available after driver **Accepts**)
- **Share ride** — copy tracking link for family
- **Safety toolkit** → **EcoRide Safety Center** (emergency hotline, auto-share)
- **Cancel eco-ride** — cancel before trip starts (dialog: **Keep** / **Cancel**)

---

## 1.6 Chat with your driver

1. From the trip screen, tap the **chat** icon.
2. Type a message or use presets:
   - *Malapit na ako!*
   - *Sandali lang po.*
   - *Salamat!*
   - *Hihintayin ko kayo.*
3. Tap send.

> Chat opens only after the driver **accepts** your booking.

---

## 1.7 Complete ride & rate

When the driver completes the trip:

1. You see **Ride complete!**
2. Review **Pickup**, **Drop-off**, **Fare**.
3. Under **Rate your trip**:
   - Tap stars (1–5)
   - Select feedback tags (e.g. *Punctual*, *Clean helmet*, or complaint tags for low ratings)
   - Tap **Submit rating**
4. Or tap **Skip for now** / **Back to home**.

You can also rate later from **History**.

---

## 1.8 Trip history

**Path:** Home top bar → **History** (or Eco-Profile tab → **Trip history**)

- Section **COMPLETED TRIPS** lists past rides.
- Tap **Rate driver** if not yet rated.
- Tap **Book again** to reuse a route.
- Tap **Receipt** to view fare breakdown.

---

## 1.9 Profile & settings

### Profile (`/profile`)

- View account info.
- **ECOPAY CASHLESS WALLET** — demo top-up buttons (MVP).
- **Log out**.

### Settings (`/settings`)

- **Push notifications** — toggle (local notifications when app active)
- **High-accuracy GPS** — toggle
- **Default vehicle** — preferred EcoTrike type
- **App tutorial** — replay onboarding
- **Reset app cache**

---

## 1.10 Maintenance mode

If the operator schedules maintenance, you may see:

- A **banner** on Home before maintenance starts, or
- A full **maintenance block screen** — apps cannot be used until maintenance ends.

---

# Part 2 — Driver app tutorial

Install the **Sulong Ride Apps** driver app. Drivers are company employees — you do not enter your own plate or trike model at registration.

---

## 2.1 Register

**Path:** Driver registration

1. Tap **Don't have an account? Register**.
2. Fill in:
   - **Full name**
   - **Email**
   - **Password**
   - **Mobile number**
3. Tap **Register**.
4. You enter the **Welcome** slideshow, then **Onboarding**.

> **Google sign-in** works for login only — register with email first.

---

## 2.2 Welcome & onboarding overview

### Welcome slideshow (4 pages)

- *Welcome to Sulong Ride Apps* → **Continue**
- *Complete onboarding* → **Continue**
- *Time in & time out* → **Continue**
- *Track your progress* → **Get started**

Tap **Skip** anytime.

### Onboarding hub

**Header** shows your name and status:
- **Pending review** — waiting for operator
- **Approved** — can proceed after training + fleet assignment
- **Not approved** — contact operator

**Cards:**
- **Document checklist** — % complete
- **Company e-trike** — assigned unit (read-only until admin assigns)
- **Application steps** — tap to open wizard

**Primary button** (changes with progress):
- **Continue application**
- **Upload required documents**
- **Review & submit**

---

## 2.3 Onboarding wizard (7 steps)

**Path:** Onboarding → **Application steps**

| Step | What to do |
|------|------------|
| 1 — Personal info | First/last name, mobile, email, emergency contact, address → **Save & continue** |
| 2 — Profile & ID | Upload **Profile photo**, **Valid government ID** → **Save & continue** |
| 3 — Driver's license | Upload **PDL**, **LTFRB Franchise / CPC** → **Save & continue** |
| 4 — Clearances | Upload **NBI**, **Police**, **Barangay** clearance → **Save & continue** |
| 5 — Health | Upload **Medical certificate**, **Drug test result** → **Save & continue** |
| 6 — Rider training | Complete embedded training module (see §2.4) |
| 7 — Review | Check summary → **Submit for review** |

**Uploading documents:**
- Tap **Camera**, **Gallery**, or **PDF / file**
- Set **expiry date** if required
- **Remove** to replace a rejected document

After submit: *"Application submitted! We will notify you when approved."*

> **OR/CR not required** — company assigns the e-trike; you do not upload vehicle OR/CR.

---

## 2.4 Rider protocol training

**Path:** Training screen (step 6 or standalone `/training`)

### Online training (default)

1. Read **Module 1 of 5** → **Next module** (repeat for all 5).
2. On the last module → **Take quiz (80% to pass)**.
3. Answer quiz questions → **Submit quiz**.
4. Score **≥ 80%** → **Training complete** → **Go to Home**.

If you score below 80%, retake the quiz.

### Onsite training

If your operator schedules onsite training, the app shows **Onsite training scheduled**. You cannot go **Online** until an operator marks training complete in admin.

---

## 2.5 Wait for operator approval

While **Pending review**:

- You can complete documents and training.
- **Online toggle is blocked** with a message: *Account pending approval*.
- An operator must **Approve** you in admin web.

After approval:

- **Post-approval welcome tour** plays once (6 pages ending **Start driving**).
- Replay anytime: **Settings → App tour**.

---

## 2.6 Go Online (start accepting trips)

Before **Online** works, ALL must be true:

| Requirement | How to check |
|-------------|--------------|
| Operator approved | Status chip shows **Approved** |
| Documents 100% | Onboarding checklist complete |
| Training complete | Training screen shows complete |
| E-trike assigned | Employment step shows company unit |

**Steps:**

1. Open **Home** (map screen).
2. Toggle **Online** ON (top switch).
3. If blocked, read the snackbar message — it tells you what's missing.
4. Keep **location permission** enabled.

**Optional — HR:** **Driver Hub → Time in / Time out** before your shift.

---

## 2.7 Accept a trip request

When **Online** and a rider books nearby:

1. An **incoming trip sheet** appears:
   - **New trip request**
   - **Pickup**, **Drop-off**, **Fare**
2. Tap **Accept** → active trip screen.
3. Or tap **Decline** — request goes to another driver.

> You won't receive requests if **Offline** or if you already have an active trip.

---

## 2.8 Complete a trip (lifecycle)

**Path:** Active Trip screen

### Phase 1 — Head to pickup (status: accepted)

1. Tap **Navigate to pickup** — opens Waze or Google Maps.
2. When you arrive → tap **Arrived at pickup**.

### Phase 2 — Passenger on board (status: ongoing)

1. Tap **Navigate to drop-off** if needed.
2. When ready to end → tap **End trip — collect payment**.

### Phase 3 — Cash payment (MVP)

1. Collect cash from rider (full fare shown).
2. Tap **Payment received**.
3. **Slide to confirm payment** → trip completes.

**Completed screen:** *Great job!* → **Back to map**

### Chat during trip

Tap **chat icon** → message rider (same presets as rider app).

---

## 2.9 Driver Hub & HR

**Path:** Home → **Profile** icon → **Driver Hub**

| Section | Action |
|---------|--------|
| **Stats** | Trips, earnings, rating, reviews |
| **Time in / Time out** | Clock in/out for attendance |
| **Leave requests** | Submit VL/SL leave |
| **Stats & history** | Past trips |
| **Achievements** | Driver milestones |
| **Edit profile** | Update name/contact |
| **Change password** | Account security |
| **Settings** | Notifications, app tour |
| **Log out** | Sign out |

### Leave request

1. **Driver Hub → Leave requests**
2. Select **VL** or **SL**
3. Enter **Start date**, **End date**, **Reason**
4. Tap **Submit request**
5. Track status: **PENDING** / **APPROVED** / **REJECTED**

---

## 2.10 If your account is revoked

- **Online toggle blocked** — *Your driver account was not approved*
- Contact your operator.
- Operator can **Approve again** from admin **Revoked** tab.

If operator **Requires documents**, you are sent back to the onboarding wizard to re-upload specific files.

---

# Part 3 — Admin web tutorial

Open the operator dashboard in your browser (Dev / UAT / Production URL from your team).

**Sign in:** `/login` — **Operator sign in** (email or **Continue with Google**)

---

## 3.1 Operator roles — what you can do

| Role | You can… | You cannot… |
|------|----------|-------------|
| **Super admin / Admin** | Everything — drivers, fleet, payroll, fare, maintenance, team | — |
| **Viewer** | View all operational pages | Approve, edit payroll, change fare, delete |
| **HR** | Attendance, leave, payroll | Approve drivers, assign fleet, edit fare |
| **Dispatcher** | Drivers, onboarding, fleet, training, approve/revoke | Payroll, fare, team, maintenance |

A **role banner** at the top explains your access when you sign in.

**First login:** You may be asked **What should we call you?** — enter your display name.

---

## 3.2 Overview dashboard

**Path:** `/` (Overview)

- **Active drivers**, **Pending approval**, **Trips today**, **Fares today**
- Charts: trips last 7 days, driver status breakdown
- **Flagged items** — quick links to drivers needing attention
- **Top drivers this week**

Read-only for all approved roles.

---

## 3.3 Approve a new driver (full workflow)

This is the most common operator task.

### Step 1 — Review onboarding

1. Sidebar → **Onboarding** (`/drivers/onboarding`)
2. Select a pending applicant → **Start onboarding**
3. Walk through wizard steps:
   - **Personal info** — verify contact details → **Save & continue**
   - **Documents** — preview uploads; **Verify** or **Reject** each document
   - **Employment** — assign **e-trike unit**, shift, start date → **Save & review**
   - **Review** → **Approve driver** or **Reject application**

### Step 2 — Or use Pending queue

1. Sidebar → **Pending** (`/pending`)
2. Find driver → **Approve** or **Reject**
3. Or tap **Onboard** for full wizard

### Step 3 — Assign fleet unit

If not done in onboarding:

1. **Drivers** → click driver name → **Driver detail**
2. Scroll to **Fleet assignment**
3. Select unit → **Assign now** (or schedule future date)

### Step 4 — Training (if onsite)

1. **Training** tab (`/training`) — find driver under **Not trained**
2. Or on driver detail → **Rider protocol training**
3. Set mode **Online** or **Onsite**
4. For onsite: **Mark onsite training complete**

### Step 5 — Confirm in app

Driver can now:
- Complete training (if online mode)
- Toggle **Online** in driver app
- Accept trip requests

---

## 3.4 Manage approved drivers

**Path:** `/approved`

| Action | When to use |
|--------|-------------|
| **Revoke** | Driver violated policy — blocks Online |
| **Require documents** | Send approved driver back to upload specific docs |

**Require documents modal:**
1. Enter **reason** (shown to driver)
2. Check which documents to re-require
3. Confirm — driver goes to **Pending** and must re-upload in app

**Revoked tab** (`/revoked`): **Approve again** to restore access.

---

## 3.5 Fleet management

**Path:** `/fleet`

### Add a new e-trike

1. Tap **Add unit**
2. Fill in:
   - **Unit number**, **Plate**, **Model**, **Color**
   - **Daily boundary fee** (used in payroll)
   - **Notes**
3. **Save unit**

### Manage a unit

1. Click unit row → **Manage** (or `/fleet/:id`)
2. **Assign to driver** → **Assign now** or **Schedule assignment**
3. **Unassign** to remove driver
4. **Add log entry** — maintenance records
5. Status: **Mark available** / **Retire unit**

**Filters:** All · Available · Assigned · Maintenance · Retired

---

## 3.6 Attendance & leave

### Attendance

**Path:** `/attendance`  
**Roles:** All (HR writes roster context)

- **Month calendar** — see who is on shift, online, on leave, off duty
- Click driver name → driver detail
- Per-driver **Shift setup** on driver detail page

### Leave

**Path:** `/leave`  
**Roles:** HR can approve/reject

1. View **Pending leave requests**
2. Tap **Approve** or **Reject** per request

---

## 3.7 Payroll

**Path:** `/payroll`  
**Roles:** Admin, super_admin, HR (viewer = read-only)

### Deduction settings (one-time setup)

1. Tab → **Deduction settings**
2. Edit PhilHealth, Pag-IBIG, SSS JSON fields
3. **Save settings**

### Generate payroll

1. Tab → **Generate**
2. Select **driver** and **pay period** (semi-monthly)
3. **Preview breakdown** — shows trips, attendance, boundary fee, deductions
4. **Save draft**

### Finalize & pay

1. Tab → **Payroll records**
2. Open draft → **Finalize**
3. After payment → **Mark paid**

### Cash advance

1. Tab → **Cash advances**
2. **Issue cash advance** — enter amount and driver
3. Amount auto-deducts on next finalized payroll

---

## 3.8 Fare settings

**Path:** `/fare`  
**Roles:** Admin, super_admin only

- View **Effective fare (now)**
- **Save default fare** (MVP: **₱40** flat)
- **Scheduled fare changes** — set future effective dates

---

## 3.9 Audit logs

**Path:** `/audit`  
**Roles:** All (read-only)

- Search operator actions: approvals, payroll, fleet changes
- Filter by date, app source, actor role
- **Apply** / **Reset** filters

---

## 3.10 App maintenance

**Path:** `/maintenance`  
**Roles:** Admin, super_admin only

### Schedule maintenance

1. **Schedule maintenance**
2. Enter **Title**, **Message**, **Start**, **End**
3. Toggle **Block apps** (hard block rider/driver apps)
4. Toggle **Notify users** (banner before start)
5. Enter your **password** to confirm

### During maintenance

- **Extend window**, **End now**, or **Cancel schedule** (password required)

---

## 3.11 Team & invites

**Path:** `/team`  
**Roles:** Admin, super_admin

### Invite a colleague

1. **Send invite**
2. Enter **Email** and **Role** (admin, viewer, hr, dispatcher)
3. **Send invite**
4. Copy invite link from **Invite links** section — share with colleague
5. They open `/invite/:token`, set name + password, and join

### Manage team

- **Approve** / **Revoke** / **Mark pending** operator access
- **Edit name**, change role (super_admin)

---

## 3.12 Document review tips

**Path:** Driver detail or Onboarding review

- Click each uploaded doc to **preview** (image or PDF)
- **Verify** — marks doc approved
- **Reject** — driver must re-upload (shows in app with reason)
- Onboarding checklist must reach **100%** before driver can go Online

---

## 3.13 Permanent delete (danger zone)

**Path:** Driver detail or Fleet unit detail  
**Roles:** Admin, super_admin only

- **Delete driver permanently** — enter password + confirm driver name
- **Delete unit permanently** — enter password + confirm plate

Use only for test records or GDPR-style removal. Cannot delete units on active trips.

---

# Part 4 — Complete ride scenario

Use this script to demo or test the full system (two phones + laptop).

| Step | Who | Action |
|------|-----|--------|
| 1 | **Admin** | Fleet → **Add unit** → assign to test driver |
| 2 | **Driver** | Register → complete onboarding wizard → training quiz ≥80% |
| 3 | **Admin** | Pending → **Approve** → confirm fleet assignment |
| 4 | **Driver** | Post-approval tour → toggle **Online** ON |
| 5 | **Rider** | Register → set Carmona pickup + drop-off → **Confirm eco-ride** |
| 6 | **Driver** | **Accept** incoming request |
| 7 | **Driver** | **Arrived at pickup** → **End trip** → **Payment received** → slide confirm |
| 8 | **Rider** | See trip complete → **Submit rating** |
| 9 | **Admin** | Audit logs → verify trip; Payroll → preview driver earnings |

**Test locations (Carmona):**
- Pickup: Carmona Public Market
- Drop-off: Carmona City Hall

See [`../tools/RIDE_TEST.md`](../tools/RIDE_TEST.md) for QA checklist details.

---

# Quick reference — common issues

## Rider

| Problem | Fix |
|---------|-----|
| Can't book | Set both pickup and drop-off inside Carmona |
| No drivers found | Wait — need an Online driver nearby |
| Map is grey | Enable location; check Google Maps API key (dev issue) |
| Chat disabled | Wait until driver accepts trip |

## Driver

| Problem | Fix |
|---------|-----|
| Can't go Online | Check: approved? docs 100%? training done? unit assigned? |
| No trip requests | Stay Online; enable GPS; be in Carmona area |
| Document rejected | Re-upload from onboarding wizard |
| Pending approval | Wait for operator — check admin **Pending** tab |

## Operator (admin web)

| Problem | Fix |
|---------|-----|
| Can't sign in | Must be invited — check **Team** invites |
| Driver account block | Use operator email, not driver email |
| Payroll empty | Run `fix_payroll.sql` in Supabase (dev) |
| Can't preview docs | Check `driver-documents` storage bucket |
| Page redirect to Overview | Your role can't access that route — check role banner |

---

# Appendix — Screen index

## Rider app routes

`splash` · `login` · `register` · `onboarding` · `home` · `trip/:id` · `trip/:id/completed` · `chat/:tripId` · `history` · `profile` · `settings` · `maintenance`

## Driver app routes

`splash` · `login` · `register` · `welcome` · `welcome-approved` · `onboarding` · `onboarding/apply` · `training` · `home` · `hub` · `attendance` · `leave` · `trip/:id` · `chat/:tripId` · `history` · `settings` · `maintenance`

## Admin web routes

`login` · `invite/:token` · `/` · `drivers` · `drivers/:id` · `drivers/onboarding` · `training` · `fleet` · `fleet/:id` · `pending` · `approved` · `revoked` · `attendance` · `leave` · `payroll` · `fare` · `audit` · `maintenance` · `team`

---

*For technical setup, architecture, and deployment see [`PROJECT_GUIDE.md`](PROJECT_GUIDE.md).*
