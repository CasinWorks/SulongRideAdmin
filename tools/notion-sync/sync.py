#!/usr/bin/env python3
"""Sync Sulong Ride project tracker CSV to a Notion database."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from notion_client import Client
from notion_client.errors import APIResponseError

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CSV = SCRIPT_DIR.parent.parent / "Sulong_Ride_Project_Tracker.csv"
STATE_FILE = SCRIPT_DIR / ".notion-sync-state.json"
DATABASE_TITLE = "Sulong Ride Project Tracker"
RATE_LIMIT_SECONDS = 0.35

SELECT_COLORS = [
    "default",
    "gray",
    "brown",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
    "pink",
    "red",
]

# CSV column -> ordered Notion property name candidates.
COLUMN_ALIASES: dict[str, list[str]] = {
    "Project": ["Project"],
    "Due Date": ["Due Date", "End Date"],
}

CSV_SYNC_COLUMNS = [
    "Project",
    "Category",
    "Phase",
    "Status",
    "Priority",
    "Target Month",
    "Start Date",
    "Due Date",
    "Dependencies",
    "Notes",
    "Owner",
]


def parse_notion_id(raw: str) -> str:
    """Normalize a Notion page/database ID from env or URL."""
    value = raw.strip()
    match = re.search(
        r"([0-9a-fA-F]{32}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
        r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12})",
        value,
    )
    if not match:
        raise ValueError(f"Could not parse Notion ID from: {raw!r}")
    return match.group(1).replace("-", "")


def format_notion_id(raw_id: str) -> str:
    """Format a 32-char hex ID with dashes for the Notion API."""
    clean = parse_notion_id(raw_id)
    return f"{clean[:8]}-{clean[8:12]}-{clean[12:16]}-{clean[16:20]}-{clean[20:]}"


def load_rows(csv_path: Path) -> list[dict[str, str]]:
    with csv_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"No rows found in {csv_path}")
    return rows


def collect_select_options(rows: list[dict[str, str]], column: str) -> list[str]:
    values = sorted({row[column].strip() for row in rows if row.get(column, "").strip()})
    if not values:
        raise ValueError(f"No values found for column {column!r}")
    return values


def select_schema(options: list[str]) -> dict:
    return {
        "select": {
            "options": [
                {"name": name, "color": SELECT_COLORS[index % len(SELECT_COLORS)]}
                for index, name in enumerate(options)
            ]
        }
    }


def status_schema(options: list[str]) -> dict:
    return {
        "status": {
            "options": [
                {"name": name, "color": SELECT_COLORS[index % len(SELECT_COLORS)]}
                for index, name in enumerate(options)
            ]
        }
    }


def optional_select_schema(rows: list[dict[str, str]], column: str) -> dict:
    values = sorted({row[column].strip() for row in rows if row.get(column, "").strip()})
    if not values:
        return {"rich_text": {}}
    return select_schema(values)


def build_database_schema(rows: list[dict[str, str]]) -> dict:
    return {
        "Task": {"title": {}},
        "Project": select_schema(["SulongRide"]),
        "Category": select_schema(collect_select_options(rows, "Category")),
        "Phase": select_schema(collect_select_options(rows, "Phase")),
        "Status": status_schema(collect_select_options(rows, "Status")),
        "Priority": select_schema(collect_select_options(rows, "Priority")),
        "Target Month": select_schema(collect_select_options(rows, "Target Month")),
        "Start Date": {"date": {}},
        "Due Date": {"date": {}},
        "Dependencies": {"rich_text": {}},
        "Notes": {"rich_text": {}},
        "Owner": optional_select_schema(rows, "Owner"),
    }


def get_database_properties(notion: Client, database_id: str) -> dict:
    response = notion.databases.retrieve(database_id=database_id)
    return response["properties"]


def get_merged_property_types(
    notion: Client, database_id: str
) -> tuple[dict[str, str], dict]:
    """Merge database schema with page-level properties (e.g. workspace Project relation)."""
    properties = get_database_properties(notion, database_id)
    property_types = {name: prop["type"] for name, prop in properties.items()}

    pages = query_all_pages(notion, database_id)
    if pages:
        for name, prop in pages[0].get("properties", {}).items():
            if name not in property_types:
                property_types[name] = prop["type"]

    return property_types, properties


def find_title_property_name(properties: dict) -> str:
    for name, prop in properties.items():
        if prop.get("type") == "title":
            return name
    return "Task"


def resolve_csv_column(
    csv_column: str,
    notion_properties: dict,
    property_types: dict[str, str] | None = None,
) -> str | None:
    """Map a CSV column to an existing Notion property name."""
    types = property_types or {
        name: prop["type"] for name, prop in notion_properties.items()
    }
    for candidate in COLUMN_ALIASES.get(csv_column, [csv_column]):
        if candidate not in types:
            continue
        if csv_column == "Project" and types[candidate] not in ("relation", "select"):
            continue
        return candidate
    return None


def build_column_mapping(
    notion_properties: dict, property_types: dict[str, str] | None = None
) -> dict[str, str]:
    """Map CSV column names to resolved Notion property names."""
    types = property_types or {
        name: prop["type"] for name, prop in notion_properties.items()
    }
    mapping: dict[str, str] = {}
    for csv_column in CSV_SYNC_COLUMNS:
        notion_column = resolve_csv_column(csv_column, notion_properties, types)
        if notion_column:
            mapping[csv_column] = notion_column
    return mapping


def merge_select_options(existing_prop: dict, new_names: list[str]) -> dict | None:
    if existing_prop.get("type") != "select":
        return None
    current = {opt["name"] for opt in existing_prop["select"]["options"]}
    to_add = [name for name in new_names if name not in current]
    if not to_add:
        return None
    options = list(existing_prop["select"]["options"])
    for name in to_add:
        options.append(
            {"name": name, "color": SELECT_COLORS[len(options) % len(SELECT_COLORS)]}
        )
    return {"select": {"options": options}}


def merge_status_options(existing_prop: dict, new_names: list[str]) -> dict | None:
    if existing_prop.get("type") != "status":
        return None
    current = {opt["name"] for opt in existing_prop["status"]["options"]}
    to_add = [name for name in new_names if name not in current]
    if not to_add:
        return None
    options = list(existing_prop["status"]["options"])
    for name in to_add:
        options.append(
            {"name": name, "color": SELECT_COLORS[len(options) % len(SELECT_COLORS)]}
        )
    return {"status": {"options": options}}


def ensure_property_options(
    notion: Client, database_id: str, rows: list[dict[str, str]]
) -> None:
    """Add missing select/status option values from the CSV to the database schema."""
    properties = get_database_properties(notion, database_id)
    merged_types, _ = get_merged_property_types(notion, database_id)
    column_mapping = build_column_mapping(properties, merged_types)
    updates: dict[str, dict] = {}

    for csv_column in (
        "Project",
        "Category",
        "Phase",
        "Status",
        "Priority",
        "Target Month",
        "Owner",
    ):
        notion_column = column_mapping.get(csv_column)
        if not notion_column:
            continue
        prop = properties.get(notion_column)
        if not prop or prop.get("type") == "relation":
            continue
        values = sorted(
            {row[csv_column].strip() for row in rows if row.get(csv_column, "").strip()}
        )
        if not values:
            continue
        merged = merge_status_options(prop, values) or merge_select_options(prop, values)
        if merged:
            updates[notion_column] = merged

    if updates:
        print(f"Adding missing option values for: {', '.join(updates.keys())}")
        notion.databases.update(database_id=database_id, properties=updates)
        throttle()


def ensure_database_schema(
    notion: Client, database_id: str, rows: list[dict[str, str]]
) -> dict:
    """Add any missing CSV columns to the Notion database; return property types."""
    existing = get_database_properties(notion, database_id)
    merged_types, _ = get_merged_property_types(notion, database_id)
    desired = build_database_schema(rows)
    if find_title_property_name(existing) != "Task":
        desired.pop("Task", None)
    if resolve_csv_column("Project", existing, merged_types):
        desired.pop("Project", None)
    missing = {
        name: schema
        for name, schema in desired.items()
        if name not in existing
    }
    if missing:
        print(f"Adding {len(missing)} missing properties to database...")
        notion.databases.update(database_id=database_id, properties=missing)
        throttle()
        existing = get_database_properties(notion, database_id)
    return {name: prop["type"] for name, prop in existing.items()}


def rich_text(value: str) -> list[dict]:
    text = value.strip()
    if not text:
        return []
    chunks: list[dict] = []
    while text:
        chunk = text[:2000]
        text = text[2000:]
        chunks.append({"type": "text", "text": {"content": chunk}})
    return chunks


def property_value(prop_type: str, value: str, *, relation_page_id: str | None = None) -> dict:
    if prop_type == "title":
        return {"title": rich_text(value)}
    if prop_type == "status":
        return {"status": {"name": value}}
    if prop_type == "select":
        return {"select": {"name": value}}
    if prop_type == "relation":
        if not relation_page_id:
            raise ValueError("relation property requires a linked page id")
        return {"relation": [{"id": format_notion_id(relation_page_id)}]}
    if prop_type == "rich_text":
        return {"rich_text": rich_text(value)}
    if prop_type == "date":
        return {"date": {"start": value, "end": None}}
    raise ValueError(f"Unsupported Notion property type: {prop_type!r}")


def load_project_page_ids() -> dict[str, str]:
    """Map CSV project labels (e.g. SulongRide) to Notion project page IDs."""
    mapping: dict[str, str] = {}

    raw_map = os.environ.get("NOTION_PROJECT_PAGE_IDS", "").strip()
    if raw_map:
        if raw_map.startswith("{"):
            parsed = json.loads(raw_map)
            mapping.update(
                {str(name): parse_notion_id(page_id) for name, page_id in parsed.items()}
            )
        else:
            for entry in raw_map.split(","):
                entry = entry.strip()
                if not entry or ":" not in entry:
                    continue
                name, page_id = entry.split(":", 1)
                mapping[name.strip()] = parse_notion_id(page_id.strip())

    default_page_id = os.environ.get("NOTION_PROJECT_PAGE_ID", "").strip()
    if default_page_id:
        mapping.setdefault("SulongRide", parse_notion_id(default_page_id))

    return mapping


def resolve_project_page_id(project_name: str, project_page_ids: dict[str, str]) -> str | None:
    if project_name in project_page_ids:
        return project_page_ids[project_name]
    normalized = project_name.strip().lower()
    for name, page_id in project_page_ids.items():
        if name.strip().lower() == normalized:
            return page_id
    return None


def discover_project_page_ids(
    notion: Client, database_id: str, project_property: str = "Project"
) -> dict[str, str]:
    """Infer project page IDs from features that already have Project set in Notion."""
    discovered: dict[str, str] = {}
    pages = query_all_pages(notion, database_id)

    for page in pages:
        project_prop = page.get("properties", {}).get(project_property, {})
        if project_prop.get("type") != "relation":
            continue
        relation_ids = [
            rel["id"] for rel in project_prop.get("relation", []) if rel.get("id")
        ]
        if not relation_ids:
            continue

        prop_id = project_prop["id"]
        item = notion.pages.properties.retrieve(
            page_id=page["id"], property_id=prop_id
        )
        for related in item.get("results", []):
            related_page = related.get("relation", {})
            related_id = related_page.get("id")
            if not related_id:
                continue
            try:
                linked = notion.pages.retrieve(page_id=related_id)
            except APIResponseError:
                continue
            title = ""
            for prop in linked.get("properties", {}).values():
                if prop.get("type") == "title":
                    title = "".join(
                        part.get("plain_text", "") for part in prop.get("title", [])
                    ).strip()
                    break
            if not title:
                title = "".join(
                    part.get("plain_text", "") for part in linked.get("title", [])
                ).strip()
            if title:
                discovered.setdefault(title, parse_notion_id(related_id))
        throttle()

        if discovered:
            break

    return discovered


def row_to_properties(
    row: dict[str, str],
    property_types: dict[str, str],
    title_property: str,
    column_mapping: dict[str, str],
    *,
    project_page_ids: dict[str, str] | None = None,
) -> dict:
    properties: dict = {}
    project_page_ids = project_page_ids or {}

    task = row["Task"].strip()
    if task:
        properties[title_property] = property_value(
            property_types.get(title_property, "title"), task
        )

    project_column = column_mapping.get("Project")
    project_name = row.get("Project", "").strip()
    if project_column and project_name:
        project_type = property_types.get(project_column)
        if project_type == "relation":
            page_id = resolve_project_page_id(project_name, project_page_ids)
            if page_id:
                properties[project_column] = property_value(
                    "relation", project_name, relation_page_id=page_id
                )
            if (
                "Select" in property_types
                and property_types["Select"] == "select"
                and project_name == "SulongRide"
            ):
                properties["Select"] = {"select": None}
        elif project_type == "select":
            properties[project_column] = property_value("select", project_name)

    for csv_column in CSV_SYNC_COLUMNS:
        if csv_column == "Project":
            continue
        notion_column = column_mapping.get(csv_column)
        if not notion_column or notion_column not in property_types:
            continue
        value = row.get(csv_column, "").strip()
        if value:
            properties[notion_column] = property_value(
                property_types[notion_column], value
            )

    return properties


def load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    return json.loads(STATE_FILE.read_text(encoding="utf-8"))


def save_state(database_id: str) -> None:
    STATE_FILE.write_text(
        json.dumps({"database_id": database_id}, indent=2) + "\n",
        encoding="utf-8",
    )


def throttle() -> None:
    time.sleep(RATE_LIMIT_SECONDS)


def query_all_pages(notion: Client, database_id: str) -> list[dict]:
    pages: list[dict] = []
    cursor = None
    while True:
        response = notion.databases.query(
            **{"database_id": database_id, "start_cursor": cursor}
            if cursor
            else {"database_id": database_id}
        )
        pages.extend(response["results"])
        if not response.get("has_more"):
            break
        cursor = response.get("next_cursor")
        throttle()
    return pages


def page_task_title(page: dict, title_property: str) -> str | None:
    props = page.get("properties", {})
    task_prop = props.get(title_property, {})
    title_items = task_prop.get("title", [])
    if not title_items:
        return None
    return "".join(item.get("plain_text", "") for item in title_items).strip() or None


def create_database(
    notion: Client, parent_page_id: str, rows: list[dict[str, str]]
) -> str:
    response = notion.databases.create(
        parent={"type": "page_id", "page_id": parent_page_id},
        title=[{"type": "text", "text": {"content": DATABASE_TITLE}}],
        properties=build_database_schema(rows),
    )
    return response["id"]


def is_database(notion: Client, notion_id: str) -> bool:
    """Return True if the ID refers to an existing Notion database."""
    try:
        notion.databases.retrieve(database_id=format_notion_id(notion_id))
        return True
    except APIResponseError as exc:
        if exc.code in ("object_not_found", "validation_error"):
            return False
        raise


def resolve_database_id(args: argparse.Namespace, notion: Client | None = None) -> str | None:
    if args.database_id:
        return format_notion_id(args.database_id)
    if os.environ.get("NOTION_DATABASE_ID"):
        return format_notion_id(os.environ["NOTION_DATABASE_ID"])
    state = load_state()
    if state.get("database_id"):
        return format_notion_id(state["database_id"])
    parent = os.environ.get("NOTION_PARENT_PAGE_ID")
    if parent and notion and is_database(notion, parent):
        database_id = format_notion_id(parent)
        print(
            "NOTION_PARENT_PAGE_ID points to a database — syncing into it "
            "(use a page ID here if you want a new database created)."
        )
        save_state(database_id)
        return database_id
    return None


def sync_rows(
    notion: Client,
    database_id: str,
    rows: list[dict[str, str]],
    property_types: dict[str, str],
    title_property: str,
    column_mapping: dict[str, str],
    *,
    project_page_ids: dict[str, str] | None = None,
    dry_run: bool,
) -> tuple[int, int, int]:
    existing_pages = query_all_pages(notion, database_id)
    by_title = {}
    for page in existing_pages:
        title = page_task_title(page, title_property)
        if title:
            by_title[title] = page["id"]

    created = updated = skipped = 0

    for row in rows:
        task = row["Task"].strip()
        properties = row_to_properties(
            row,
            property_types,
            title_property,
            column_mapping,
            project_page_ids=project_page_ids,
        )
        page_id = by_title.get(task)

        if dry_run:
            action = "update" if page_id else "create"
            print(f"[dry-run] would {action}: {task}")
            if page_id:
                updated += 1
            else:
                created += 1
            continue

        try:
            if page_id:
                notion.pages.update(page_id=page_id, properties=properties)
                updated += 1
                print(f"Updated: {task}")
            else:
                notion.pages.create(
                    parent={"database_id": database_id},
                    properties=properties,
                )
                created += 1
                print(f"Created: {task}")
        except APIResponseError as exc:
            print(f"Error syncing {task!r}: {exc}", file=sys.stderr)
            skipped += 1

        throttle()

    return created, updated, skipped


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync Sulong Ride project tracker CSV to Notion."
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Path to CSV (default: {DEFAULT_CSV})",
    )
    parser.add_argument(
        "--database-id",
        help="Existing Notion database ID (skips database creation)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without calling Notion write APIs",
    )
    return parser.parse_args()


def main() -> int:
    load_dotenv(SCRIPT_DIR / ".env")
    args = parse_args()

    api_key = os.environ.get("NOTION_API_KEY")
    parent_page_id = os.environ.get("NOTION_PARENT_PAGE_ID")

    if not api_key:
        print("Missing NOTION_API_KEY. Copy .env.example to .env and set it.", file=sys.stderr)
        return 1

    if not args.csv.exists():
        print(f"CSV not found: {args.csv}", file=sys.stderr)
        return 1

    rows = load_rows(args.csv)
    notion = Client(auth=api_key)

    database_id = resolve_database_id(args, notion)

    if not database_id:
        if not parent_page_id:
            print(
                "Missing NOTION_PARENT_PAGE_ID (required on first run to create the database).",
                file=sys.stderr,
            )
            return 1
        if args.dry_run:
            print(
                f"[dry-run] would create database '{DATABASE_TITLE}' "
                f"with {len(rows)} rows"
            )
            return 0

        parent_page_id = format_notion_id(parent_page_id)
        print(f"Creating database '{DATABASE_TITLE}'...")
        database_id = create_database(notion, parent_page_id, rows)
        save_state(database_id)
        throttle()
        print(f"Database created: {database_id}")
    else:
        print(f"Using database: {database_id}")

    if args.dry_run:
        property_types = {
            name: next(iter(schema))
            for name, schema in build_database_schema(rows).items()
        }
        title_property = "Task"
        column_mapping = {col: col for col in CSV_SYNC_COLUMNS}
    else:
        ensure_database_schema(notion, database_id, rows)
        ensure_property_options(notion, database_id, rows)
        property_types, notion_properties = get_merged_property_types(notion, database_id)
        title_property = find_title_property_name(notion_properties)
        column_mapping = build_column_mapping(notion_properties, property_types)
        project_notion = column_mapping.get("Project")
        project_type = property_types.get(project_notion) if project_notion else None
        if project_notion:
            print(
                f"Project column: CSV 'Project' -> Notion {project_notion!r} "
                f"({project_type})"
            )
        print(f"Title property: {title_property!r}")

    project_page_ids = load_project_page_ids()
    project_column = column_mapping.get("Project")
    project_type = property_types.get(project_column) if project_column else None
    if (
        not args.dry_run
        and project_type == "relation"
        and not project_page_ids
        and project_column
    ):
        project_page_ids = discover_project_page_ids(
            notion, database_id, project_column
        )
        if project_page_ids:
            print(
                "Discovered project page IDs from existing Features rows: "
                + ", ".join(sorted(project_page_ids))
            )
    if project_type == "relation" and not project_page_ids:
        print(
            "\nWARNING: Features uses a Project relation column, but no project page "
            "IDs are configured.\n"
            "Add NOTION_PROJECT_PAGE_ID to .env with the SulongRide project page ID, "
            "and share that project page with your Notion integration.\n"
            "Tasks will sync without a Project link until this is set.\n",
            file=sys.stderr,
        )
    elif project_type == "relation" and project_page_ids:
        labels = ", ".join(sorted(project_page_ids))
        print(f"Project page IDs configured for: {labels}")

    created, updated, skipped = sync_rows(
        notion,
        database_id,
        rows,
        property_types,
        title_property,
        column_mapping,
        project_page_ids=project_page_ids,
        dry_run=args.dry_run,
    )

    print(
        f"\nDone. {created} created, {updated} updated, {skipped} skipped "
        f"({len(rows)} rows in CSV)."
    )
    if not args.dry_run and not os.environ.get("NOTION_DATABASE_ID") and database_id:
        print(f"Database ID saved to {STATE_FILE.name}")

    return 0 if skipped == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
