# CKD Care — Daily Tracking Loop (Group A) Design

**Date:** 2026-09-02
**Status:** Approved design, ready for implementation planning
**Scope:** First version — the daily tracking loop. Records/labs (Group B) and food content (Group C) come in later iterations.

## Overview

An Android/iOS Flutter app helping a CKD5/dialysis patient and their caregiver
manage daily care. **One shared device, all data local (SQLite), no accounts,
no network, works fully offline.**

This spec covers **Group A only**: fluid intake, fluid output, medicine
reminders + adherence log, and the dashboard that ties them together. Deferred
to later specs:

- **Group B** (records): lab results (creatinine, potassium, etc.), medicine
  stock, dialysis center schedule.
- **Group C** (static content): good / bad foods for CKD5.
- **Group D** (online sync): Supabase-backed sync with offline-first behavior.
  See "Sync-readiness" below — Group A ships the schema hooks for this, but
  builds no sync code.

The data model and migration system are designed so B, C, and D slot in as
numbered migrations, not rewrites.

## Users

Single shared device. No accounts, no per-user data separation. Patient and
caregiver both operate the same app instance; the caregiver may do setup
(fluid limit, medicine schedules) and the patient does daily logging, but the
app makes no distinction between them.

## Tech stack

- **Flutter** (existing scaffold; Dart SDK `^3.13.2`)
- **State management:** `provider` (lightest mainstream option, official, minimal boilerplate)
- **Storage:** `sqflite` + `path` (local SQLite)
- **Notifications:** `flutter_local_notifications` (local scheduled reminders)
- **IDs:** `uuid` (client-generated v4, for sync-stable row identity)
- **Testing:** `sqflite_common_ffi` for in-memory DB in unit tests

Rejected for now: riverpod / bloc (more ceremony than this scope needs).
Supabase sync is a **deferred phase (Group D)**, not part of Group A — the
offline app is the foundation, sync is an additive layer (see below).

## Architecture

```
lib/
  main.dart                  # app entry, DB init, notification init + reschedule-on-boot
  db/
    app_database.dart        # sqflite open, versioned schema, onUpgrade migrations
  models/                    # plain Dart classes: FluidEntry, Medicine, MedicineTime, DoseLog, Setting
  repositories/              # fluid_repository, medicine_repository, settings_repository
  services/
    notification_service.dart  # wraps flutter_local_notifications (schedule/cancel/reschedule)
  providers/                 # ChangeNotifiers: FluidProvider, MedicineProvider, DashboardProvider, SettingsProvider
  screens/                   # dashboard, fluid, medicines, medicine_detail, settings
  widgets/                   # shared UI (fluid gauge, dose tile, etc.)
```

**Data flow:** `Widget → Provider → Repository → SQLite`.
Repositories are the only code that touches the DB and return typed models
(never raw maps), so providers and UI are unit-testable against a fake repo and
the DB is swappable.

## Data model (SQLite)

Dates stored as ISO-8601 text (sortable). Indexes on the columns filtered daily.

Every **data** table carries three sync-metadata columns from v1 (see
"Sync-readiness"): `uuid` (client-generated v4, the sync-stable identity),
`updated_at` (last-modified, for last-write-wins), `deleted` (soft-delete
tombstone). The local `INTEGER id` stays the in-app primary key; `uuid` is the
cross-device identity.

```sql
-- Fluid entries: intake and output share one table, discriminated by `type`.
fluid_entry(
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,   -- client-generated v4, sync-stable identity
  type TEXT NOT NULL,          -- 'intake' | 'output'
  amount_ml INTEGER NOT NULL,
  logged_at TEXT NOT NULL,     -- full ISO timestamp
  day TEXT NOT NULL,           -- 'YYYY-MM-DD', derived, for fast daily rollups
  note TEXT,
  updated_at TEXT NOT NULL,    -- last-modified, for sync conflict resolution
  deleted INTEGER NOT NULL DEFAULT 0   -- soft-delete tombstone
);
CREATE INDEX idx_fluid_day ON fluid_entry(day, type);

medicine(
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  dosage TEXT,                 -- free text, e.g. '50 mg'
  active INTEGER NOT NULL DEFAULT 1,   -- deactivated but kept for dose history
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
);

-- One row per scheduled clock time (fixed daily in v1).
-- Flexible patterns (every-other-day, weekdays, intervals) extend this table later.
medicine_time(
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,
  medicine_id INTEGER NOT NULL REFERENCES medicine(id),
  time_of_day TEXT NOT NULL,   -- 'HH:mm'
  updated_at TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_time_med ON medicine_time(medicine_id);

-- Adherence log: one row per dose the user acts on.
dose_log(
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,
  medicine_id INTEGER NOT NULL REFERENCES medicine(id),
  scheduled_time TEXT NOT NULL, -- ISO timestamp the dose was due
  status TEXT NOT NULL,         -- 'taken' | 'skipped'
  acted_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_dose_med_time ON dose_log(medicine_id, scheduled_time);

-- Single-row-per-key settings; daily fluid limit lives here.
-- Device-local config, NOT synced — no sync columns.
setting(key TEXT PRIMARY KEY, value TEXT NOT NULL);
```

### Best-practice / scalability choices baked in

- **`day` column + index** on fluid → dashboard "today's total" is one indexed
  query, not a full scan; stays fast after years of data.
