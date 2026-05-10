---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M018"
name: "Tier 3 auto-compact helper in build-context.sh + templates/compression-tier3-prompt.md + intensity-gate wiring + failure-passthrough + originals persistence + MIT-08 density pre-check + kf_get_tier3_* config accessors"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/build-context.sh` already ships `_bc_apply_tier1` (P03/T01) and `_bc_apply_tier2` (P04/T01). The pipeline wiring at the bottom of the file invokes them in sequence:

  ```bash
  _bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
  _bc_apply_tier2 "$PAYLOAD_CAPTURE" || true
  _bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
  ```

  T01 inserts a `_bc_apply_tier3 "$PAYLOAD_CAPTURE" || true` call between `_bc_apply_tier2` and `_bc_emit_payload_breakdown`. The tier3 helper has the same trailing `|| true` so a failure inside the helper never aborts the dispatch (FR-9 failure-passthrough).
- The Tier 1 helper's stats-file pattern is the canonical contract T01 mirrors. Stats live at `$TMPDIR_BUILD/_tier3_stats.txt` with the form `savings_tokens=<N> invocations=<M>`. The emitter (T02 widens this) reads the file via the same awk one-pass that already extracts tier1 / tier2 fields. T01 ships ONLY the helper + the stats-file write side; T02 widens the emitter to read the file and stamp the JSONL fields.
- The Tier 2 helper's `_tier2_stats.txt` shape is the second reference. Tier 3 follows the same shape (single line, `savings_tokens=` + `invocations=` keys, defaults to `savings_tokens=0 invocations=0`).
- `scripts/lib/knowledge-filter.sh` ships `kf_get_compression_enabled`, `kf_get_tier1_*`, `kf_get_tier2_*` accessors (P02/P03/P04 pattern). T01 extends this file with the new tier3 accessors:

  - `kf_get_tier3_enabled <project_root>` → `'true'|'false'` (default `true`).
  - `kf_get_tier3_intensity_floor <project_root>` → `'quick'|'standard'|'full'` (default `standard`; closed enum, anything else falls through to `standard`).
  - `kf_get_tier3_section_budget_tokens <project_root>` → integer (default `2500` — Tier 3 budget defaults higher than Tier 2's 1500 because T3 pays an LLM call to fit; the operator can tighten via config).
  - `kf_get_tier3_originals_dir <project_root>` → string (default `.orchestrator/cache/tier3-originals/`).
  - `kf_get_tier3_output_max_ratio <project_root>` → real (default `0.80` — discard summaries that exceed 80% of input bytes).
  - `kf_get_tier3_density_floor <project_root>` → real (default `1.5` — skip T3 when `input_tokens / section_budget` < density_floor).

  Each accessor reuses `kf_resolve_config_path` and `kf_read_compression_scalar` exactly as the existing tier2 accessors do (lines 465-491 of `scripts/lib/knowledge-filter.sh`). Bash 3.2 — no associative arrays.

- `scripts/dispatch/dispatch-interface.sh` is the canonical runtime-portable dispatch surface. Tier 3 invokes it via:

  ```bash
  bash "$PROJECT_ROOT/scripts/dispatch/dispatch-interface.sh" \
    --backend "${ORCH_BACKEND:-claude-code}" \
    --prompt-file "$rendered_prompt_file" \
    --capture-output "$summary_out_file" \
    --max-output-tokens "$summary_budget" \
    --timeout-seconds 60
  ```

  The exact CLI surface depends on `dispatch-interface.sh`'s `--help` output at integration time; T01 reads the help and adapts. The contract is: `dispatch-interface.sh` exits 0 on success with the summary text written to `$summary_out_file`; non-zero exit is the failure-passthrough trigger.

  IMPORTANT: if at integration time the `dispatch-interface.sh` CLI does not yet expose a `--prompt-file` / `--capture-output` flag pair, T01 ships a minimal shim wrapper at `scripts/dispatch/lib/tier3-llm-call.sh` whose body is the dispatch invocation. The shim isolates the runtime-portability surface so the multi-runtime parity work (P07) can swap providers without touching `_bc_apply_tier3`. The shim's contract: `bash tier3-llm-call.sh --prompt-file <p> --capture-output <o> --max-output-tokens <N> --timeout-seconds <S>`; exit 0 = success, anything else = failure-passthrough.

- `scripts/engine/intensity-gate.sh` is the canonical intensity resolver. T01 calls:

  ```bash
  resolved_intensity="$(grep -E '^intensity:' "$INTENSITY_METADATA_FILE" 2>/dev/null \
    | head -1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
  ```

  matching the same parser the gate itself uses (lines 50 of `scripts/engine/intensity-gate.sh`). Default when metadata absent: `Standard` (so a fresh dispatch with no metadata defaults to T3-on; the operator opts out via config, not via metadata absence).

- `scripts/lib/preservation-check.sh` ships `pres_check_section <tier> <pre-file> <post-file> <tier-name>` and `pres_emit_violation <tier> <section> <pattern> <log-file>` (M018/P02). T01 calls `pres_check_section "tier3" "$pre_file" "$out_file" tier3` after summarization; on failure, the helper restores `$pre_file` byte-identical and emits a `tier_preservation_violation` JSONL record with `tier=tier3`.

- `references/compression-grammar.md` (P01) carries the Tier 3 rules. T01 reads it once at integration time to confirm the preserved-pattern list T3 must respect (frontmatter `^---$` pairs, ` ``` ` code-fences, paths, MEM IDs, command names, URLs, JSONL records, scaffold-placeholder markers). The summarization prompt template (Step 2 below) names these patterns verbatim so the LLM is instructed to preserve them; the post-call preservation self-check verifies the LLM honored the contract.

