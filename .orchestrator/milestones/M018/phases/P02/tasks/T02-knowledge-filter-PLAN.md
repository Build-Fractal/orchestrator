---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M018"
name: "Knowledge-aware filter in build-context.sh + config key + payload_filter emitter + filter_dropped_tokens field"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed `scripts/lib/preservation-check.sh`. Sourcing the library exposes `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check`, `PRES_PATTERNS_REGEX`, `PRES_PATTERN_NAMES`. T02 sources the library defensively (the filter operates on whole-entry granularity per grammar contract `## Tier: filter` failure semantics — there is no preserved-pattern self-check at the entry interior — but sourcing the library now means P03/P04/P06 inherit a working source path with no further wiring).
- `references/compression-grammar.md` `## Tier: filter` (lines 144–164) names the contract: filter reads each knowledge entry's `status:` field; drops list-matched values; missing `status:` → RETAINED (fail-open); parse error on `status:` → RETAINED + `entry_status_unparseable` field on the `payload_filter` record.
- `scripts/dispatch/build-context.sh` is the integration target. Filter integration lands BEFORE `_bc_emit_payload_breakdown` (line 1042 in current file); the precise insertion point is inside `_bc_gather_knowledge_from_index` and `_bc_gather_knowledge_flat` (lines 382–482) — both knowledge-gather paths must apply the filter so the filter is path-independent.
- M020 ships the `status:` field on knowledge entries. Per the planning payload note, most pre-M020 entries default to `graduated`. The filter treats absent `status:` field as `stable` (per spec FR-3 + grammar contract `## Tier: filter` failure semantics). The filter does NOT special-case `graduated` — it drops only what `compression.knowledge_filter.drop_list` names, defaulting to `["superseded", "experimental"]`.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans compound chains > 2, plain subshells, `$(... | ...)`. `build-context.sh` already complies; T02's additions must too.

## Description

Wire the knowledge-aware injection filter into `scripts/dispatch/build-context.sh`. The filter:

1. Reads `compression.knowledge_filter.drop_list` from `.orchestrator/config.yml` (default: `["superseded", "experimental"]`).
2. Honors a `compression.enabled: false` short-circuit (FR-15 / SC-8) — when disabled, the filter is a no-op and the Knowledge section is byte-identical to the pre-M018 baseline.
3. For each knowledge entry resolved by the existing scope-filter pipeline (`scripts/knowledge/resolve-entries.sh` output), reads the entry's `status:` frontmatter field. If the value matches the drop-list, the entry is excluded from the payload. Missing field → retained (fail-open per A-1 + grammar contract).
4. When the filter drops at least one entry, emits a `payload_filter` JSONL record to `execution-log.jsonl` with the schema below, AND the existing `_bc_emit_payload_breakdown` function adds an additive `filter_dropped_tokens` field to the `payload_breakdown` record.
5. When the entire Knowledge section becomes empty (filter dropped every entry), emits the literal `(no qualifying knowledge entries)` instead of an empty section, preserving downstream-parser shape (spec acceptance scenario 5).

`payload_filter` JSONL record schema (additive — CON-5):

```json
{
  "record_type": "payload_filter",
  "filter": "knowledge_status",
  "drop_list": ["superseded", "experimental"],
  "dropped_count": 3,
  "dropped_tokens": 1247,
  "dropped_ids": ["MEM042", "MEM055", "MEM061"],
  "source": "runtime",
  "unitId": "M018/P02/T02",
  "milestone": "M018",
  "phase": "P02",
  "task": "T02",
  "timestamp": "2026-04-27T14:23:01Z"
}
```

The `payload_breakdown` extension is additive: existing record stays valid; a new optional `filter_dropped_tokens` field is added at top level (sibling of `payload_tokens_estimate`). Pre-M018 records remain valid JSON (CON-5 — missing field treated as null by post-M018 rollups).

## Steps

