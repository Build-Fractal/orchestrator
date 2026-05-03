---
schema_version: "1.0"
type: tier-2-structured-extraction
source: "tests/fixtures/m036-p03-tier-2/sample.md"
extracted_at: "fixture"
---

# Tier 2 Fixture — PBJ Staffing Sample

This is a fixture markdown file used by M036 P03's Tier 2 acceptance
harness. The structured-extraction stub treats this content as if it
were a regulatory document with multiple headings.

## Section 1 — Definitions

- `staff_count`: the number of nursing staff on duty in a measurement window.
- `census`: the number of residents in a facility at a measurement instant.

## Section 2 — Calculation

The hours-per-resident-day metric divides total nursing hours by the
resident census, summed across the measurement window.
