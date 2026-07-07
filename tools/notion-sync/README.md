# Notion sync — Sulong Ride project tracker

Syncs `Sulong_Ride_Project_Tracker.csv` (65 tasks) into a Notion database via the [Notion API](https://developers.notion.com/). Re-runs are **idempotent**: rows are matched by **Task** title and updated in place (no duplicates).

## Prerequisites

- Python 3.9+
- A Notion workspace where you can create integrations and share pages

## One-time Notion setup

### 1. Create an integration

1. Open [notion.so/my-integrations](https://www.notion.so/my-integrations).
2. Click **New integration**.
3. Name it (e.g. `EtrikeApp Sync`), pick your workspace, and create it.
4. Copy the **Internal Integration Secret** (`secret_…`). You will use this as `NOTION_API_KEY`.

### 2. Choose a parent page and share it

1. In Notion, open or create a page where the tracker database should live (e.g. **Sulong Ride**).
2. Click **⋯** (top right) → **Connections** → add your integration.
3. The integration must have access to this page before the script can create a database under it.

### 3. Get the page ID

From the page URL:

```text
https://www.notion.so/Your-Workspace/Sulong-Ride-abc123def4567890abcdef1234567890
                                                      └──────── 32-char ID ────────┘
```

Copy the 32-character ID (with or without dashes). This is `NOTION_PARENT_PAGE_ID`.

## Script setup

```bash
cd tools/notion-sync
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
```

Edit `.env`:

```env
NOTION_API_KEY=secret_your_integration_secret
NOTION_PARENT_PAGE_ID=your_parent_page_id
```

**Never commit `.env`** — it is listed in `.gitignore`.

## Run the sync

From `tools/notion-sync` (with venv activated):

```bash
python sync.py
```

First run:

- Creates a full-page database **Sulong Ride Project Tracker** under your parent page
- Sets columns: Task (title), Category / Phase / Status / Priority / Target Month (select), Dependencies / Notes / Owner (text)
- Imports all 65 CSV rows
- Saves the database ID to `.notion-sync-state.json` for future runs

Subsequent runs:

- Reuses the saved database ID
- Updates existing rows by Task name; creates any new tasks from the CSV

### Options

```bash
# Custom CSV path
python sync.py --csv ../../Sulong_Ride_Project_Tracker.csv

# Preview without writing
python sync.py --dry-run

# Target an existing database (skip create + ignore state file)
NOTION_DATABASE_ID=xxxxxxxx python sync.py
```

## Rate limits

The Notion API allows about **3 requests per second**. The script waits ~0.35s between row writes, so a full sync takes roughly 30–45 seconds.

## Fallback: manual CSV import

If you prefer not to use the API:

1. In Notion, create a new **Table – Full page** database.
2. Add columns to match the CSV:
   - **Task** — Title
   - **Category**, **Phase**, **Status**, **Priority**, **Target Month** — Select
   - **Dependencies**, **Notes**, **Owner** — Text
3. Open the database, click **⋯** → **Merge with CSV** (or **Import** → **CSV**).
4. Upload `Sulong_Ride_Project_Tracker.csv` from the repo root.
5. Map each CSV column to the matching property.

Manual import is faster for a one-off upload but does not stay in sync when the CSV changes. Re-importing usually creates duplicates unless you clear the table first.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `object_not_found` on create | Share the parent page with your integration (step 2 above). |
| `unauthorized` | Check `NOTION_API_KEY` is the full `secret_…` value. |
| `validation_error` on select | Re-run after editing the CSV; new select values are added on database create only. For an existing DB, add the option in Notion or delete the DB and sync again. |
| Duplicate rows after manual import | Delete the database and run `python sync.py`, or set `NOTION_DATABASE_ID` and run once to upsert by Task. |

## Files

| File | Purpose |
|------|---------|
| `sync.py` | Main sync script |
| `requirements.txt` | Python dependencies |
| `.env.example` | Template for secrets |
| `.gitignore` | Ignores `.env` and local state |