1. **Add `compression:` block to `.orchestrator/config.yml`** (and mirror in `templates/config-defaults.yml`):

   ```yaml
   # M018 — Context Compression Layer
   compression:
     enabled: true                      # FR-15: master toggle. false → entire pipeline short-circuits.
     knowledge_filter:
       enabled: true                    # FR-3: tier-specific toggle.
       drop_list:                       # FR-3: status: values that trigger drop.
         - superseded
         - experimental
   ```

   Use `Edit` to insert the block at end of file. Keep ordering: append after the existing `comments:` block. Preserve existing keys.

2. **Author a small helper in `build-context.sh`** to read the drop-list. The existing `config_read` helper (line 141) reads scalar keys; the drop-list is a YAML array. Add a sibling helper:

   ```bash
   # Reads compression.knowledge_filter.drop_list as newline-separated values.
   # Returns the default 'superseded\nexperimental' if the key is absent or the
   # config is missing. Bash 3.2; AP-009 compliant (no compound chain > 2,
   # no $(...|...)).
   _bc_read_drop_list() {
     local cfg="$ORCH_ROOT/config.yml"
     [ ! -f "$cfg" ] && cfg="$PROJECT_ROOT/.orchestrator/config.yml"
     if [ ! -f "$cfg" ]; then
       printf 'superseded\nexperimental\n'
       return
     fi
     # Single-pass awk: find drop_list:, then collect subsequent leading-dash bullets
     # until the indent level exits or a non-bullet line appears.
     awk '
       BEGIN { in_block=0 }
       /^[[:space:]]*drop_list:[[:space:]]*$/ { in_block=1; next }
       in_block==1 {
         if ($0 ~ /^[[:space:]]+-[[:space:]]+[A-Za-z_-]+/) {
           sub(/^[[:space:]]+-[[:space:]]+/, "")
           gsub(/[[:space:]]+$/, "")
           print
         } else if ($0 ~ /^[^[:space:]]/) {
           in_block=0
         }
       }
     ' "$cfg"
   }
   ```

   Place this helper between `config_read` (line 141) and the `CONTEXT_VERBOSITY=` line (line 153).

   Add a sibling read for `compression.enabled` and `compression.knowledge_filter.enabled` (both scalar — use the existing `config_read`):

   ```bash
   COMPRESSION_ENABLED="$(config_read 'compression.enabled' true)"
   KNOWLEDGE_FILTER_ENABLED="$(config_read 'compression.knowledge_filter.enabled' true)"
   ```

   Verify the existing `READ_CONFIG` script (`bash "$READ_CONFIG" key`) handles dotted keys. If not, fall back to a per-key awk grep similar to `_bc_read_drop_list`. (The codebase already uses dotted keys in `comments.auto_apply_threshold.uat-bug` etc., so the reader supports them — confirm by `grep dotted scripts/util/read-config.sh` before assuming.)

