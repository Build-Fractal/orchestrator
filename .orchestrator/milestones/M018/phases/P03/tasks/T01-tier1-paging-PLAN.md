---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M018"
name: "Tier 1 paging + cache lookup/reuse in build-context.sh + additive tier1_* emitter fields + config keys"
depends_on: []
---

## Prerequisites

- P02 has shipped:
  - `scripts/lib/preservation-check.sh` — sourceable library exporting `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check`, `PRES_PATTERNS_REGEX`, `PRES_PATTERN_NAMES`. T01 sources this library and uses `pres_check_section` and `pres_emit_violation` only (density-pre-check is for Tier 3).
    - `pres_check_section <section_name> <body_file>` → exit 0 if every preserved-pattern regex from the cross-tier vocabulary matches byte-identical to a paired `<body_file>.pre` capture; exit 1 if any pattern fails.
    - `pres_emit_violation <tier> <section> <pattern> <log_file>` → appends a `{"record_type":"tier_preservation_violation","tier":"<tier>","section":"<section>","pattern":"<pattern>","timestamp":"..."}` line.
  - `scripts/lib/knowledge-filter.sh` — pure library (T01 does NOT need it; only listed here so the planner does not duplicate its config-reader pattern).
  - `_bc_apply_knowledge_filter` integration in `scripts/dispatch/build-context.sh` lines 490 + 508 (planning + flat knowledge-gather paths).
  - `_bc_emit_payload_breakdown` in `scripts/dispatch/build-context.sh` line ~1101 — the JSONL emitter that T01 extends with two additive fields.
  - `_bc_emit_compression_underperformance` in `scripts/dispatch/build-context.sh` line ~1356 — operational signal, untouched by T01.
- `compression:` block in `.orchestrator/config.yml` lines 42–62 already carries `compression.enabled`, `compression.knowledge_filter.*`, and `compression.underperformance.*`. T01 appends a new `compression.tier1.*` sub-block under the existing `compression:` map; preserve every existing key byte-identical.
- `references/compression-grammar.md` `## Tier: tier1` (lines 167–187) is the contract:
  - applies-to: `tool-result-block`, `tool-call-record` deduplicated by SHA-256(command+input).
  - preserves: cross-tier vocabulary patterns, the `<tool-result file="..." preview-lines="...">` wrapper attributes, the first occurrence of every deduplicated tool-call's full record.
  - failure semantics: self-check on output via cross-tier regex set; on failure, pass through unmodified + emit `tier_preservation_violation`. Cache-key uses full SHA-256.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` is the existing P02 disable-flag golden. T01 must not break it: when `compression.enabled: false`, the entire pipeline (filter + tier1) short-circuits and that golden remains byte-identical.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans: compound chains > 2; plain subshells; `$(... | ...)`; process substitution `<(...)` / `>(...)`. Bash 3.2 — no `declare -A`. T01 follows MEM004's dispatch-internal carve-out (the build-context.sh `_bc_emit_*` functions already use awk/pipes; the carve-out applies to dispatch-internal helpers, NOT to verifier scripts and NOT to agent-facing payload bytes).

## Description

Land Tier 1 microcompact inside `scripts/dispatch/build-context.sh`. After T01:

1. The build-context.sh assembled payload — captured to `$PAYLOAD_CAPTURE` BEFORE `_bc_emit_payload_breakdown` runs — passes through a Tier 1 paging stage that detects inline tool-result blocks above the configured size threshold, replaces them with a `<tool-result file="..." preview-lines="...">` reference, and persists the original body to `.orchestrator/cache/tool-results/<sha256>`.
2. The cache key is the full SHA-256 hex digest of the concatenation `command + "\x1F" + input`, computed from the `command="..."` and `input` body of every tool-result block. (`\x1F` is the ASCII unit-separator byte; it is illegal inside the captured command string and inside the body, so concatenation is unambiguous.)
3. When the same tool-result block reappears in a later dispatch (same SHA-256 hash), the existing cache entry is reused — the file is NOT rewritten (its mtime is preserved so cache-prune.sh ages it correctly).
4. After paging, `pres_check_section` runs over the modified section body. A failure triggers passthrough (the section reverts to the unpaged body; nothing is cached) plus a `tier_preservation_violation` JSONL record emit via `pres_emit_violation`.
5. `_bc_emit_payload_breakdown` is extended with two additive integer fields: `tier1_savings_tokens` (sum of tokens omitted by paging across all blocks in this dispatch) and `tier1_invocations` (count of tool-result blocks paged in this dispatch — both reused and freshly cached count). Pre-T01 records remain valid JSON; rollups read missing fields as 0.
6. `compression.tier1.*` config keys land in `.orchestrator/config.yml`:
   - `compression.tier1.enabled` (default `true`)
   - `compression.tier1.inline_threshold_tokens` (default `1500`)
   - `compression.tier1.preview_lines` (default `5`)
   - `compression.tier1.cache_dir` (default `.orchestrator/cache/tool-results/`)
7. Disable semantics:
   - `compression.enabled: false` → entire pipeline short-circuits (P02 contract preserved).
   - `compression.tier1.enabled: false` → only Tier 1 short-circuits; the knowledge filter still runs.

T01 does NOT ship `cache-prune.sh` (T02), the verifiers (T03), the fixture (T03), or the P03-SUMMARY.

### Tool-result block grammar (canonical input shape T01 detects)

build-context.sh-assembled payloads embed prior tool-call results inside `## Upstream Context` (and occasionally inside the rendered Task Plan body). The canonical block shape T01 paginates is:

