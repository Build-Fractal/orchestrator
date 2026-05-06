---
schema_version: "1.0"
type: status-headline-shape
milestone: "M029"
phase: "P01"
created_at: "2026-05-05"
---

# Status Headline Shape

This document is the canonical Principle III design contract for the
`orchestrator:status` headline block (FR-2 / SC-2 of the M029 spec at
`specs/037-roadmap-visibility-cli-ux/spec.md`). Per the SC-2 explicit
clause and the arbiter ruling 2026-05-05 (RISK-7 / MIT-10), this file
MUST be on disk before any FR-2 implementation work begins. T03 (the
headline render path) and T04 (the `--format=json` renderer, which
reuses the headline fields as top-level JSON keys) BOTH consume this
contract.

## Purpose

The headline is the first thing every operator and every CI scraper
sees when invoking `orchestrator:status`. Its byte-stable shape is a
public contract:

- Every CI scraper that greps the headline reads the regex from this
  document. The regex block below is the ground truth that
  `tests/m029-acceptance/p01-sc2-headline.sh` greps against the
  renderer's stdout. T03's headline implementation MUST emit lines
  that match these regexes byte-for-byte. SC-2 fails on any drift.
- Every implementation reads field order from this document. The five
  headline fields ship in fixed order; reordering, omitting, or
  renaming a field is a contract violation.
- Every downstream consumer (`commands/status.md`, the JSON renderer,
  M035 packaging post-install verification, post-launch
  `external-tool-adapters`) reads field semantics from this document.

The companion contract for the JSON view of the same five fields is
`references/status-json-schema.md`. The two files MUST stay paired:
the five headline fields appear as the corresponding top-level JSON
keys in the schema. Drift between the two files is a contract
violation; the gate verifiers cross-check field presence in both
directions.

## Field Set

The headline carries exactly five fields in fixed order:

1. **Milestone ID + name** — `M### <name>` (e.g.,
   `M029 Roadmap Visibility & CLI UX`). Maps to JSON keys
   `milestone_id` + `milestone_name`.
2. **Phase index + percent complete** — `phase X/N (P_active, K%)`
   (e.g., `phase 1/3 (P01, 0%)`). Maps to JSON keys `phase_index` +
   `phase_count` + `phase_percent_complete`.
3. **Lock state** — `lock: <state>` where `<state>` is either `free`
   or `held by PID <pid> since <timestamp>`. Maps to JSON key
   `lock_state`.
4. **Last-dispatch recency** — `last_dispatch: <Nh ago | Nm ago | Ns ago | none>`.
   Maps to JSON key `last_dispatch_recency`.
5. **Last-verify result** — `last_verify: <pass | fail | none>`.
   Maps to JSON key `last_verify_result`.

The field names — `milestone`, `phase_index`, `lock_state`,
`last_dispatch`, `last_verify` — are themselves part of the contract:
they appear verbatim in the rendered headline (lines 2 and 3) and
verbatim as JSON key fragments. Renames are breaking changes.

## Line Packing

The five fields are packed into exactly three non-blank lines:

- **Line 1**: field 1 (milestone ID + name) on its own line.
  Example: `M029 Roadmap Visibility & CLI UX`
- **Line 2**: fields 2 + 3 separated by `  |  ` (two spaces, pipe,
  two spaces). Example:
  `phase 1/3 (P01, 0%)  |  lock: free`
- **Line 3**: fields 4 + 5 separated by `  |  ` (two spaces, pipe,
  two spaces). Example:
  `last_dispatch: 12m ago  |  last_verify: pass`

The three-line packing is byte-stable. T03's renderer MUST NOT insert
extra whitespace or punctuation, MUST NOT collapse lines under narrow
terminals, and MUST NOT add color codes to the headline block (color
belongs to `sections`, not to the headline; AD-2 unconditional ANSI
strip applies under `--format=json` regardless).

## Embedded Footer

Under `efficiency_footer: true` (the default), the M027
`scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>`
line follows the three-line headline block verbatim, with no
intervening blank line transformation that the M027 helper itself
does not already perform. The headline does NOT re-render or
reformat the footer; it embeds it.