3. **Author the filter function** `_bc_filter_knowledge_by_status`. Place it near `_bc_gather_knowledge_from_index` (around line 380):

   ```bash
   # Input on stdin: resolved knowledge entries (output of $RESOLVE_ENTRIES) — a
   # multi-entry markdown stream where each entry begins with a YAML frontmatter
   # block (^---$ ... ^---$) and ends before the next ^---$ at column 0.
   # Output on stdout: the filtered stream, with drop-list-matching entries removed.
   # Side effect: writes a stats line to $TMPDIR_BUILD/_filter_stats.txt of the form:
   #   dropped_count=<N> dropped_tokens=<N> dropped_ids=<comma-separated>
   # The caller reads this file to emit the payload_filter JSONL record.
   _bc_filter_knowledge_by_status() {
     local drop_list_file="$1"
     local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
     local dropped_count=0 dropped_tokens=0 dropped_ids=""

     # Short-circuit when filter is disabled.
     if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$KNOWLEDGE_FILTER_ENABLED" != "true" ]; then
       cat
       printf 'dropped_count=0 dropped_tokens=0 dropped_ids=\n' > "$stats_file"
       return 0
     fi

     # Stage stdin to a temp file so we can iterate by entry.
     local in_file="$TMPDIR_BUILD/_filter_in.md"
     cat > "$in_file"

     # Split into entries by ^---$ frontmatter delimiter pairs. Use awk to
     # output one entry per record-separator-bracketed block.
     local out_file="$TMPDIR_BUILD/_filter_out.md"
     : > "$out_file"

     # Single-pass awk: track frontmatter open/close, capture status: field
     # within frontmatter, and decide retain/drop on the close delimiter.
     awk -v drop_file="$drop_list_file" -v stats_file="$stats_file" '
       BEGIN {
         # Load drop-list into associative-style keyed lookup. awk gawk has true
         # associative arrays — we are not bound by bash 3.2 here.
         while ((getline d < drop_file) > 0) {
           gsub(/[[:space:]]+/, "", d)
           if (d != "") drop[d] = 1
         }
         in_fm = 0
         entry_buf = ""
         status_val = ""
         entry_id = ""
         dropped_count = 0
         dropped_tokens = 0
         dropped_ids = ""
       }
       {
         entry_buf = entry_buf $0 "\n"
         if ($0 == "---") {
           if (in_fm == 0) {
             in_fm = 1
           } else {
             in_fm = 0
             # Frontmatter just closed. Continue reading body until next "---" at col 0
             # or EOF.
             next
           }
         }
         if (in_fm == 1 && $0 ~ /^status:[[:space:]]/) {
           status_val = $0
           sub(/^status:[[:space:]]*/, "", status_val)
           sub(/[[:space:]]+$/, "", status_val)
           gsub(/^"|"$/, "", status_val)
         }
         if (in_fm == 1 && $0 ~ /^id:[[:space:]]/) {
           entry_id = $0
           sub(/^id:[[:space:]]*"?/, "", entry_id)
           sub(/"?[[:space:]]*$/, "", entry_id)
         }
       }
       # Detect entry boundary: a line that is exactly "---" AND the next line
       # starts a new entry frontmatter. We approximate: flush on next "id:" at
       # frontmatter open OR at EOF.
       /^---$/ && in_fm == 1 && entry_buf != "" {
         # second occurrence above flips in_fm to 0; this path is the start of
         # the NEXT entry frontmatter or trailing body. We handle the simpler
         # rule below at END.
       }
       END {
         # Final flush: decide on the last entry buffered.
         _decide(entry_buf, status_val, entry_id)
         printf "dropped_count=%d dropped_tokens=%d dropped_ids=%s\n", \
           dropped_count, dropped_tokens, dropped_ids > stats_file
       }
       function _decide(buf, st, eid,    keep, tok) {
         keep = 1
         if (st != "" && (st in drop)) keep = 0
         tok = int(length(buf) / 4)   # rough char-quartile estimate
         if (keep == 1) {
           printf "%s", buf
         } else {
           dropped_count++
           dropped_tokens += tok
           if (dropped_ids == "") dropped_ids = eid
           else dropped_ids = dropped_ids "," eid
         }
       }
     ' "$in_file" > "$out_file"

     cat "$out_file"
   }
   ```

   **NOTE on the awk above**: the entry-boundary detection in real M018 code needs to actually flush on EVERY entry boundary, not just at EOF. The simplified single-flush version above is a placeholder — when implementing, scan multiple `^---$` pairs and flush per entry. Two production-clean approaches:
   - **Approach A (recommended)**: pre-split the input file with a Python-free shell pre-pass — `awk '/^---$/ {n++} {print n " " $0}' "$in_file"` numbers every line by block. Group pairs (n=1+2 = entry 1 frontmatter; n=3 = entry 1 body until next n=4 opens entry 2 frontmatter). This is more verbose but each step is a single command.
   - **Approach B**: process entry-by-entry by splitting on the `^---$` *boundary between entries* (the resolved-entries stream from `$RESOLVE_ENTRIES` separates entries by a closing `---` followed by a blank line followed by the next opening `---`). Use awk's `RS` set to that boundary.

   Pick Approach A for clarity and AP-009 compliance. Implement step-by-step; test against the fixture in step 7 before integrating.