```
<tool-result command="<verbatim-command-string>">
<tool-result-input>
<verbatim input bytes — possibly multi-line, possibly empty>
</tool-result-input>
<tool-result-body>
<verbatim body bytes — possibly multi-line, this is what gets paged>
</tool-result-body>
</tool-result>
```

The opening `<tool-result command="..."` tag MUST appear at column 0. The closing `</tool-result>` MUST appear at column 0. Nested `<tool-result>` blocks are NOT supported in this milestone (NG-7 implicitly — output compression is out of scope).

After paging, the block becomes:

```
<tool-result file=".orchestrator/cache/tool-results/<sha256>" preview-lines="5" command="<verbatim-command-string>" original-body-tokens="<N>">
<verbatim first 5 lines of the body>
</tool-result>
```

The `<tool-result-input>` tag and its body are dropped from the payload (the input is folded into the cache key; the receiving agent does not need it inline). `original-body-tokens` is the pre-paging token count of the body (computed via the existing `chars_to_tokens_quartile` from `scripts/lib/pricing.sh`).

If the body is ≤ `compression.tier1.inline_threshold_tokens`, the block is passed through verbatim — no paging, no cache write.

### Cache file shape

`.orchestrator/cache/tool-results/<sha256>` — plain text, no envelope. Contents are the verbatim body bytes only. The first occurrence in any dispatch writes the file; subsequent occurrences with the same SHA-256 short-circuit the write (existence check + skip; mtime preserved). The SHA-256 is the lowercase hex digest from `shasum -a 256` (POSIX-ubiquitous on macOS + Linux).

## Steps

### Step 1 — Append `compression.tier1.*` to `.orchestrator/config.yml`

Use `Edit` to append after the existing `compression.underperformance:` block. The current block ends at line 62 (`min_sample_size: 10`). Insert below it (still nested under `compression:`):

```yaml
  # M018/P03 — Tier 1 microcompact (tool-result paging + cache reuse).
  # When a tool-result block's body exceeds `inline_threshold_tokens`, the
  # body is replaced inline with a `<tool-result file="..." preview-lines="...">`
  # reference and the original is persisted to `cache_dir/<sha256>`. Cache
  # lookups key on SHA-256(command + 0x1F + input) so identical tool calls
  # across dispatches reuse the same file. `preview_lines` is the number of
  # leading body lines retained in-band so the receiving agent has a
  # zero-fetch summary.
  tier1:
    enabled: true
    inline_threshold_tokens: 1500
    preview_lines: 5
    cache_dir: .orchestrator/cache/tool-results/
```