Under `efficiency_footer: false` (or `--quiet`), the footer line
disappears with no other side effect. The three-line headline block
remains unchanged. CON-5 suppression-matrix inheritance from M027
governs every sub-knob of the footer transparently.

The footer is governed by M027's resolution chain:

1. Environment variable `ORCH_EFFICIENCY_FOOTER` (highest precedence).
2. Local config (`.orchestrator/config.yaml` or equivalent).
3. Project config (`.orchestrator/config.yaml` at project root).
4. Defaults (default `true`).

M029 introduces NO new resolution layer here. The headline embeds
the footer verbatim and lets M027's existing resolution chain
decide whether the footer renders.

## Regex

The canonical SC-2 regex that asserts the headline shape. The regex
block is named `headline-regex` and is the ground truth that
`tests/m029-acceptance/p01-sc2-headline.sh` greps against the
renderer's stdout. T03's headline implementation MUST emit lines
that match these regexes byte-for-byte; SC-2 fails on any drift.

```
# headline-regex (POSIX extended; tested against the first three non-blank lines of stdout)
line1: ^M[0-9]{3} .+$
line2: ^phase [0-9]+/[0-9]+ \(P[0-9]{2}, [0-9]+%\)  \|  lock: (free|held by PID [0-9]+ since .+)$
line3: ^last_dispatch: ([0-9]+[smhd] ago|none)  \|  last_verify: (pass|fail|none)$
```

Notes:

- The separator on lines 2 and 3 is exactly two spaces, a pipe, and
  two spaces (`  |  `). The regex literal `  \|  ` reflects this.
- The phase block on line 2 is exactly `(P##, K%)` with the `%` sign
  and zero-padded phase index. The percent value is an integer with
  no decimal places.
- The recency token on line 3 is exactly one of `Ns ago`, `Nm ago`,
  `Nh ago`, `Nd ago`, or the literal `none`. Non-integer or
  fractional recency tokens (e.g., `1.5h ago`) are not permitted.
- The verify-result token is exactly one of `pass`, `fail`, `none`.
  No other tokens are permitted.

## CON-5 Suppression Matrix

M029 inherits M027's suppression knobs transparently:

- `efficiency_footer: false` → the footer line disappears (the
  three-line headline block remains unchanged).
- Other M027 knobs that gate sub-surfaces of the footer (e.g.,
  `display_thresholds.compression_savings_pct` for footer line
  visibility) propagate verbatim. M029 does not interpose its own
  threshold knobs in P01.
- Quiet mode (`--quiet`) collapses to `efficiency_footer: false`
  semantics for the embedded footer; the three-line headline block
  remains.

M029 introduces NO new suppression knobs in P01. AD-5's
`display_thresholds.compression_savings_pct` knob is a P03
deliverable, not a P01 contract concern. P01 ships only the
headline shape and the JSON schema; suppression matrix changes are
out of scope.

## Cross-References

- `references/status-json-schema.md` — companion contract. The five
  headline fields appear as top-level JSON keys in the schema. Drift
  between the two files is a contract violation; gate verifiers
  cross-check field presence in both directions.
- `commands/status.md` — consumer. T03 wires the headline into the
  status command's rendered output; the headline block prepends
  the existing flat-section markdown body.
- `scripts/diagnostics/efficiency-footer.sh` — M027 footer helper
  that the headline embeds verbatim under `efficiency_footer: true`.
- Spec entries: FR-2 (status headline requirement), SC-2 (acceptance
  criterion that asserts the headline regex), AD-1 (single-resolve
  invocation context discipline that drives the headline rendering
  path), CON-5 (suppression-matrix inheritance from M027).

The contract is consumed by every later P01 task: T03 reads the
field order, line-packing, and regex; T04 reads the field set as
the source of truth for the JSON top-level keys; T05's context
skill cross-references this contract in its body; T06's phase suite
chains the gate verifier as gate 1.
