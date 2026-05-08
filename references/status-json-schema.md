---
schema_version: "1.0"
type: status-json-schema
milestone: "M029"
phase: "P01"
created_at: "2026-05-05"
---

# Status JSON Schema

This document is the canonical Principle III design contract for the
`orchestrator:status --format=json` output (FR-3 / SC-3 of the M029
spec at `specs/037-roadmap-visibility-cli-ux/spec.md`). Per the SC-3
explicit clause and the arbiter ruling 2026-05-05 (RISK-7 / MIT-10),
this file MUST be on disk before any FR-3 implementation work begins.
T04 (the `--format=json` wiring + `scripts/diagnostics/render-status-json.sh`)
consumes this contract as the single source of truth for the JSON
shape, the ANSI strip rule, and the degraded-state envelope.

The companion contract for the human-readable headline view of the
same five top-level fields is `references/status-headline-shape.md`.
The two files MUST stay paired: the five headline fields (milestone
ID + name, phase index + percent, lock state, last-dispatch recency,
last-verify result) appear as the corresponding top-level JSON keys
in the schema. Drift between the two files is a contract violation;
the gate verifiers cross-check field presence in both directions.

## schema_version

`schema_version` is `"1.0"` from day 1 per AD-7 of the M029 spec.
Future field additions are non-breaking under semver-style minor
bumps. Field removals or type changes require a major bump and a
deprecation cycle. M035 packaging consumes this schema as a public
surface; post-launch `external-tool-adapters` consumes it for
GitHub Projects / Trello / Notion / Linear adapters.

The `schema_version` field is the first key emitted in the JSON
object (rendering order is conventional, not contractual; consumers
MUST NOT depend on key order — JSON object key order is per the
JSON spec). Renderers MUST emit `schema_version` as a literal
string, not a number; downstream consumers parse the string
directly to detect compatibility.

Versioning operations:

- **Field addition** (non-breaking): minor bump (`1.0` → `1.1`).
  Older consumers ignore the new field; newer consumers read it.
- **Field removal** (breaking): major bump (`1.0` → `2.0`) AND a
  deprecation cycle of at least one minor release where the field
  is documented as deprecated before it is removed.
- **Type change** (breaking): same as field removal — major bump
  + deprecation cycle.

## Top-Level Keys

The required top-level keys are documented below as a fenced JSON
block illustrating the canonical shape:

```json
{
  "schema_version": "1.0",
  "milestone_id": "M029",
  "milestone_name": "Roadmap Visibility & CLI UX",
  "phase_index": 1,
  "phase_count": 3,
  "phase_percent_complete": 0,
  "lock_state": "free",
  "last_dispatch_recency": "12m ago",
  "last_verify_result": "pass",
  "sections": {
    "progress": "Milestone: 0/3 phases complete (0%)\n...",
    "blockers": "...",
    "execution_history": "...",
    "telemetry_metrics": "...",
    "efficiency_footer": "Efficiency (Tier 1 rollup)\n...",
    "next_action": "Run /orchestrator-dispatch to execute the next task."
  }
}
```

Per-key types and headline-field mapping:

- `schema_version: string` — locked at `"1.0"` per AD-7.
- `milestone_id: string` — e.g., `"M029"`. Maps to headline field 1.
- `milestone_name: string` — e.g., `"Roadmap Visibility & CLI UX"`.
  Maps to headline field 1.
- `phase_index: integer` — 1-based active phase index. Maps to
  headline field 2.
- `phase_count: integer` — total phases in the active milestone.
  Maps to headline field 2.
- `phase_percent_complete: integer` — percentage of phases complete
  in the active milestone (integer, no decimal). Maps to headline
  field 2.
- `lock_state: string` — exactly one of `"free"` or
  `"held by PID <pid> since <timestamp>"`. Maps to headline field 3.
- `last_dispatch_recency: string` — exactly one of `"Ns ago"`,
  `"Nm ago"`, `"Nh ago"`, `"Nd ago"`, or `"none"`. Maps to
  headline field 4.
- `last_verify_result: string` — exactly one of `"pass"`, `"fail"`,
  or `"none"`. Maps to headline field 5.
- `sections: object` — keyed object whose values are
  ANSI-stripped strings (see `## sections` below). Each section is
  the rendered markdown of the corresponding flat-section block in
  the legacy `commands/status.md` body.

An optional `state` key MAY appear at the top level when the
JSONL stream parses with errors; see `## Edge Cases` below.

## sections