Indentation: two-space, matching the existing `knowledge_filter:` and `underperformance:` siblings.

### Step 2 — Add config readers to `build-context.sh`

In `scripts/dispatch/build-context.sh`, locate the existing block (line ~181):

```bash
KNOWLEDGE_FILTER_ENABLED="$(kf_get_knowledge_filter_enabled "$PROJECT_ROOT")"
```

Add immediately below it:

```bash
# M018/P03/T01: Tier 1 microcompact config.
TIER1_ENABLED="$(config_read 'compression.tier1.enabled' true)"
TIER1_INLINE_THRESHOLD_TOKENS="$(config_read 'compression.tier1.inline_threshold_tokens' 1500)"
TIER1_PREVIEW_LINES="$(config_read 'compression.tier1.preview_lines' 5)"
TIER1_CACHE_DIR="$(config_read 'compression.tier1.cache_dir' '.orchestrator/cache/tool-results/')"
# Resolve cache_dir relative to PROJECT_ROOT when it starts with '.orchestrator/'.
case "$TIER1_CACHE_DIR" in
  /*) : ;;  # absolute, leave alone
  *)  TIER1_CACHE_DIR="$PROJECT_ROOT/$TIER1_CACHE_DIR" ;;
esac
```

(Use `config_read` exactly as the surrounding code does. The dotted-key form is supported; the P02 task plan T02 confirmed this.)

### Step 3 — Source the preservation library defensively

Find the existing `preservation-check.sh` source line in `build-context.sh` (P02 added it; grep `preservation-check`). If it is absent (it should be present per P02), add near the top of the script (after the `kf_*` source line):

```bash
# M018/P02/T01: preservation-contract self-check library, sourced for
# Tier 1 / Tier 2 / Tier 3 callers.
if [ -r "$PROJECT_ROOT/scripts/lib/preservation-check.sh" ]; then
  . "$PROJECT_ROOT/scripts/lib/preservation-check.sh"
fi
```

### Step 4 — Author the Tier 1 paging function `_bc_apply_tier1`