- `.orchestrator/cache/tier3-originals/` is created lazily on first T3 fire via `mkdir -p`. The directory lives beside `.orchestrator/cache/tool-results/` (P03's tier1 cache); `cache-prune.sh` (P03) does NOT recurse into sub-directories under cache_dir, so tier3-originals/ co-tenants are untouched by tier1 prune.

- AD-19 / AP-009: every Check at task-plan level is a single-script-file invocation. T01's task-local self-check is `bash -n scripts/dispatch/build-context.sh` — this catches syntax errors in the modified file without depending on T04's verifiers. The canonical verifiers `m018-p06-tier3-helper-shape.sh` and `m018-p06-tier3-prompt-template.sh` ship in T04.

- Bash 3.2 (MEM001): no `declare -A`; awk inside the helper body is permitted by the MEM004 emitter-internal carve-out.

## Description

T01 ships:

1. `templates/compression-tier3-prompt.md` (new) — the summarization prompt template.
2. `kf_get_tier3_*` accessors in `scripts/lib/knowledge-filter.sh` (six new accessors mirroring the tier2 shape).
3. `_bc_apply_tier3 <capture_file>` helper in `scripts/dispatch/build-context.sh` (between `_bc_apply_tier2` and `_bc_emit_payload_breakdown`), with:
   - intensity-gate short-circuit (Quick → skip + emit `tier3_skipped`),
   - master compression toggle short-circuit (`COMPRESSION_ENABLED=false` → passthrough),
   - per-tier toggle short-circuit (`TIER3_ENABLED=false` → passthrough),
   - section-walker that finds the largest oversized `^## ` section after Tier 1 + Tier 2,
   - MIT-08 density pre-check (`input_tokens / section_budget < density_floor` → skip without paying LLM cost),
   - originals persistence (`.orchestrator/cache/tier3-originals/<sha256>.txt`),
   - LLM call via `dispatch-interface.sh` (or the `tier3-llm-call.sh` shim; whichever the runtime exposes),
   - output-size guard (`output / input > output_max_ratio` → discard, passthrough, emit `tier3_no_savings`),
   - in-band marker emit (`<!-- compressed:tier3 model=<m> input_tokens=<n> output_tokens=<o> -->`),
   - preservation self-check + restore-on-violation,
   - failure-passthrough on every error path (LLM call failed, dispatch-interface non-zero, prompt render failed, etc.) → write `savings_tokens=0 invocations=0` to stats file, emit `tier3_failed` JSONL, return 0.
4. Pipeline wiring: insert `_bc_apply_tier3 "$PAYLOAD_CAPTURE" || true` between the existing tier2 and emitter calls.
5. Config-stanza extension to the orchestrator config default at `templates/orchestrator-config-default.yml` — add a `compression.tier3` block with the documented defaults so `orchestrator:init` copies it forward.

T01 does NOT ship:

- The two additive JSONL fields on `payload_breakdown` / `dispatch_usage` / `unit_close` (T02 — schema extensions).
- `compression-eval.sh --tier 3` real cohort logic (T03).
- Verifiers, fixtures, fixture-staging helper, P06-SUMMARY, CLAUDE.md/AGENTS.md dual-write (T04).

## Inputs

Surface contracts T01 reads from upstream files:

- `scripts/dispatch/build-context.sh:_bc_apply_tier1` (lines ~596-767) — canonical helper shape: stats-file write, in-place rewrite via temp file + `mv`, atomic replace, preservation self-check + restore-on-violation, MEM004 carve-out comments, single-pass awk for the transformation, defensive `|| true` on every shell-out.

- `scripts/dispatch/build-context.sh:_bc_apply_tier2` (lines ~805-1027) — second reference for helper shape: same passthrough discipline, in-band marker emit, frontmatter / code-fence boundary refusal pattern, `tier_preservation_violation` emit on cross-tier preservation failure.

- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` (lines ~1593-1754) — emitter shape T02 widens. T01 only writes the stats file `$TMPDIR_BUILD/_tier3_stats.txt` (`savings_tokens=<N> invocations=<M>` line). T02 reads it.

- `scripts/lib/knowledge-filter.sh:kf_get_tier2_enabled` / `kf_get_tier2_section_budget_tokens` / `kf_get_tier2_protected_tail_ratio` (lines ~465-491) — accessor shape T01 mirrors for the six tier3 accessors.

- `scripts/dispatch/dispatch-interface.sh` `--help` — read at integration time to confirm the prompt-file / capture-output flag pair. If the flags are absent, ship the `tier3-llm-call.sh` shim per Step 4 below.

- `references/compression-grammar.md` Tier 3 section — read once to enumerate the preserved-pattern list the prompt template names verbatim.

- `templates/compression-tier3-prompt.md` shape: see Step 2.

## Steps

### Step 1 — Add `kf_get_tier3_*` accessors to `scripts/lib/knowledge-filter.sh`

Append after the existing tier2 accessors (file lines ~491) the following block:

```bash
# ---------------------------------------------------------------------------
# kf_get_tier3_<key> <project_root>  ->  scalar
# M018/P06/T01: Tier 3 auto-compact config accessors. Each returns the scalar
# value from compression.tier3.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_tier3_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_tier3_intensity_floor() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.intensity_floor)"
  case "$val" in
    quick|standard|full) printf '%s\n' "$val" ;;
    *) printf 'standard\n' ;;
  esac
}