- **Soft-delete `active` flag** on medicine instead of hard delete → historical
  dose logs never break; referential integrity preserved.
- **Versioned schema** with `onUpgrade` migration path from day one → Group B
  tables are a numbered migration, not a rewrite.
- **`medicine_time` as its own table** → flexible schedules later means adding
  pattern columns here, without reshaping dose-log or reminder logic.
- Repository methods return typed models, never raw maps.

**Deliberately NOT added:** an ORM, a generic events table, a `SyncService`, or
a Supabase client. The migration system + the sync-metadata columns are the
scalability levers, and they are in place. Sync itself is Group D.

## Sync-readiness (foundation for Group D, no sync code in Group A)

The requirement: later add **Supabase online sync with offline-first behavior**,
and keep the database swappable. Group A lays the cheap-to-add-now / expensive-
to-backfill-later foundation, and builds nothing else:

- **Repository layer is the swap/sync seam.** UI and providers never touch
  `sqflite`; they call repositories that return typed models. Swapping the
  storage engine, or adding a remote data source *behind* the repositories,
  changes nothing above them. No abstract repository interface yet — there is
  one implementation; extracting an interface when the second arrives is a
  mechanical refactor (YAGNI until then).
- **`uuid` on every data row.** Local `INTEGER` PKs collide when two devices
  merge; a client-generated v4 `uuid` gives each row a stable cross-device
  identity. Generated at insert time, immutable thereafter.
- **`updated_at` on every data row.** Bumped on every write. Enables
  last-write-wins conflict resolution and "changed since last sync" queries
  without a separate audit log.
- **`deleted` tombstone on every data row.** A hard-deleted row can't be
  propagated as a deletion to the server/other devices. All deletes are soft;
  reads filter `deleted = 0`.

**Deferred to Group D (its own spec, after Group A works fully offline):**
Supabase client + auth, a `SyncService` (push local dirty rows, pull remote
changes since a cursor), a `last_synced_at` marker, connectivity/retry handling,
and the conflict policy (default: last-write-wins by `updated_at`). Offline-first
is guaranteed because Group A *is* the fully-functional offline app; sync is a
purely additive background layer.

## Features & screens (Group A)

### Dashboard (home) — the daily glance
- **Fluid gauge:** intake vs daily limit ("650 / 1000 mL"), color shifts
  green → amber (near limit) → red (over). Net balance line: intake − output.
- **Today's meds:** doses due today with status (taken ✓ / skipped / pending),
  quick "mark taken" tap; shows next upcoming dose.
- **Quick-add buttons:** + Intake, + Output.
- **First-run / empty state:** prompts setting the fluid limit.

### Fluid screen
Full day's entries (intake & output), add / edit / delete; per-entry amount +
optional note + time. Day switcher to review past days.

### Medicines screen
List of active meds; add / edit a medicine (name, dosage, one or more clock
times); deactivate. Tapping a med → its adherence history.

### Settings
Daily fluid limit (mL); notifications on/off.

## Notification flow (the one timing-sensitive piece)

- On **add / edit / deactivate medicine** → `notification_service` cancels that
  medicine's pending notifications and reschedules from its `medicine_time`
  rows. Notification IDs are **stable, derived from `medicine_id` + time slot**,
  so rescheduling is idempotent.
- Notification fires at the clock time with actions **Taken** / **Skip** →
  writes a `dose_log` row and updates the dashboard.
- **Reschedule-on-boot:** notifications are re-registered on app start (covers
  device reboot clearing scheduled notifications).
- If the user marks a dose from the **dashboard** instead of the notification,
  the pending notification for that dose is cancelled.

### Edge cases handled
- Dose acted on twice → idempotent by `medicine_id + scheduled_time` (upsert /
  last-status-wins, no duplicate rows).
- Fluid limit not yet set → gauge shows "set a limit" prompt.
- Notification permission denied → app still works; dashboard is the source of
  truth for what is due.

### Deliberately skipped for now
Snooze, per-dose custom reminders, timezone-change rescheduling, streak stats.
Add when a real need appears.

## Testing & verification

Test the logic that can break; skip widget-pixel tests and framework glue.

**Unit tests** (in-memory SQLite via `sqflite_common_ffi`):
- Fluid rollups: intake/output sums per `day`, net balance, and at/over/under
  limit boundaries (649 / 650 / 1001 vs a 1000 limit) — drives gauge color.
- Dose-log idempotency: acting on the same `medicine_id + scheduled_time` twice
  yields one row, last status wins.
- Repository round-trips: save → read back typed model; soft-delete keeps dose
  history queryable.
- Migration: open at schema v1, upgrade, assert tables/indexes exist — guards
  the Group B growth path.

**Provider tests** (fake repository, no DB): dashboard aggregates today's fluid
+ doses correctly; marking a dose updates state and calls
`notification_service.cancel`.

**Notification service** (mock plugin): schedule / cancel called with the stable
derived IDs; reschedule is idempotent. No real notifications fired in tests.

**One smoke widget test:** dashboard renders with seeded data (gauge + dose list
appear) — catches wiring breakage.

**Manual verification checklist** (device — notifications can't be fully proven
in unit tests): set limit → log intake past it (gauge turns red) → add a
medicine with a near-future time → notification fires → tap **Taken** →
dashboard reflects it → reboot → reminders still scheduled.

**Gate before "done":** `flutter analyze` clean and `flutter test` green.