4. **Wire the filter into both knowledge-gather paths**. In `_bc_gather_knowledge_from_index` (around line 463 where the function does `echo "$resolved"`), pipe the resolved entries through the filter:

   ```bash
   # Write drop list to a temp file for the filter awk to read.
   local drop_list_file="$TMPDIR_BUILD/_drop_list.txt"
   _bc_read_drop_list > "$drop_list_file"

   if [ -z "$resolved" ]; then
     echo "No knowledge entries in scope."
   else
     local entry_count
     entry_count="$(echo "$all_ids" | grep -c 'MEM' 2>/dev/null || echo 0)"
     echo "<!-- $entry_count knowledge entries resolved from index -->"
     echo ""
     # Apply M018/P02 status filter.
     printf '%s\n' "$resolved" | _bc_filter_knowledge_by_status "$drop_list_file"
   fi
   ```

   In `_bc_gather_knowledge_flat` (around line 480 where it does `echo "$entries"`), do the same pipe.

   Handle the empty-after-filter case (spec acceptance scenario 5): if the filter dropped every entry, emit `(no qualifying knowledge entries)`. Detect this by checking the post-filter byte count or grep-count for `^---$` frontmatter delimiters in the filter output.

5. **Source the preservation library defensively**. At the top of `build-context.sh` (just after `config_read` definition, around line 152), add:

   ```bash
   # M018/P02: source preservation-check library so downstream tier wiring inherits
   # a single source path. The filter operates on whole-entry granularity (no
   # interior preservation check per grammar contract `## Tier: filter` failure
   # semantics), so no caller wires pres_check_section yet.
   if [ -r "$PROJECT_ROOT/scripts/lib/preservation-check.sh" ]; then
     . "$PROJECT_ROOT/scripts/lib/preservation-check.sh" || true
   fi
   ```

6. **Extend `_bc_emit_payload_breakdown`** (line 1042) to include `filter_dropped_tokens` when present. Read the stats file (`$TMPDIR_BUILD/_filter_stats.txt`); parse `dropped_tokens=N`; default to 0 when the file is missing (e.g., when the planning branch did not run knowledge gather, or filter was disabled). Add the field to the existing `printf` JSONL line:

   ```bash
   local filter_dropped_tokens=0
   local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
   if [ -f "$stats_file" ]; then
     filter_dropped_tokens="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_tokens=/) { sub("dropped_tokens=","",$i); print $i; exit } }' "$stats_file")"
     [ -z "$filter_dropped_tokens" ] && filter_dropped_tokens=0
   fi
   ```

   Extend the `printf` format string with `,"filter_dropped_tokens":%d` and add the variable to the value list. Ensure the field appears in the JSONL output AT THE END of the existing object so existing rollup `jq` filters that key by leading fields keep working.

7. **Emit the `payload_filter` JSONL record** when the filter dropped at least one entry. Add a new function `_bc_emit_payload_filter` near `_bc_emit_payload_breakdown` and call it from the same top-level invocation site (line 1208 region):

   ```bash
   _bc_emit_payload_filter() {
     [ "${ORCH_M019_EMIT:-1}" = "0" ] && return 0
     local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
     [ ! -f "$stats_file" ] && return 0
     local dropped_count dropped_tokens dropped_ids
     dropped_count="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_count=/) { sub("dropped_count=","",$i); print $i; exit } }' "$stats_file")"
     dropped_tokens="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_tokens=/) { sub("dropped_tokens=","",$i); print $i; exit } }' "$stats_file")"
     dropped_ids="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_ids=/) { sub("dropped_ids=","",$i); print $i; exit } }' "$stats_file")"
     [ -z "$dropped_count" ] && dropped_count=0
     [ "$dropped_count" -eq 0 ] && return 0
     local log_dir log_file ts
     log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
     [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ] && log_dir="$ORCH_ROOT"
     log_file="$log_dir/execution-log.jsonl"
     ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
     # Build dropped_ids JSON array from comma-separated string.
     local ids_json="[]"
     if [ -n "$dropped_ids" ]; then
       ids_json="[\"$(printf '%s' "$dropped_ids" | sed 's/,/","/g')\"]"
     fi
     # Build drop_list JSON array from drop-list file.
     local drop_list_file="$TMPDIR_BUILD/_drop_list.txt"
     local drop_json="[]"
     if [ -f "$drop_list_file" ]; then
       drop_json="$(awk '{ if (NR==1) printf "[\"%s\"", $0; else printf ",\"%s\"", $0 } END { print "]" }' "$drop_list_file")"
     fi
     mkdir -p "$log_dir" 2>/dev/null || return 0
     printf '{"record_type":"payload_filter","filter":"knowledge_status","drop_list":%s,"dropped_count":%d,"dropped_tokens":%d,"dropped_ids":%s,"source":"runtime","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","timestamp":"%s"}\n' \
       "$drop_json" "$dropped_count" "$dropped_tokens" "$ids_json" \
       "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
       "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
       "$ts" \
       >> "$log_file" 2>/dev/null || true
     return 0
   }
   ```

   Call it from the bottom of build-context (after `_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true`):

   ```bash
   _bc_emit_payload_filter || true
   ```

8. **Construct the test fixture**. Create `tests/fixtures/m018-p02-knowledge-status/` with:
   - `README.md` — documents the fixture's purpose: "Mixed-status knowledge entries for the M018/P02 filter verifier. 5 entries: 2 `status: stable`, 1 `status: superseded`, 1 `status: experimental`, 1 missing-status (back-compat)."
   - `KNOWLEDGE.md` — five MEM entries with the indicated `status:` field values. Use realistic content (not just lorem ipsum) so the filter's regex grep-match doesn't produce false positives.
   - `KNOWLEDGE-INDEX.md` (or whatever the existing index format is — check `scripts/knowledge/resolve-entries.sh` for the expected shape).
   - A minimal milestone scaffold (`M999-FIXTURE/M999-ROADMAP.md` etc.) so `build-context.sh` can be invoked against it.

9. **Capture a baseline golden payload** at `tests/fixtures/m018-p02-baseline-payload.golden.txt`. Run `build-context.sh` with `compression.enabled: false` against the fixture; capture the Knowledge section verbatim. SC-8 / FR-15 regression test: T04's `m018-p02-disable-flag-honored.sh` verifier diffs the disable-flag-on output against this golden.

10. **Smoke-test locally**:
    - With filter enabled (default): run `build-context.sh` against the fixture; assert the resulting payload omits the 2 drop-list-matching entries; assert `execution-log.jsonl` carries a `payload_filter` record with `dropped_count: 2`; assert the `payload_breakdown` record carries `filter_dropped_tokens > 0`.
    - With `compression.enabled: false`: run again; assert the payload's Knowledge section is byte-identical to the golden; assert no `payload_filter` record was written.
    - With missing-status entry: assert it is RETAINED (not dropped).

## Must-Haves

This task addresses the phase truths:

- The filter reads `status:` and excludes drop-list values; missing field → retained. (Verified by `bash scripts/verify/m018-p02-filter-drops.sh` from T04.)
- The `payload_filter` record is emitted; `payload_breakdown` carries `filter_dropped_tokens`; pre-M018 records remain valid JSON. (Verified by `bash scripts/verify/m018-p02-emitter-additivity.sh` from T04.)
- `compression.enabled: false` short-circuits the filter; payload byte-identical to golden. (Verified by `bash scripts/verify/m018-p02-disable-flag-honored.sh` from T04.)

## Verification

```
bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status
```

Expected: stdout payload's Knowledge section omits the 2 drop-list-matching MEM IDs; the missing-status MEM is retained; `execution-log.jsonl` (under the fixture's milestone dir) carries one new `payload_filter` line with `dropped_count: 2` and one `payload_breakdown` line with `filter_dropped_tokens` > 0.

Then run with the disable flag:

```
ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status > /tmp/p02-disabled-payload.txt
diff <(grep -A 999 '## Knowledge' /tmp/p02-disabled-payload.txt | sed -n '/^## Knowledge/,/^## /p') tests/fixtures/m018-p02-baseline-payload.golden.txt
```

(Note: the verifier T04 ships will use script-file shape per AD-19; the inline `diff <(...)` above is for manual smoke only.)

The phase-level verifier `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/` runs after T04 lands all phase-truth verifiers.

## Inputs

### From Previous Tasks

- `scripts/lib/preservation-check.sh` (from T01)
  - Key API: `pres_check_section <section_id> <pre_file> <post_file> [tier]`, `pres_emit_violation <tier> <section> <pattern> <log_file>`, `pres_density_pre_check <section_file> <max_density_pct>`.
  - Key types: parallel indexed arrays `PRES_PATTERNS_REGEX`, `PRES_PATTERN_NAMES`. Sourceable.
  - Behavioral contract: `pres_check_section` returns 0 on PASS, 1 on first violation; `pres_emit_violation` is bail-safe; `pres_density_pre_check` returns 1 (refuse) when density exceeds threshold.
  - In T02: source the library defensively. T02's filter does NOT call `pres_check_section` (filter operates on whole-entry granularity per grammar contract); the source ensures P03/P04/P06 inherit a working source path with no further wiring.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — integration target. Existing functions to extend: `_bc_gather_knowledge_from_index` (line 382), `_bc_gather_knowledge_flat` (line 467), `_bc_emit_payload_breakdown` (line 1042). Existing helpers to reuse: `config_read` (line 141), `chars_to_tokens_quartile` (sourced from `scripts/lib/pricing.sh`).
- `scripts/knowledge/resolve-entries.sh` — produces the multi-entry markdown stream the filter consumes. Output contract: each entry begins with `---\n`, ends before the next `---\n` or EOF; the entry's `status:` field appears within the frontmatter block.
- `references/compression-grammar.md` `## Tier: filter` (lines 144–164) — the failure-semantics contract: missing `status:` → retain; parse error → retain + `entry_status_unparseable` field; never crash.
- `templates/config-defaults.yml` — the canonical defaults file mirrored into `.orchestrator/config.yml`.
- `.orchestrator/scratch/m018-section-distribution-output.json` — `model_assumptions.filter` block (mean_drop=0.30, Beta(2,5) prior) informs the test fixture's drop ratio (5 entries × 30% ≈ 1.5 → fixture ships 2 drops to demonstrate).