kf_get_tier3_section_budget_tokens() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.section_budget_tokens)"
  if [ -z "$val" ]; then
    printf '2500\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier3_originals_dir() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.originals_dir)"
  if [ -z "$val" ]; then
    printf '.orchestrator/cache/tier3-originals/\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier3_output_max_ratio() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.output_max_ratio)"
  if [ -z "$val" ]; then
    printf '0.80\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier3_density_floor() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier3.density_floor)"
  if [ -z "$val" ]; then
    printf '1.5\n'
  else
    printf '%s\n' "$val"
  fi
}
```

Update the file's top-of-file comment-listing of public accessors (around lines 18-26) to include the six new tier3 accessors.

### Step 2 — Author `templates/compression-tier3-prompt.md`

```markdown
---
schema_version: "1.0"
type: compression-prompt
tier: 3
applies_to: ["dispatch-payload-section"]
preserves: [
  "frontmatter '---' fences",
  "code fences (3+ backticks)",
  "JSONL records (lines starting with '{')",
  "MEM identifiers (MEM\\d+)",
  "absolute and project-relative paths",
  "scaffold-placeholder markers ({{ ... }})",
  "URLs",
  "command names like orchestrator:auto / speckit.* / gsd:*",
  "in-band compression markers (<!-- compressed:tierN ... -->)"
]
---

# Tier 3 Compression Prompt — M018/P06

You are summarizing one section of a dispatch payload to fit a token budget while preserving load-bearing content.

## Input contract

The input is a single dispatch-payload section beginning with a markdown header line (`## <Section>`) and continuing through its body. The section may exceed the configured budget after Tier 1 microcompact + Tier 2 head-drop have already run.

## Output contract

Produce a summary that:

1. **Begins** with the original `## <Section>` header line, byte-identical.
2. **Immediately follows** the header with this in-band marker on its own line:
   ```
   <!-- compressed:tier3 model=<MODEL> input_tokens=<N> output_tokens=<M> -->
   ```
   The orchestrator post-processes the marker; emit it with placeholder values `<MODEL>`, `<N>`, `<M>` and the orchestrator will substitute them.