Place this function adjacent to `_bc_apply_knowledge_filter` (around line 518). The function reads the captured-payload file path on argument 1 and rewrites the file in place (writing through a temp file + `mv` for atomicity). It returns 0 on success and on no-op short-circuit; it returns 0 (passthrough) on internal errors and emits a one-line stderr warning per the cache-missing-or-unwritable spec scenario (US-3 acceptance #4).

```bash
# M018/P03/T01: Tier 1 microcompact — tool-result paging + cache reuse.
#
# Argument 1: path to the captured payload file (already assembled, prior
# to _bc_emit_payload_breakdown). The function rewrites the file in place
# when paging fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes paged tool-result bodies to $TIER1_CACHE_DIR/<sha256> (one
#     file per unique command+input, full-fidelity body).
#   - Writes a stats line to $TMPDIR_BUILD/_tier1_stats.txt of the form:
#       savings_tokens=<N> invocations=<N>
#     The caller (_bc_emit_payload_breakdown) reads this file to populate
#     the additive `tier1_savings_tokens` + `tier1_invocations` fields.
#
# Short-circuits (passthrough; stats file not written; no cache writes):
#   - $COMPRESSION_ENABLED != "true"
#   - $TIER1_ENABLED != "true"
#   - The capture file contains zero `^<tool-result command=` opens.
#   - mkdir -p $TIER1_CACHE_DIR fails (one-line stderr warning emitted).
#
# Preservation self-check:
#   - After paging completes, runs pres_check_section "tier1" against the
#     post-paging file. On failure, restores the pre-paging file and emits
#     `tier_preservation_violation` via pres_emit_violation. Cache files
#     written during the failed pass are kept (they may be reused on
#     future passes; cache-prune handles eventual eviction).
#
# AP-009 compliance: no compound chains > 2; no plain subshells; no
# $(...|...). Awk does the heavy lifting in a single invocation.
_bc_apply_tier1() {
  local capture_file="$1"
  if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$TIER1_ENABLED" != "true" ]; then
    return 0
  fi
  # Quick gate: any tool-result blocks at all?
  local _tr_count
  _tr_count="$(grep -c '^<tool-result command=' "$capture_file" 2>/dev/null || true)"
  if [ -z "$_tr_count" ] || [ "$_tr_count" = "0" ]; then
    return 0
  fi

  if ! mkdir -p "$TIER1_CACHE_DIR" 2>/dev/null; then
    printf 'build-context.sh: tier1 disabled — cache_dir unwritable: %s\n' "$TIER1_CACHE_DIR" >&2
    return 0
  fi

  local pre_file out_file stats_file
  pre_file="$TMPDIR_BUILD/_tier1_pre.txt"
  out_file="$TMPDIR_BUILD/_tier1_out.txt"
  stats_file="$TMPDIR_BUILD/_tier1_stats.txt"
  cp "$capture_file" "$pre_file"

  # Single awk pass: scan the file, accumulate command + input + body for
  # every <tool-result ...>...</tool-result> block, hand each to a
  # subordinate bash helper that hashes + writes the cache, and emit the
  # transformed payload to $out_file. Running totals to $stats_file.
  #
  # Inputs threaded as awk variables:
  #   th         — inline_threshold_tokens
  #   pl         — preview_lines
  #   cdir       — TIER1_CACHE_DIR
  #   stf        — stats_file
  #
  # Token estimation inside awk: chars/4 quartile approximation (the
  # build-context.sh quartile estimator from scripts/lib/pricing.sh is
  # bash; replicating its branchless integer form in awk keeps us in a
  # single pass). The pricing.sh estimator returns
  # int( (chars + 3) / 4 ); we mirror that exactly.
  awk -v th="$TIER1_INLINE_THRESHOLD_TOKENS" \
      -v pl="$TIER1_PREVIEW_LINES" \
      -v cdir="$TIER1_CACHE_DIR" \
      -v stf="$stats_file" \
      '
      function tok(c) { return int((c + 3) / 4) }
      function sha256(s,   cmd, h) {
        cmd = "printf %s \047" s "\047 | shasum -a 256 | cut -c1-64"
        cmd | getline h
        close(cmd)
        return h
      }
      function flush_block(   cmd_str, in_str, body_str, body_chars, body_tok, key, path, preview, n, lines, i) {
        if (cmd_only) {
          # No body captured (malformed) — pass through verbatim.
          printf "%s", raw
          raw=""; in_block=0; saw_input=0; saw_body=0
          cmd_only=0
          return
        }
        body_chars = length(body_buf)
        body_tok = tok(body_chars)
        if (body_tok <= th + 0) {
          # Below threshold → pass through verbatim.
          printf "%s", raw
          inv_total += 0
          raw=""; in_block=0; saw_input=0; saw_body=0
          body_buf=""; input_buf=""; cmd_str=""
          return
        }
        # Page it.
        cmd_str = saved_cmd
        in_str  = input_buf
        body_str = body_buf
        # SHA-256 over command + 0x1F + input.
        key = sha256(cmd_str "\x1F" in_str)
        path = cdir key
        # Write the cache file iff missing (preserve mtime on reuse).
        if ((getline _t < path) < 0) {
          # Not readable → write.
          out = path
          printf "%s", body_str > out
          close(out)
        } else {
          close(path)
        }
        # Build preview: first pl lines of body.
        n = split(body_str, lines, "\n")
        preview = ""
        for (i = 1; i <= n && i <= pl + 0; i++) {
          preview = preview lines[i] (i < n ? "\n" : "")
        }
        # Emit the paged tag.
        printf "<tool-result file=\"%s\" preview-lines=\"%d\" command=\"%s\" original-body-tokens=\"%d\">\n%s\n</tool-result>\n", \
               path, pl, cmd_str, body_tok, preview
        savings_tok += body_tok - tok(length(preview))
        inv_total += 1
        raw=""; in_block=0; saw_input=0; saw_body=0
        body_buf=""; input_buf=""; saved_cmd=""
      }
      BEGIN { in_block=0; saw_input=0; saw_body=0; raw=""; savings_tok=0; inv_total=0 }
      /^<tool-result command=/ {
        # Extract command="..." attribute. Greedy through last quote on the line.
        line=$0
        match(line, /command="[^"]*"/)
        if (RSTART > 0) {
          attr = substr(line, RSTART+9, RLENGTH-10)
          saved_cmd = attr
        } else {
          saved_cmd = ""
        }
        in_block=1; saw_input=0; saw_body=0
        body_buf=""; input_buf=""
        raw=line "\n"
        next
      }
      in_block && /^<tool-result-input>/ { saw_input=1; raw=raw $0 "\n"; next }
      in_block && /^<\/tool-result-input>/ { saw_input=0; raw=raw $0 "\n"; next }
      in_block && saw_input==1 { input_buf = input_buf $0 "\n"; raw=raw $0 "\n"; next }
      in_block && /^<tool-result-body>/ { saw_body=1; raw=raw $0 "\n"; next }
      in_block && /^<\/tool-result-body>/ { saw_body=0; raw=raw $0 "\n"; next }
      in_block && saw_body==1 { body_buf = body_buf $0 "\n"; raw=raw $0 "\n"; next }
      in_block && /^<\/tool-result>/ { raw=raw $0 "\n"; flush_block(); next }
      in_block { raw=raw $0 "\n"; next }
      { print }
      END {
        printf "savings_tokens=%d invocations=%d\n", savings_tok, inv_total > stf
      }
      ' "$pre_file" > "$out_file"

  # Preservation self-check: pres_check_section over the rewritten body.
  # Argument shape: pres_check_section <section_label> <body_file>.
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier1" "$out_file" >/dev/null 2>&1; then
      pres_emit_violation "tier1" "payload" "cross-tier" "$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl" 2>/dev/null || true
      # Restore pre-paging body; clear stats so emitter writes 0/0.
      cp "$pre_file" "$capture_file"
      printf 'savings_tokens=0 invocations=0\n' > "$stats_file"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"
  return 0
}
```

Notes:
- The awk `sha256()` helper shells out via awk's `cmd | getline` — this is a single pipe inside awk's own command pipeline, NOT a shell `$(...|...)` expression, so AP-009 does not apply (the heuristic targets shell-side shapes; awk's `cmd | getline` is intrinsic to awk).
- The block grammar accepts the `<tool-result-input>` and `<tool-result-body>` sub-tags; if a captured payload contains an old-shape tool-result without the sub-tags (older logs predating M018), the block is treated as `cmd_only` and passed through verbatim — never paged, never cached. That keeps T01 backwards-compatible with any in-flight historical fixture.
- `chars_to_tokens_quartile` returns `(chars+3)/4` rounding up — see `scripts/lib/pricing.sh`. The awk `tok()` function is byte-identical to that.

### Step 5 — Wire `_bc_apply_tier1` into the dispatch path

`build-context.sh` already captures the assembled payload to `$PAYLOAD_CAPTURE` before `_bc_emit_payload_breakdown` (the existing line ~1470 reads `_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true`). Insert the Tier 1 call IMMEDIATELY before that line:

```bash
# M018/P03/T01: Tier 1 microcompact runs against the captured payload
# before the breakdown emitter samples it (so emitter section sizes
# reflect post-tier1 reality).
_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
_bc_emit_compression_underperformance || true
```

### Step 6 — Extend `_bc_emit_payload_breakdown` with `tier1_*` additive fields

In `_bc_emit_payload_breakdown` (line ~1101), find the existing `filter_dropped_tokens` read block (around line 1166 — it reads `$TMPDIR_BUILD/_filter_stats.txt`). Add a sibling block immediately after it:

```bash
  # M018/P03/T01 (CON-5): additive `tier1_savings_tokens` + `tier1_invocations`
  # fields. Reads $TMPDIR_BUILD/_tier1_stats.txt written by _bc_apply_tier1.
  # Defaults to 0 when tier1 was disabled or the file is absent.
  local tier1_savings_tokens=0 tier1_invocations=0
  local _bc_pb_t1_stats="$TMPDIR_BUILD/_tier1_stats.txt"
  if [ -f "$_bc_pb_t1_stats" ]; then
    tier1_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) { sub("savings_tokens=", "", $i); print $i; exit }
      }
    }' "$_bc_pb_t1_stats")"
    tier1_invocations="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^invocations=/) { sub("invocations=", "", $i); print $i; exit }
      }
    }' "$_bc_pb_t1_stats")"
    if [ -z "$tier1_savings_tokens" ]; then tier1_savings_tokens=0; fi
    if [ -z "$tier1_invocations" ];   then tier1_invocations=0; fi
  fi
```

Then update the `printf` template that emits the JSONL line to include the two new fields. Find the line:

```bash
  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"filter_dropped_tokens":%d,"model":"%s","source":"estimate","timestamp":"%s"}\n' \
```

Replace the format string and argument list to insert `"tier1_savings_tokens":%d,"tier1_invocations":%d,` IMMEDIATELY AFTER the `filter_dropped_tokens` field (preserve the existing field order for everything else):

```bash
  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier1_invocations":%d,"model":"%s","source":"estimate","timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$payload_chars" "$payload_tokens" \
    "$section_tokens_json" "$filter_dropped_tokens" \
    "$tier1_savings_tokens" "$tier1_invocations" \
    "$model" "$ts" \
    >> "$log_file" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown append failed on %s\n' "$log_file" >&2
    return 0
  }
```

CON-5 invariants: pre-T01 `payload_breakdown` records remain valid JSON; T01 only ADDS fields. Rollups treat missing fields as 0.

### Step 7 — Self-test: dispatch the build-context.sh against the existing P02 fixture

Run:

```
bash scripts/dispatch/build-context.sh M018 P03 T01-self-test
```

against the current state with `compression.enabled: true`. The execution-log.jsonl should now show a `payload_breakdown` record with `tier1_savings_tokens` and `tier1_invocations` fields present (both 0 if no tool-result blocks are in the assembled payload — that's fine; T03's verifier exercises a fixture with real blocks).

Run:

```
ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh M018 P03 T01-self-test
```

The captured payload bytes must remain byte-identical to the pre-T01 path under disable. (T03 wires the golden-payload regression verifier; T01's self-check is an interactive sanity check.)

## Must-Haves

- Tier 1 paging replaces oversized inline tool-result blocks with a `<tool-result file="..." preview-lines="...">` reference and persists the original to `.orchestrator/cache/tool-results/<sha256>` (T03 verifier `m018-p03-tier1-paging.sh`).
- Cache reuse: identical command+input across dispatches reuses the same SHA-256-keyed cache entry without rewriting the file (T03 verifier `m018-p03-cache-reuse.sh`).
- `payload_breakdown` records carry additive `tier1_savings_tokens` + `tier1_invocations` integer fields; pre-T01 records remain valid JSON (T03 verifier `m018-p03-emitter-additivity.sh`).
- `compression.enabled: false` short-circuits the entire pipeline; `compression.tier1.enabled: false` short-circuits only Tier 1 (T03 verifier `m018-p03-disable-flag-honored.sh`).
- Body-level preservation self-check via `pres_check_section`; failure passes the section through unmodified plus a `tier_preservation_violation` JSONL emit (T03 verifier `m018-p03-preservation-self-check.sh`).

## Verification

- `bash scripts/verify/m018-p03-tier1-paging.sh` — PASS (exits 0; T01 lands the production code that this verifier exercises).
- `bash scripts/verify/m018-p03-cache-reuse.sh` — PASS.
- `bash scripts/verify/m018-p03-emitter-additivity.sh` — PASS.
- `bash scripts/verify/m018-p03-disable-flag-honored.sh` — PASS.
- `bash scripts/verify/m018-p03-preservation-self-check.sh` — PASS.

T03 ships these verifiers; they exercise T01's production code. Until T03 lands, T01 is verifiable via the self-test in Step 7 plus a `bash -n scripts/dispatch/build-context.sh` syntax check.

## Inputs

### From Previous Tasks

(None within P03 — T01 is the first task.)

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the dispatch payload assembler. Key insertion points: line ~181 (config reads), line ~518 (apply-knowledge-filter sibling), line ~1101 (`_bc_emit_payload_breakdown`), line ~1166 (`filter_dropped_tokens` read), line ~1470 (call site).
- `scripts/lib/preservation-check.sh` — sourceable; functions `pres_check_section` and `pres_emit_violation` used by Step 4.
- `scripts/lib/pricing.sh` — sourceable; `chars_to_tokens_quartile` defines the `(chars+3)/4` token estimator T01 mirrors in awk.
- `.orchestrator/config.yml` — Step 1 appends to the `compression:` map (lines 42–62 currently).
- `references/compression-grammar.md` `## Tier: tier1` (lines 167–187) — contract.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — P02 disable-flag golden; T01 must NOT change its bytes when `compression.enabled: false`.

## Constraints

- **AP-009 (Bash shape guard)**: zero compound chains > 2; zero plain subshells; zero `$(...|...)` shell forms. Awk `cmd | getline` is permitted (it's awk-internal, not shell-shape).
- **Bash 3.2 compatibility**: no `declare -A`; no associative arrays; parallel indexed arrays only.
- **CON-5 (additive emitters)**: `payload_breakdown` records gain TWO new fields; no existing field is removed or renamed; pre-T01 records remain valid JSON.
- **Constitution Principle VI (originals authoritative)**: T01 writes ONLY to `.orchestrator/cache/tool-results/<sha256>` (disposable), `$TMPDIR_BUILD/*` (transient), `execution-log.jsonl` (additive emit), and the in-flight `$PAYLOAD_CAPTURE`. No canonical file (knowledge tree, spec, plan, roadmap) is touched.
- **Disable contract**: when `compression.enabled: false`, T01 MUST short-circuit before any cache write or any payload mutation. The P02 golden payload (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) is the regression contract — T03's `m018-p03-disable-flag-honored.sh` verifier asserts byte-identity.
- **MEM004 (Pure Lib Extraction)**: T01's `_bc_apply_tier1` is dispatch-internal, like the existing `_bc_apply_knowledge_filter` and `_bc_emit_payload_breakdown`. It does not need to live in a separate `scripts/lib/tier1.sh`. (P02 chose to extract `kf_*` to a sourceable lib because the filter has TWO call sites — planning + section-handlers; Tier 1 has ONE call site, so inline is fine. If P04/P06 demand cross-call-site reuse, the function migrates to `scripts/lib/tier1.sh` then.)

## Expected Output

- `scripts/dispatch/build-context.sh` grew by ~150 lines (the `_bc_apply_tier1` function plus the config reads plus the emitter additions).
- `.orchestrator/config.yml` carries the new `compression.tier1.*` block under the existing `compression:` map.
- `bash -n scripts/dispatch/build-context.sh` succeeds (syntax check).
- A self-test invocation of build-context.sh produces a `payload_breakdown` JSONL line whose JSON parses cleanly (`python3 -c 'import json,sys;[json.loads(l) for l in open(sys.argv[1])]' execution-log.jsonl`) and contains both `tier1_savings_tokens` and `tier1_invocations` keys with integer values.
- No verifier files yet — T03 ships those.
