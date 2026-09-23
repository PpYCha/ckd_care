# KidneyTrack Health Trends Graphs Design

## Goal

Add a Health trends feature that helps a KidneyTrack user understand patterns in
fluid intake/output and dialysis session weights over daily, weekly, monthly,
and yearly ranges. The feature should use existing local SQLite data and should
not ask the user to re-enter values already stored elsewhere.

## User Outcome

The user can open a Trends card from the dashboard and see two focused chart
views:

- Fluid trends: intake, output, and net balance.
- Session weight trends: pre-weight and post-weight for dated dialysis
  sessions.

The feature succeeds when the user can quickly compare short-term daily records
with longer-term weekly, monthly, and yearly patterns, including empty states
when no records exist for the selected period.

## Current Data Sources

Fluid data already lives in `fluid_entry`.

- `type`: `intake` or `output`.
- `amount_ml`: amount to aggregate.
- `logged_at`: timestamp of the entry.
- `day`: local date string used by existing daily screens.
- `deleted`: soft-delete flag that must be excluded from reports.

Dialysis weights already live in `dialysis_session_log`.

- `session_key`: normalized dated session key.
- `session_start`: dated session timestamp.
- `pre_weight_kg`: nullable pre-session weight.
- `post_weight_kg`: nullable post-session weight.

Weight reporting must keep measurements attached to concrete dated sessions,
not recurring dialysis schedule defaults.

## Product Shape

The dashboard gets a compact Health trends card below the existing date/fluid
area or near the next dialysis card. Tapping it opens a full `TrendsScreen`.

`TrendsScreen` has two tabs:

- `Fluid`
- `Weights`

Each tab has the same period selector:

- `Day`
- `Week`
- `Month`
- `Year`

Each period view includes previous/next controls and a readable range label.
Future ranges are allowed for navigation consistency, but they normally show an
empty state unless data exists.

## Range Rules

All ranges use local dates.

- Day: midnight through the next midnight for the selected date.
- Week: Monday through Sunday containing the selected date.
- Month: first through last day of the selected month.
- Year: January through December of the selected year.

For fluid:

- Day groups entries by hour so a user can see when fluid was logged.
- Week groups totals by day.
- Month groups totals by day.
- Year groups totals by month.

For weights:

- Day shows concrete sessions on that date.
- Week shows concrete sessions in the week.
- Month shows concrete sessions in the month.
- Year groups by month and uses averages for pre/post weights.

## Data Models

Add a small trends model layer:

- `TrendPeriod`: enum for day, week, month, year.
- `TrendRange`: start, end, label, and period.
- `FluidTrendPoint`: label, start date/time, intake mL, output mL, net mL.
- `WeightTrendPoint`: label, start date/time, nullable pre-weight kg,
  nullable post-weight kg.

The models should stay presentation-friendly but not depend on Flutter widgets.

## Repository Changes

Extend `FluidRepository` with a range rollup method.

Expected behavior:

- Exclude `deleted = 1`.
- Aggregate intake and output independently.
- Return zeroes for missing fluid buckets inside the selected range, so the
  chart has stable spacing.
- Keep existing `totalsForDay` behavior unchanged.

Extend `DialysisSessionLogRepository` with a range method.

Expected behavior:

- Read rows by `session_start` range.
- Include rows when either pre-weight or post-weight exists.
- Preserve per-session points for day/week/month.
- For yearly data, average all available pre-weights and post-weights per
  month independently.
- Keep existing `saveWeights` semantics unchanged.

No schema change is required for the first version because the existing indexes
support the needed range access:

- `idx_fluid_day` for fluid day/type queries.
- `idx_dialysis_session_start` for session weight range queries.

## Provider

Add `TrendsProvider`.

Responsibilities:

- Track selected tab-independent date and selected period.
- Build the active `TrendRange`.
- Load fluid and weight trend points from repositories.
- Expose loading and error states.
- Refresh after period/date changes.

The provider should not mutate existing fluid or dialysis data. It only reads.

## UI

Add `TrendsScreen`.

Screen structure:

- App bar title: `Health trends`.
- Tab bar: `Fluid`, `Weights`.
- Period segmented control: `Day`, `Week`, `Month`, `Year`.
- Previous/range/next row.
- Summary tiles above the chart.
- Chart area.
- Empty state when the selected range has no meaningful data.

Fluid chart:

- Grouped bars for intake and output.
- A small net-balance summary above or below the chart.
- Intake uses the app water color; output uses a neutral or primary color.

Weight chart:

- Line chart with two series: pre-weight and post-weight.
- Missing values do not draw a point for that series.
- A small difference summary can show average removed weight when both values
  exist.

Use custom `CustomPainter` chart widgets for this version. That avoids a new
package dependency and keeps the feature simple for the current app size.

## Error And Empty States

Empty fluid state:

`No fluid records in this range`

Empty weights state:

`No session weights in this range`

Database or loading errors should display a short retry panel and keep the rest
of the app usable.

## Navigation

Add the dashboard Health trends card with a line-chart icon. The card opens
`TrendsScreen` using `Navigator.push`.

Do not add a new bottom navigation item. The existing bottom navigation already
has five destinations, and trends are a secondary analysis workflow rather than
a daily logging workflow.

## Testing

Repository tests:

- Fluid daily hourly grouping.
- Fluid weekly daily totals with missing buckets.
- Fluid yearly monthly totals.
- Weight range query preserves per-session points.
- Weight yearly monthly averages handle missing pre/post values separately.

Provider tests:

- Default range is current day.
- Changing period rebuilds range and reloads data.
- Previous/next navigation changes by day, week, month, or year.

Widget tests:

- Dashboard renders the Health trends card.
- Trends screen shows Fluid and Weights tabs.
- Empty states render for ranges without data.

Final verification should run:

- `flutter analyze`
- `flutter test`

## Out Of Scope

- Exporting charts to PDF or images.
- Cloud sync.
- Medical interpretation or advice.
- Goal thresholds beyond the existing fluid limit.
- Editing fluid entries or dialysis weights from the trends screen.