3. **Preserves verbatim** every byte that matches the patterns listed in this template's frontmatter `preserves:` array. Specifically:
   - Frontmatter `---` fence pairs and the lines between them.
   - Code fences (3 or more backticks) and the code lines between them.
   - JSONL records (lines starting with `{` and ending with `}`).
   - MEM identifiers (e.g., `MEM001`, `MEM031`).
   - Absolute and project-relative paths (e.g., `scripts/dispatch/build-context.sh`).
   - Scaffold-placeholder markers (e.g., `{{milestone_id}}`).
   - URLs (e.g., `https://example.com/path`).
   - Command names (e.g., `orchestrator:auto`, `speckit.orchestrator.dispatch`).
   - In-band compression markers from earlier tiers.
4. **Compresses prose** between preserved patterns: paraphrase verbose narrative into terse bullet form; collapse redundant sentences; cite section / decision / MEM IDs rather than restating their content.
5. **Stays under** the output token budget named in the orchestrator's invocation. The orchestrator discards summaries that exceed `output_max_ratio` (default 0.80) of input bytes.

## Failure modes

If you cannot produce a summary that honors all four output-contract clauses (e.g., the input is mostly preserved patterns with no compressible prose), **return the input unchanged** with the original `## <Section>` header but no `<!-- compressed:tier3 ... -->` marker. The orchestrator detects the absent marker and treats the call as no-savings (passthrough).

## Section to compress

