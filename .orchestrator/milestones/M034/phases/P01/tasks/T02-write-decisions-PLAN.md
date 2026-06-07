---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M034"
name: "write-decisions.sh — stdin-JSON writer with supersede chain"
depends_on: ["T01"]
---

## Prerequisites

- `scripts/knowledge/lib/decisions-constants.sh` exists (T01 deliverable — the CON-4 SSOT). The writer sources it for `DECISIONS_SCHEMA_VERSION`, `DECISIONS_SEVERITY_DEFAULT`, `DECISIONS_TYPE_DEFAULT`.
- `templates/decisions-packet.md` exists (T01 deliverable — the emit format the writer must match).
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` exists (the round-trip target).
- `scripts/knowledge/write-summary.sh` exists (prior-art single-file bash writer shape).
- `jq` is available at `/usr/bin/jq` (confirmed at plan-authoring time). The writer REQUIRES it.

## Description

FR-2/FR-3 + PC-1 + #Q-1. Author `scripts/knowledge/write-decisions.sh`: a bash 3.2 single-file helper that reads the full FR-1 decision-entry array as a JSON document on stdin and emits a schema-valid `*-DECISIONS.md` packet matching `templates/decisions-packet.md`. It implements the #Q-1 append-with-supersede-chain so re-runs preserve audit history.

The PC-1 calling convention (binding, from `M034-P00-ADDENDUM.md`):

```
write-decisions.sh --milestone=<M> --artifact=<primary-artifact-path> --out=<packet-path>  < entries.json
```

- `--out=-` writes the packet to stdout (mirrors `write-summary.sh`'s `-` sentinel).
- `--milestone`/`--artifact`/`--out` are flag args carrying only ids/paths — never free text.
- stdin wire format: `{"decisions": [ { "id", "summary", "picked_value", "rationale", "alternatives_considered", "concrete_impact", "severity", "type" }, ... ]}`. Keys are EXACTLY the FR-1 names. `severity`/`type` may be absent → writer applies the SSOT defaults.
- **Escaping contract**: NONE required of the caller. Each field is extracted with `jq -r` and written via a quoted variable expansion / `printf '%s'`. The writer NEVER re-shell-interprets a field body (no `eval`, no unquoted re-expansion). This is the RISK-1 property.

## Steps

1. Resolve the script dir and source the SSOT: `. "$SCRIPT_DIR/lib/decisions-constants.sh"`.

2. **jq-required guard.** If `command -v jq` fails, print to stderr `ERROR: write-decisions.sh requires jq (structured multi-entry parse). Install jq and retry.` and exit 1. (PC-1 packaging note — jq moves from optional to required for THIS script; FR-12 strict-when-missing-tooling posture.)

3. Parse `--milestone=`/`--artifact=`/`--out=` flags (same `--*=*` branch shape as `write-summary.sh:94-101`). Validate all three present; on a missing flag, error + exit 1. Reject any positional/unknown arg.

4. Read all of stdin into a variable. Validate it is a JSON object with a `.decisions` array via `jq -e '.decisions | type == "array"'`; on failure, error `ERROR: stdin is not a {"decisions":[...]} document` + exit 1.

5. **Per-entry field extraction.** Iterate the array by index using a count from `jq '.decisions | length'`. For each index `i`, extract each field with `jq -r ".decisions[$i].<field> // empty"`. Apply defaults when empty: `severity` → `$DECISIONS_SEVERITY_DEFAULT`, `type` → `$DECISIONS_TYPE_DEFAULT`. Validate severity/type against the SSOT validators (`decisions_is_valid_severity`/`decisions_is_valid_type`); on an invalid value, error naming the entry id + the bad value + exit 1.

6. **content_hash** (idempotency key). Compute a hash over the field BODIES (the eight FR-1 fields except `id`, in a fixed order: summary, picked_value, rationale, alternatives_considered, concrete_impact, severity, type). Concatenate them with a `\x1f` (unit-separator) delimiter into one string and pipe through `shasum -a 256`, keeping the first 16 hex chars: `printf '%s' "$concat" | shasum -a 256 | cut -c1-16`. (Pipes/`cut` inside the script body are permitted — the AD-19 shape rules govern plan `Check:` lines, not verifier/helper internals; cf. `write-summary.sh`'s internal awk/pipe use.)

7. **Append-with-supersede-chain (#Q-1).** Determine the output mode:
   - **`--out=-` (stdout) OR the `--out` file does not exist**: emit a fresh packet — frontmatter (`schema_version` from SSOT, `type: decision-packet`, `milestone`, `source` = artifact label, `artifact`) + one `## D-N` block per entry including its computed `content_hash`. No supersede fields on first emit.
   - **`--out` file exists**: for each incoming entry with base-id `B` (strip any `-vN` suffix to get the logical id):
     - Find the chain tip in the existing file: the highest-version entry for base-id `B` that has NO `superseded_by:` marker (scan `## B`, `## B-v2`, ... blocks). If none exists for `B`, the entry is NEW → append a fresh `## B` block with its content_hash.
     - If a tip exists and its `content_hash` EQUALS the incoming entry's hash → **idempotent no-op** (do not write a new block, do not touch the file for this entry).
     - If a tip exists and the hash DIFFERS → append a new block with id `B-v<N+1>` carrying `supersedes: <tip-id>` + its new content_hash, AND amend the tip block in place to add `superseded_by: B-v<N+1>` (mirror `extract-supersede.sh::supersede_amend_prior_chunk` — awk insert after the `content_hash` line, tmpfile + `mv`).

