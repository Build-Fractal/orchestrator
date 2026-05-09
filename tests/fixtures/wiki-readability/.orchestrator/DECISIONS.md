# Synthetic Decisions Log

Test fixture for the M040 wiki readability decorator acceptance harness.

## Heading-shape decisions

### DR-SYN-001 — Adopt synthetic fixture for decorator acceptance

The fixture exercises the `### CODE — Title` heading shape and produces a
slug the decorator can target.

### DR-SYN-002 — Validate path-link rewriting

Source markdown that mentions `.orchestrator/decisions/dr-syn-002-followup.md`
must rewrite to a wiki-stub-relative link.

## Open governance items (bullet-shape codes)

- **`DR-OPEN-SYN-001`** — Bullet-shape decision used to verify the
  bullet parser path picks up open-governance entries.
- `DR-OPEN-SYN-002` — Alternate bullet shape (no bold backticks).