Replace this block with the input section. The orchestrator renders the prompt by appending the section bytes after this header.
```

The orchestrator renders the template by appending the section bytes after the final header. Token-budget instructions are passed via the dispatch-interface invocation (max-output-tokens), not the template body.

### Step 3 — Author `_bc_apply_tier3` helper in `scripts/dispatch/build-context.sh`

Insert immediately after `_bc_apply_tier2` (around line 1027) and before `_bc_emit_payload_breakdown`:

```bash
# M018/P06/T01: Tier 3 auto-compact — LLM-routed section summarization.
#
# Argument 1: path to the captured payload file (already through Tier 1 + Tier 2,
# prior to _bc_emit_payload_breakdown). The function rewrites the file in place
# when summarization fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes a stats line to $TMPDIR_BUILD/_tier3_stats.txt of the form:
#       savings_tokens=<N> invocations=<M>
#     The caller (T02-widened _bc_emit_payload_breakdown) reads this file
#     to populate the additive `tier3_compression_savings_tokens` and
#     `tier3_invocations` fields.
#   - Persists the original (post-Tier 2) section to
#     $TIER3_ORIGINALS_DIR/<sha256>.txt for audit + eval-harness replay.
#
# Short-circuits (passthrough; stats file written with savings_tokens=0
# invocations=0):
#   - $COMPRESSION_ENABLED != "true"
#   - $TIER3_ENABLED != "true"
#   - Resolved intensity is below $TIER3_INTENSITY_FLOOR (FR-14: Quick skips T3).
#   - The capture file contains zero in-scope `^## ` sections exceeding
#     $TIER3_SECTION_BUDGET_TOKENS.
#   - MIT-08 density pre-check fails (input_tokens / section_budget <
#     $TIER3_DENSITY_FLOOR — too sparse to compress meaningfully).
#
# Failure-passthrough (FR-9; emits tier3_failed JSONL record + zero stats):
#   - dispatch-interface.sh non-zero exit (timeout, rate limit, error).
#   - Output bytes empty or smaller than the in-band marker length.
#   - Output / input ratio > $TIER3_OUTPUT_MAX_RATIO (emits tier3_no_savings).
#   - pres_check_section "tier3" returns non-zero (preservation breach).
#
# MEM004 carve-out: dispatch-internal helper, like _bc_apply_tier1 / _bc_apply_tier2.
_bc_apply_tier3() {
  local capture_file="$1"
  local stats_file="$TMPDIR_BUILD/_tier3_stats.txt"

  # Always write a zero-stats line first so the emitter never reads a missing
  # file (defensive: even early-return paths leave stats in a known shape).
  printf 'savings_tokens=0 invocations=0\n' > "$stats_file"

  # Master toggle short-circuit.
  if [ "${COMPRESSION_ENABLED:-true}" != "true" ]; then
    return 0
  fi
  # Per-tier toggle short-circuit.
  if [ "${TIER3_ENABLED:-true}" != "true" ]; then
    return 0
  fi
  if [ ! -f "$capture_file" ]; then
    return 0
  fi

  # Intensity gate (FR-14). TIER3_INTENSITY_FLOOR resolved at top-of-file.
  # Resolved intensity comes from the engine's metadata file when present;
  # default to Standard so a fresh dispatch with no metadata enables T3.
  local resolved_intensity="Standard"
  if [ -n "${INTENSITY_METADATA_FILE:-}" ] && [ -f "$INTENSITY_METADATA_FILE" ]; then
    resolved_intensity="$(grep -E '^intensity:' "$INTENSITY_METADATA_FILE" 2>/dev/null \
      | head -1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
    if [ -z "$resolved_intensity" ]; then resolved_intensity="Standard"; fi
  fi
  case "$TIER3_INTENSITY_FLOOR" in
    quick) ;;  # Floor=quick means T3 always runs.
    standard)
      case "$resolved_intensity" in
        Quick)
          _bc_emit_tier3_event tier3_skipped "intensity=quick"
          return 0
          ;;
      esac
      ;;
    full)
      case "$resolved_intensity" in
        Quick|Standard)
          _bc_emit_tier3_event tier3_skipped "intensity=$resolved_intensity"
          return 0
          ;;
      esac
      ;;
  esac

  # Find the largest oversized `^## ` section after Tier 1 + Tier 2.
  # Single-pass awk emits "<line_start> <line_end> <byte_size> <header>" for
  # the largest section whose body exceeds TIER3_SECTION_BUDGET_TOKENS.
  local target_info
  target_info="$(awk -v budget="$TIER3_SECTION_BUDGET_TOKENS" '
    function tok(c) { return int((c + 3) / 4) }
    BEGIN { cur_start=0; cur_chars=0; cur_header=""; max_chars=0; max_start=0; max_end=0; max_header="" }
    /^## / {
      if (cur_start > 0 && tok(cur_chars) > budget && cur_chars > max_chars) {
        max_start = cur_start; max_end = NR - 1
        max_chars = cur_chars; max_header = cur_header
      }
      cur_start = NR; cur_chars = length($0) + 1; cur_header = $0
      next
    }
    cur_start > 0 { cur_chars += length($0) + 1 }
    END {
      if (cur_start > 0 && tok(cur_chars) > budget && cur_chars > max_chars) {
        max_start = cur_start; max_end = NR
        max_chars = cur_chars; max_header = cur_header
      }
      if (max_start > 0) printf "%d %d %d %s\n", max_start, max_end, max_chars, max_header
    }
  ' "$capture_file")"

  if [ -z "$target_info" ]; then
    return 0   # No oversized section.
  fi

  local _line_start _line_end _section_chars _section_header
  _line_start="$(printf '%s\n' "$target_info" | awk '{print $1}')"
  _line_end="$(printf '%s\n' "$target_info" | awk '{print $2}')"
  _section_chars="$(printf '%s\n' "$target_info" | awk '{print $3}')"
  _section_header="$(printf '%s\n' "$target_info" | awk '{ for (i=4; i<=NF; i++) printf "%s%s", $i, (i==NF?"":" ") }')"

  local _section_tokens
  _section_tokens=$(( (_section_chars + 3) / 4 ))

  # MIT-08 density pre-check. density = input_tokens / budget; below floor
  # means the section is too sparse to compress without paying excess LLM
  # cost. awk computes the ratio in real arithmetic.
  local _density_ok
  _density_ok="$(awk -v t="$_section_tokens" -v b="$TIER3_SECTION_BUDGET_TOKENS" -v f="$TIER3_DENSITY_FLOOR" '
    BEGIN { ratio = (b > 0) ? (t * 1.0 / b) : 0; print (ratio >= f) ? "1" : "0" }
  ')"
  if [ "$_density_ok" != "1" ]; then
    _bc_emit_tier3_event tier3_skipped "reason=density-floor density=$_section_tokens/$TIER3_SECTION_BUDGET_TOKENS floor=$TIER3_DENSITY_FLOOR"
    return 0
  fi

  # Stage the section to a pre-file; persist the original to the originals dir.
  local pre_file out_file rendered_prompt summary_out
  pre_file="$TMPDIR_BUILD/_tier3_pre.txt"
  out_file="$TMPDIR_BUILD/_tier3_out.txt"
  rendered_prompt="$TMPDIR_BUILD/_tier3_prompt.txt"
  summary_out="$TMPDIR_BUILD/_tier3_summary.txt"

  awk -v s="$_line_start" -v e="$_line_end" 'NR>=s && NR<=e' "$capture_file" > "$pre_file"

  if ! mkdir -p "$TIER3_ORIGINALS_DIR" 2>/dev/null; then
    printf 'build-context.sh: tier3 disabled — originals_dir unwritable: %s\n' "$TIER3_ORIGINALS_DIR" >&2
    _bc_emit_tier3_event tier3_failed "reason=originals-dir-unwritable"
    return 0
  fi

  local _orig_hash _orig_path
  _orig_hash="$(printf '%s\x1F%s' "$_section_header" "$(cat "$pre_file")" | shasum -a 256 | cut -c1-64)"
  case "$TIER3_ORIGINALS_DIR" in
    */) _orig_path="${TIER3_ORIGINALS_DIR}${_orig_hash}.txt" ;;
    *)  _orig_path="${TIER3_ORIGINALS_DIR}/${_orig_hash}.txt" ;;
  esac
  if [ ! -f "$_orig_path" ]; then
    cp "$pre_file" "$_orig_path" 2>/dev/null || true
  fi

  # Render the prompt: template body + appended section bytes.
  local _tpl="$PROJECT_ROOT/templates/compression-tier3-prompt.md"
  if [ ! -f "$_tpl" ]; then
    _bc_emit_tier3_event tier3_failed "reason=prompt-template-missing path=$_tpl"
    return 0
  fi
  cat "$_tpl" "$pre_file" > "$rendered_prompt" 2>/dev/null || {
    _bc_emit_tier3_event tier3_failed "reason=prompt-render-failed"
    return 0
  }

  # Token budget for the LLM output: input_tokens * output_max_ratio.
  local _summary_budget
  _summary_budget="$(awk -v t="$_section_tokens" -v r="$TIER3_OUTPUT_MAX_RATIO" '
    BEGIN { print int(t * r) }
  ')"

  # Invoke dispatch-interface.sh (or the tier3-llm-call.sh shim if present).
  local _llm_caller="$PROJECT_ROOT/scripts/dispatch/dispatch-interface.sh"
  if [ -x "$PROJECT_ROOT/scripts/dispatch/lib/tier3-llm-call.sh" ]; then
    _llm_caller="$PROJECT_ROOT/scripts/dispatch/lib/tier3-llm-call.sh"
  fi
  bash "$_llm_caller" \
    --prompt-file "$rendered_prompt" \
    --capture-output "$summary_out" \
    --max-output-tokens "$_summary_budget" \
    --timeout-seconds 60 >/dev/null 2>&1 || {
    _bc_emit_tier3_event tier3_failed "reason=llm-call-nonzero"
    return 0
  }

  if [ ! -s "$summary_out" ]; then
    _bc_emit_tier3_event tier3_failed "reason=llm-empty-output"
    return 0
  fi

  # Output-size guard. discard if larger than ratio * input.
  local _summary_chars _summary_tokens _ratio_ok
  _summary_chars="$(wc -c < "$summary_out" | tr -d ' ')"
  _summary_tokens=$(( (_summary_chars + 3) / 4 ))
  _ratio_ok="$(awk -v sc="$_summary_chars" -v ic="$_section_chars" -v r="$TIER3_OUTPUT_MAX_RATIO" '
    BEGIN { ratio = (ic > 0) ? (sc * 1.0 / ic) : 1.0; print (ratio <= r) ? "1" : "0" }
  ')"
  if [ "$_ratio_ok" != "1" ]; then
    _bc_emit_tier3_event tier3_no_savings "reason=output-exceeds-max-ratio summary_chars=$_summary_chars input_chars=$_section_chars"
    return 0
  fi

  # Substitute the in-band marker placeholders in the LLM output.
  local _model="${ORCH_MODEL:-unknown}"
  sed -i.bak \
    -e "s|<MODEL>|$_model|" \
    -e "s|<N>|$_section_tokens|" \
    -e "s|<M>|$_summary_tokens|" \
    "$summary_out" 2>/dev/null || true
  rm -f "${summary_out}.bak" 2>/dev/null || true

  # Splice the summary back into the capture file.
  awk -v s="$_line_start" -v e="$_line_end" -v sf="$summary_out" '
    NR == s {
      while ((getline ln < sf) > 0) print ln
      close(sf)
      next
    }
    NR > s && NR <= e { next }
    { print }
  ' "$capture_file" > "$out_file"

  # Preservation self-check.
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier3" "$pre_file" "$out_file" tier3 >/dev/null 2>&1; then
      if type pres_emit_violation >/dev/null 2>&1; then
        local _t3_log
        _t3_log="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
        if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
          _t3_log="$ORCH_ROOT/execution-log.jsonl"
        fi
        pres_emit_violation "tier3" "$_section_header" "preservation-breach" "$_t3_log" 2>/dev/null || true
      fi
      _bc_emit_tier3_event tier3_failed "reason=preservation-breach"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"

  # Compute savings + write stats.
  local _savings_tokens
  _savings_tokens=$(( _section_tokens - _summary_tokens ))
  if [ "$_savings_tokens" -lt 0 ]; then _savings_tokens=0; fi
  printf 'savings_tokens=%d invocations=1\n' "$_savings_tokens" > "$stats_file"
  return 0
}