8. **Emit format** — each `## <id>` block matches `templates/decisions-packet.md` EXACTLY (bold-key bullet lines), with the supersede fields appended only when set:

```
## D-1
- **id**: D-1
- **summary**: <body>
- **picked_value**: <body>
- **rationale**: <body>
- **alternatives_considered**: <body>
- **concrete_impact**: <body>
- **severity**: block
- **type**: decision
- **content_hash**: <16-hex>
```

   For a superseding entry also emit `- **supersedes**: <tip-id>` after `content_hash`; for an amended prior entry insert `- **superseded_by**: <new-id>` after its `content_hash` line.

9. On success print `DECISIONS: <N> entries written to <out>` to stdout (`N` = entries actually written, excluding no-ops). Do NOT emit any `unit_close` JSONL (that is write-summary's concern, not this writer's).

10. Co-author `tools/verify/m034-p01-writer.sh`: (a) build a `{"decisions":[...]}` doc from the eight P00 baseline entries (a heredoc fixture inside the verifier, or `jq` reshaping the fixture) and assert the writer emits a packet whose `## D-N` blocks carry all eight required fields + a `content_hash`; (b) re-run with the SAME input against the SAME `--out` file and assert NO new blocks appear (idempotent no-op); (c) re-run with one entry's `rationale` changed and assert a `-v2` block appears carrying `supersedes:` and the prior block gains `superseded_by:`; (d) run with `jq` shadowed/unavailable (e.g. `PATH=/nonexistent` for the `command -v` probe via a test seam, OR assert the guard message exists by source-grep) and assert the jq-required error path. Write the packet under `tmp/` or `$TMPDIR` (throwaway). Print `PASS: m034-p01 writer` on success, `FAIL: ...` + exit 1 otherwise.

## Must-Haves

- The writer reads `{"decisions":[...]}` on stdin, extracts fields with `jq -r`, never re-shell-interprets bodies, and accepts `--milestone`/`--artifact`/`--out` (PC-1, FR-2).
- The writer errors clearly and exits non-zero when jq is absent (PC-1 packaging note).
- Re-emitting unchanged entries is a no-op; changed entries append a `-vN` superseding block and mark the prior `superseded_by:` (#Q-1).
- A packet built from the P00 baseline entries carries all eight required fields per entry + a content_hash (FR-1/SC-1 coverage).

## Verification

`bash tools/verify/m034-p01-writer.sh`
`grep -q "command -v jq" scripts/knowledge/write-decisions.sh`
`grep -q "supersede" scripts/knowledge/write-decisions.sh`

## Notes

Expected: `bash tools/verify/m034-p01-writer.sh` prints `PASS: m034-p01 writer` and exits 0; the two `grep` commands exit 0. The writer is modeled on `write-summary.sh`'s flag-parse + `build_output` shape but diverges on input (stdin JSON, not `--field=` flags) and adds the supersede chain — both justified in `M034-P00-ADDENDUM.md` PC-1 / #Q-1.

Hashing: `shasum -a 256` is present on both macOS and Linux. If a target lacks it, `cksum` is an acceptable fallback — but pick ONE deterministic hash and document it inline; the content_hash only needs intra-file stability (idempotency), not cross-machine reproducibility.

The writer is the consumer of the PC-1 LLM-instruction-template contract: the artifact-authoring task (P02+) emits exactly the `{"decisions":[...]}` shape this writer parses. Do not add alias keys.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/lib/decisions-constants.sh` (T01) — source it. Provides `DECISIONS_SCHEMA_VERSION`, `DECISIONS_SEVERITY_DEFAULT="block"`, `DECISIONS_TYPE_DEFAULT="decision"`, and the `decisions_is_valid_severity`/`decisions_is_valid_type` validators (each prints `ok` for a valid value, else empty).
- `templates/decisions-packet.md` (T01) — the exact emit shape (frontmatter + `## D-N` bold-key bullet blocks).
- `scripts/knowledge/write-summary.sh` — prior-art: flag parse at `:76-107`, `--*=*` branch at `:94-101`, `build_output()` heredoc-free `echo` emission at `:173-208`, `-`-for-stdout at `:218-225`.
- `scripts/knowledge/lib/extract-supersede.sh` — `supersede_amend_prior_chunk()` at `:80-96` is the in-place amend pattern (awk insert after `content_hash:` + tmpfile/`mv`); adapt it for the `- **superseded_by**:` bullet shape.
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` — the 8-entry round-trip target.

## Constraints

- Bash 3.2 / POSIX-sh single file (CON-1 / AD-19): no `declare -A`, no `${var,,}`, no process substitution. Pipes/`awk`/`cut`/`$()` ARE permitted inside the script body (helper-internal, MEM004 carve-out) — the AD-19 prohibition targets plan `Check:` command lines.
- jq is REQUIRED (hard dependency for this script only); fail loud if absent.
- NEVER `eval` or unquoted-re-expand a field body (RISK-1).
- Do NOT author the reader (T04), the producer (T03), or modify status/doctor.

## Expected Output

`scripts/knowledge/write-decisions.sh` + `tools/verify/m034-p01-writer.sh` created. The writer round-trips the baseline entries, is idempotent on unchanged re-emit, appends a supersede chain on change, and fails loud without jq.
