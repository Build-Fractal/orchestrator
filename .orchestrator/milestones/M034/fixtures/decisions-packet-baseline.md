<!--
  SYNTHETIC REPRESENTATIVE FIXTURE — decisions-packet-baseline.md
  Representative of the lakeledger M066/P01 data-catalog walkthrough (a 197-line
  catalog carrying 8 load-bearing decisions). The lakeledger repo is EXTERNAL and
  not present here, so this packet is authored as an in-repo synthetic substitute
  that exercises the full FR-1 field-set, including one `severity: warn` entry
  (D-5) and one `type: boundary_translation` entry (D-7, the surface_acres vs
  surface_area_acres drift named in the spec Problem Statement / M066/P04).
  It is the P01/P02 schema-coverage fixture; it is NOT a verbatim capture.
-->
---
schema_version: "1.0"
type: decision-packet
milestone: "M034"
source: "synthetic-representative-of-lakeledger-M066/P01"
artifact: "catalog/lake-attributes-catalog.md"
---

# Decision Packet — lake-attributes catalog (representative)

## D-1
- **id**: D-1
- **summary**: Primary key for the lake-attributes table
- **picked_value**: Composite `(lake_id, observation_year)`
- **rationale**: Attributes are versioned per observation year; a bare `lake_id` PK would forbid year-over-year rows.
- **alternatives_considered**: Surrogate auto-increment `id` (rejected: hides the natural uniqueness contract); bare `lake_id` (rejected: forbids re-observation).
- **concrete_impact**: Every downstream join keys on `(lake_id, observation_year)`; a surrogate key would silently admit duplicate-year rows that the ingest dedupe relies on rejecting.
- **severity**: block
- **type**: decision

## D-2
- **id**: D-2
- **summary**: Null-handling policy for missing depth soundings
- **picked_value**: Explicit `NULL` + `depth_source = 'unsurveyed'`
- **rationale**: Distinguishes "measured zero" from "never measured" — a sentinel `0` conflates them.
- **alternatives_considered**: Sentinel `-1` (rejected: leaks into AVG()); drop the row (rejected: loses the lake from the catalog entirely).
- **concrete_impact**: Aggregate depth statistics must filter on `depth_source <> 'unsurveyed'`; a sentinel would corrupt every basin-mean.
- **severity**: block
- **type**: decision

## D-3
- **id**: D-3
- **summary**: Unit of record for surface area
- **picked_value**: Acres, stored as `NUMERIC(10,2)`
- **rationale**: Source regulatory filings report acres; storing native avoids a lossy hectare round-trip.
- **alternatives_considered**: Hectares (rejected: source is acres, conversion introduces drift); square meters (rejected: precision overkill, unreadable in reports).
- **concrete_impact**: Report templates and the public API contract both assume acres; a unit change is a breaking API change.
- **severity**: block
- **type**: decision

## D-4
- **id**: D-4
- **summary**: Temporal grain of the catalog
- **picked_value**: One row per lake per observation year
- **rationale**: Matches the annual regulatory survey cadence; finer grain has no source data.
- **alternatives_considered**: Per-survey-event grain (rejected: most lakes have one survey/year, sparse); per-decade rollup (rejected: loses year resolution downstream queries need).
- **concrete_impact**: The `observation_year` column is load-bearing in the PK (D-1) and in every time-series query.
- **severity**: block
- **type**: decision

## D-5
- **id**: D-5
- **summary**: Trophic-state classification vocabulary
- **picked_value**: Carlson TSI buckets (oligotrophic / mesotrophic / eutrophic / hypereutrophic)
- **rationale**: Carlson is the field-standard; aligns with what limnologist reviewers expect.
- **alternatives_considered**: Raw TSI numeric only (rejected: forces every consumer to re-bucket); a custom 3-bucket scheme (rejected: non-standard, fails reviewer expectation).
- **concrete_impact**: Bucket boundaries are a named constant; if a second consumer re-derives them differently the classification silently diverges. Low blast radius today (one consumer), so flagged not blocking.
- **severity**: warn
- **type**: decision

## D-6
- **id**: D-6
- **summary**: Source-of-truth precedence when filings disagree
- **picked_value**: Most-recent filing wins; conflicts logged to `catalog_conflicts`
- **rationale**: Later filings supersede earlier corrections; a logged trail preserves auditability.
- **alternatives_considered**: First-filing-wins (rejected: ignores corrections); manual adjudication per conflict (rejected: does not scale to the catalog size).
- **concrete_impact**: The ingest pipeline needs a deterministic tiebreak; without it, re-ingest order would non-deterministically flip values.
- **severity**: block
- **type**: decision

## D-7
- **id**: D-7
- **summary**: Catalog vocabulary → schema column mapping for surface area
- **picked_value**: Catalog term `surface_acres` maps to DB column `surface_area_acres`
- **rationale**: The catalog/spec vocabulary (`surface_acres`) differs from the persisted schema-native column name (`surface_area_acres`); the bridge must be explicit so mock-only verification does not pass while the real query fails.
- **alternatives_considered**: Rename the column to match the catalog term (rejected: column name is already shipped in the public schema); rename the catalog term (rejected: catalog vocabulary is operator-facing and stable).
- **concrete_impact**: This is the lakeledger M066/P04 drift class — a query written against `surface_acres` passes mock tests and fails at first real run against `surface_area_acres`. Verification mechanism: real-DB column-existence check.
- **severity**: block
- **type**: boundary_translation

## D-8
- **id**: D-8
- **summary**: Retention policy for superseded catalog rows
- **picked_value**: Soft-delete via `superseded_by` pointer; never hard-delete
- **rationale**: Preserves the audit chain (consistent with the M034 #Q-1 append-with-supersede-chain decision and M036).
- **alternatives_considered**: Hard-delete on supersede (rejected: destroys audit history); separate archive table (rejected: splits the query surface, complicates time-travel queries).
- **concrete_impact**: Every catalog query must filter `superseded_by IS NULL` for the active view; the full history remains queryable for audit.
- **severity**: block
- **type**: decision