# T3 event emitter — appends a JSONL record to the active execution log naming
# the tier3 reason / status. Bail-safe per FR-9.
_bc_emit_tier3_event() {
  local record_type="$1"
  local reason="$2"
  local log_dir log_file ts unit_id
  log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  if [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ]; then
    log_dir="$ORCH_ROOT"
  fi
  log_file="$log_dir/execution-log.jsonl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  unit_id="${MILESTONE_ID}/${PHASE_ID}/${TASK_ID}"
  mkdir -p "$log_dir" 2>/dev/null || return 0
  printf '{"record_type":"%s","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","reason":"%s","timestamp":"%s"}\n' \
    "$record_type" "$unit_id" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$reason" "$ts" \
    >> "$log_file" 2>/dev/null || true
  return 0
}
```

### Step 4 — Wire the helper into the pipeline

Find the existing pipeline tail (around line 2017-2025):

```bash
_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
# (tier2 comment block ...)
_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
```

Insert the tier3 invocation immediately before the emitter:

```bash
_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true
# M018/P06/T01: Tier 3 auto-compact (LLM-routed). Failure-passthrough on
# every error path; never crashes the dispatch (FR-9).
_bc_apply_tier3 "$PAYLOAD_CAPTURE" || true
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
```

### Step 5 — Add tier3 config defaults to `templates/orchestrator-config-default.yml`

Locate the existing `compression:` block (the one with `tier1:` and `tier2:` sub-keys). Append a `tier3:` sub-block:

```yaml
  tier3:
    enabled: true
    intensity_floor: standard       # quick | standard | full — Quick skips T3 (FR-14).
    section_budget_tokens: 2500     # sections above this budget are eligible for T3.
    originals_dir: ".orchestrator/cache/tier3-originals/"
    output_max_ratio: 0.80          # discard summaries exceeding 80% of input bytes.
    density_floor: 1.5              # MIT-08: skip T3 when input_tokens/budget < floor.