## Constraints

- **Bash 3.2 + AP-009 / AD-19 shape**. Every new shell function uses sequential statements, no compound chains > 2, no `$(...|...)`, no plain subshells.
- **Awk is the heavy lift**. The `_bc_filter_knowledge_by_status` function delegates entry-boundary detection to a single awk script — gawk's associative arrays and `RS`/`FS` machinery are AP-009-safe (awk runs in its own process; the bash `awk '...' file > out` invocation is a single command).
- **Additive emitter (CON-5)**. The `payload_breakdown` extension adds a single new top-level field (`filter_dropped_tokens`); pre-M018 records remain valid JSON. The `payload_filter` record is a brand-new `record_type`; existing rollups that key by `record_type` ignore it cleanly.
- **Bail-safe**. Filter failure (config missing, awk error) MUST pass through unmodified knowledge stream and emit no `payload_filter` record. Constitution Principle XI compliance.
- **Originals authoritative (FR-17 / Constitution VI)**. The filter operates on a stream piped from `resolve-entries.sh` output; it never modifies on-disk knowledge files.
- **Multi-runtime parity (FR-13)**. The filter is bash-only; no LLM call; output is byte-identical across CC / Codex CLI / Cursor (M009 launch gate).
- **AGENTS.md dual-write convention**. T02 does NOT edit CLAUDE.md or AGENTS.md. T04 handles the dual-write recent-changes refresh.
- **Dogfood inflection**. Once T02 lands, every M018 dispatch from P03 onward filters knowledge entries. The integration MUST not break self-application: existing M018 phase plans + summaries reference MEM IDs that may or may not carry `status:` fields. Missing-field defaults to RETAINED, so no in-flight phase loses knowledge.

## Expected Output

- `scripts/dispatch/build-context.sh` modified — adds `_bc_read_drop_list`, `_bc_filter_knowledge_by_status`, `_bc_emit_payload_filter`, sourced preservation library, extended `_bc_emit_payload_breakdown`. Estimated +180–250 lines.
- `.orchestrator/config.yml` modified — adds `compression:` block.
- `templates/config-defaults.yml` modified — same block mirrored.
- `tests/fixtures/m018-p02-knowledge-status/` created — fixture milestone with 5 mixed-status MEM entries.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` created — golden capture under `compression.enabled: false`.
- Smoke tests pass: filter drops 2/5 entries in the default config; disable flag produces byte-identical golden; missing-status entry is retained.