Every string value under `sections` is ANSI-stripped unconditionally
regardless of TTY. The TTY split (auto-strip on pipe/CI, retain on
TTY) applies to the legacy markdown flat-section path; under
`--format=json`, ANSI is stripped from every section's rendered
string before JSON serialization.

The strip primitive is the regex `\x1b\[[0-9;]*[mGKHF]` applied with
`sed` (or equivalent). `scripts/diagnostics/render-status-json.sh`
is the single strip site — no other call site re-strips, and no
section-renderer is permitted to bypass the strip. AD-2's
unconditional-strip rule is load-bearing: downstream consumers
(M035 post-install verifier, post-launch `external-tool-adapters`)
parse the JSON and embed the section strings into their own UI;
embedded ANSI escapes corrupt those embeddings.

Section keys are conventional and may grow over time under semver
minor bumps; current keys include `progress`, `blockers`,
`execution_history`, `telemetry_metrics`, `efficiency_footer`,
`next_action`. Renderers MUST NOT emit a section key with a `null`
or empty-string value when the corresponding section is suppressed
(e.g., `efficiency_footer: false`); the key is omitted entirely
under suppression. Consumers test for key presence to detect
suppression.

## Edge Cases

When `execution-log.jsonl` parses with errors, the renderer emits a
JSON object with `state: "degraded"` and a `parse_errors` array of
one human-readable string per invalid line. The renderer never
crashes on a corrupt JSONL stream; the operator sees a
degraded-but-valid response instead. All other top-level keys
remain populated to whatever extent the partial parse permits.

The degraded-state envelope:

```json
{
  "schema_version": "1.0",
  "state": "degraded",
  "parse_errors": [
    "line 42: invalid JSON token at column 17",
    "line 88: missing required field 'task_id'"
  ],
  "milestone_id": "M029",
  "milestone_name": "Roadmap Visibility & CLI UX",
  "phase_index": 1,
  "phase_count": 3,
  "phase_percent_complete": 0,
  "lock_state": "free",
  "last_dispatch_recency": "12m ago",
  "last_verify_result": "pass",
  "sections": {
    "progress": "...",
    "blockers": "..."
  }
}
```

Notes:

- `state` is OPTIONAL. It is emitted ONLY when at least one
  `parse_errors` entry would be emitted; in the steady-state
  (no parse errors), neither `state` nor `parse_errors` appears.
- `parse_errors[*]` are human-readable strings. The exact wording
  is not contractual, but each string MUST identify the offending
  line number and a one-clause reason.
- Other top-level keys are populated on a best-effort basis. If
  the partial parse cannot determine a specific field (e.g., the
  active-milestone derivation depends on a corrupt log entry),
  that field MAY fall back to a documented sentinel (e.g.,
  `last_dispatch_recency: "none"`). The renderer MUST NOT omit
  required top-level keys; required keys remain present with
  sentinel values.

## ANSI Strip Primitive

The exact ANSI strip primitive is the regex `\x1b\[[0-9;]*[mGKHF]`.
A reference shell implementation:

```sh
sed 's/\x1b\[[0-9;]*[mGKHF]//g'
```

This regex matches the CSI (Control Sequence Introducer) sequences
that ANSI color codes, cursor-positioning escapes, and screen-clear
escapes use. Renderers MUST apply this primitive (or an equivalent
that strips the same escape set) before JSON serialization of any
`sections` value.

The primitive is intentionally conservative: it strips CSI sequences
that end in `m` (color/style), `G` (cursor horizontal absolute),
`K` (erase in line), `H` (cursor position), `F` (cursor previous
line). It does NOT strip OSC (Operating System Command) sequences
or other less-common terminal control codes; if such codes appear
in a section's rendered output, that is a bug in the section
renderer, not a gap in this primitive.

## drift (M035 P01)

The top-level `drift` field is an ADDITIVE schema-version-1.0
extension shipped by M035 P01 / T04 (FR-4). Per AD-7 stability
policy below, additive top-level fields do NOT bump
`schema_version`; the M029 cross-check verifier that asserts
`schema_version == "1.0"` byte-for-byte stays green.

The `drift` object is ALWAYS present in the envelope (the key set
is stable across availability states); suppression is signalled
via empty `rendered_line` + `update_source: none` shape rather
than via key omission. This deviates from the `sections`-side
suppression convention (where suppressed sections are omitted
entirely) — the deviation is intentional: downstream consumers
that key on `drift.update_source` need a stable shape regardless
of helper availability.

### Object Shape