```

### Step 6 — Optional: ship the `tier3-llm-call.sh` shim

Inspect `bash scripts/dispatch/dispatch-interface.sh --help` at integration time. If the CLI does NOT expose `--prompt-file` / `--capture-output` / `--max-output-tokens` / `--timeout-seconds` flags, ship a thin shim at `scripts/dispatch/lib/tier3-llm-call.sh` that translates the helper's call shape into whatever the dispatch interface accepts. The shim's contract is named in Prerequisites; the body is whatever shape the runtime requires. If the dispatch interface DOES expose the four flags, no shim is needed and `_bc_apply_tier3` calls `dispatch-interface.sh` directly (the helper auto-detects the shim path).

### Step 7 — Self-check during development

```bash
bash -n scripts/dispatch/build-context.sh
bash -n scripts/lib/knowledge-filter.sh
```

Both should exit 0. Run a known-pass dispatch (fresh project, planning branch) under `ORCH_M019_EMIT=0` to confirm nothing crashes.

## Verification

T01 ships only production code. The canonical truth verifiers
(`m018-p06-tier3-helper-shape.sh`, `m018-p06-tier3-prompt-template.sh`)
land in T04. T01's task-local extractable Check is a syntax-only
self-check (per the auto-loop verify parser's zero-Check refusal):

- Check: `bash -n scripts/dispatch/build-context.sh`

## Must-Haves (subset addressed by this task)

- **Truth #1**: `_bc_apply_tier3` helper exists and routes through `dispatch-interface.sh` with the new prompt template. Wholly addressed by Steps 1, 3, 4, 5.
- **Truth #2**: `templates/compression-tier3-prompt.md` exists with versioned frontmatter + input/output contract body. Wholly addressed by Step 2.

T01 does not address Truths #3 (T02 — schema additivity), #4 (T03 — compression-eval cohort), or #5 (T04 — dual-write).

## Notes

- **Bash 3.2** (MEM001): no `declare -A`; awk inside helper bodies is permitted by the MEM004 carve-out. Parallel scalars (`_line_start`, `_line_end`, etc.) — no associative arrays.
- **`sed -i.bak`** is the macOS-portable in-place edit form (BSD sed requires the `.bak` argument; the helper deletes the backup file unconditionally afterward). GNU sed accepts the same form. Bash 3.2 + macOS 12+ default sed both accept this shape.
- **shasum -a 256** is the canonical hash command Tier 1 uses (see `scripts/dispatch/build-context.sh:643-652`). T1's pattern of "stage to temp, shell out for digest" is reused here for the originals-cache key.
- **The summary marker substitution** uses literal `<MODEL>` / `<N>` / `<M>` placeholders in the LLM output. The LLM is instructed in the prompt template to emit those literal placeholders; the helper substitutes them post-call. This avoids requiring the LLM to know the model name + token counts (the orchestrator knows them; the LLM doesn't need to).
- **Failure-passthrough audit**: every `return 0` path that does NOT mutate `$capture_file` MUST leave `_tier3_stats.txt` at `savings_tokens=0 invocations=0` (the helper's first action ensures this). The success path overwrites the stats file with the actual savings. T02's emitter relies on this invariant.
- **MIT-08 framing**: density_floor=1.5 means the helper skips T3 unless input is at least 1.5× the budget. Below that, the LLM has too little to compact and the call is wasted. Operators can tune this; the default is conservative.
- **Originals cache co-tenancy**: `tier3-originals/` lives alongside `tool-results/` under `.orchestrator/cache/`. `cache-prune.sh` (P03) uses `for f in "$CACHE_DIR"/*` with no recursion, so tier3-originals/ is untouched by tier1 prune passes. A future T-row will add tier3-originals retention if disk-pressure surfaces (per the originals-authoritative principle, the orchestrator never auto-deletes tier3-originals; operator-driven prune only).
- **dispatch-interface.sh CLI surface uncertainty**: at integration time, T01 reads `bash scripts/dispatch/dispatch-interface.sh --help` to confirm the four flags. If absent, ship the shim per Step 6. The helper's `_llm_caller` lookup auto-detects the shim path (executable check on `scripts/dispatch/lib/tier3-llm-call.sh`).
- **No JSONL record_type collision**: `tier3_skipped`, `tier3_failed`, `tier3_no_savings` are new record_type values (additive — pre-M018 readers ignore unknown record_type per CON-5).
- **TIER3_INTENSITY_FLOOR resolution at top-of-file**: T01 also adds these lines to the top-of-file config-resolution block (around lines 199-206 of build-context.sh, after the tier2 block):

  ```bash
  # M018/P06/T01: Tier 3 auto-compact config. Defaults: enabled=true,
  # intensity_floor=standard, section_budget_tokens=2500,
  # originals_dir=.orchestrator/cache/tier3-originals/,
  # output_max_ratio=0.80, density_floor=1.5. Master compression.enabled
  # toggle (FR-15) gates this tier; per-tier compression.tier3.enabled
  # short-circuits Tier 3 alone.
  TIER3_ENABLED="$(kf_get_tier3_enabled "$PROJECT_ROOT")"
  TIER3_INTENSITY_FLOOR="$(kf_get_tier3_intensity_floor "$PROJECT_ROOT")"
  TIER3_SECTION_BUDGET_TOKENS="$(kf_get_tier3_section_budget_tokens "$PROJECT_ROOT")"
  TIER3_ORIGINALS_DIR="$(kf_get_tier3_originals_dir "$PROJECT_ROOT")"
  TIER3_OUTPUT_MAX_RATIO="$(kf_get_tier3_output_max_ratio "$PROJECT_ROOT")"
  TIER3_DENSITY_FLOOR="$(kf_get_tier3_density_floor "$PROJECT_ROOT")"
  case "$TIER3_ORIGINALS_DIR" in
    /*) : ;;
    *)  TIER3_ORIGINALS_DIR="$PROJECT_ROOT/$TIER3_ORIGINALS_DIR" ;;
  esac
  export TIER3_ENABLED TIER3_INTENSITY_FLOOR TIER3_SECTION_BUDGET_TOKENS \
         TIER3_ORIGINALS_DIR TIER3_OUTPUT_MAX_RATIO TIER3_DENSITY_FLOOR
  ```