```json
"drift": {
  "commits_behind": "<integer-or-string-unknown>",
  "update_source": "git|npm|homebrew|none",
  "upstream_path": "<absolute-path-or-empty>",
  "versions_behind": "<integer>",
  "rendered_line": "<exact-string-rendered-by-tui-or-empty>"
}
```

Per-key types:

- `drift.commits_behind: string` — either a numeric integer
  encoded as a string (e.g., `"14"`) or the literal token
  `"unknown"` (#Q-G5 SHA-absent fallback path). Encoded as a
  JSON string to accommodate both shapes; consumers parse the
  string and branch on `== "unknown"` or numeric.
- `drift.update_source: string` — exactly one of `"git"`,
  `"npm"`, `"homebrew"`, or `"none"`.
- `drift.upstream_path: string` — absolute filesystem path to
  the upstream repo (when `update_source=git`) or empty string
  (`""`).
- `drift.versions_behind: string` — semver-delta integer encoded
  as a string (e.g., `"3"`). Always numeric.
- `drift.rendered_line: string` — exact byte-stable line emitted
  by the TUI render path:
  `"STALE: orchestrator runtime is <N> commits behind upstream — run \`orchestrator:update\`"`.
  Empty string (`""`) under any suppression branch
  (`update_source=none`, both counts zero, helper unavailable).

### Suppression Matrix

The `rendered_line` is empty under any of:

- `update_source = "none"` (FR-16 suppression honor).
- `commits_behind = "0"` AND `versions_behind = "0"` (no drift to
  report).
- The drift helper (`scripts/state/check-orchestrator-drift.sh`)
  was missing, exited non-zero, or emitted unparseable stdout.

Under suppression, the other `drift.*` fields fall back to a
documented default shape:

```json
"drift": {
  "commits_behind": "0",
  "update_source": "none",
  "upstream_path": "",
  "versions_behind": "0",
  "rendered_line": ""
}
```

### Source

The data comes from `scripts/state/check-orchestrator-drift.sh`
(M035 P01 / T03). The helper exits 0 always (FR-15: consumers
branch on the data, not the exit code) and emits a four-line
`key=value` stdout block. The renderer parses the four
fields, computes the byte-stable rendered line, and emits the
five-key `drift` object.

## Versioning Policy

Restating AD-7's stability policy:

- `schema_version` is `"1.0"` from day 1.
- Field additions are non-breaking and ship under semver-style
  minor bumps (`1.0` → `1.1` → `1.2` ...).
- Field removals or type changes are breaking and require a major
  bump (`1.0` → `2.0`) AND a deprecation cycle of at least one
  minor release where the affected field is documented as
  deprecated before it is removed.
- Downstream consumers — M035 packaging post-install verifier,
  post-launch `external-tool-adapters` (GitHub Projects, Trello,
  Notion, Linear) — pin to `schema_version` major and tolerate
  minor bumps. A major bump is a coordinated release event.

The schema is a public contract. Renderers and consumers
collaborate via this contract; private extensions (e.g., a
project-specific top-level key) are NOT permitted under
`schema_version: "1.0"`. If a project needs a project-specific
field, the path is to propose a schema field addition, ship it
under a minor bump, and consume it via the standard schema.

## Cross-References

- `references/status-headline-shape.md` — companion contract. The
  five headline fields are the same as the corresponding top-level
  JSON keys in this schema. Drift between the two files is a
  contract violation; gate verifiers cross-check field presence
  in both directions.
- `commands/status.md` — consumer. T03 wires the headline; T04
  wires `--format=json` and produces the JSON envelope documented
  here.
- `scripts/diagnostics/render-status-json.sh` — the single
  ANSI-strip site. T04 authors this script; this contract is its
  upstream design document.
- `scripts/state/detect-invocation-context.sh` — the M029 P01
  invocation-context resolver. The JSON renderer reads
  `renderer=json` + `exit_code_scheme=governance` from this
  resolver's emitted env block (AD-1 single-resolve discipline).
- Spec entries: FR-3 (`--format=json` requirement), SC-3
  (acceptance criterion that asserts the JSON shape), AD-1
  (single-resolve invocation context discipline), AD-2
  (unconditional ANSI strip under `--format=json`), AD-7
  (`schema_version: "1.0"` from day 1 + stability policy).
- Downstream consumers: M035 packaging (post-install verifier
  parses this schema), post-launch `external-tool-adapters`
  (GitHub Projects, Trello, Notion, Linear adapters parse this
  schema).
