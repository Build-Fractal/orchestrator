---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M018"
name: "Tier 2 head-drop function + boundary-refusal logic in build-context.sh + tier2 config accessors + additive tier2_savings_tokens emitter field"
depends_on: []
---

## Prerequisites

- P02 (knowledge-aware filter + preservation-check library) and P03 (Tier 1 microcompact) have shipped:
  - `scripts/lib/preservation-check.sh` exports `pres_check_section <section_id> <pre_file> <post_file> [tier]` (strict-multiplicity for `tier1`/`tier2`, at-least-once for `tier3`), `pres_emit_violation <tier> <section> <pattern> <log_file>`, the parallel arrays `PRES_PATTERNS_REGEX` and `PRES_PATTERN_NAMES` (10 entries), and `pres_density_pre_check` (Tier 3 only — not used by T01). T01 sources this library and uses `pres_check_section` + `pres_emit_violation` plus reads `PRES_PATTERNS_REGEX` directly for the boundary-refusal detector.
    - Critical detail: `PRES_PATTERNS_REGEX[1]` is `^\`{3,}[a-zA-Z0-9_-]*$` — the MIT-01 4+-backtick nested code-fence regex. The boundary-refusal detector MUST honor this (a code fence opened with 4+ backticks crosses ordinary 3-backtick boundaries and would be split unsafely if the detector only looked for 3-backtick rows).
  - `scripts/lib/knowledge-filter.sh` exports `kf_resolve_config_path <project_root>`, `kf_read_compression_scalar <cfg_file> <key>`, the existing `kf_get_compression_enabled`, `kf_get_knowledge_filter_enabled`, and the parallel `kf_get_tier1_{enabled,inline_threshold_tokens,preview_lines,cache_dir}` accessors. T01 adds `kf_get_tier2_{enabled,section_budget_tokens,protected_tail_ratio}` mirroring the tier1 shape verbatim (same default-when-empty case, same printf-newline contract).
  - `scripts/dispatch/build-context.sh` carries:
    - Config reads at lines ~189–192 — `TIER1_ENABLED`, `TIER1_INLINE_THRESHOLD_TOKENS`, `TIER1_PREVIEW_LINES`, `TIER1_CACHE_DIR`. T01 inserts `TIER2_*` reads immediately below this block.
    - `_bc_apply_knowledge_filter` (line 534) and `_bc_apply_tier1` (line 588) — dispatch-internal helpers. T01 adds `_bc_apply_tier2` adjacent to `_bc_apply_tier1` (immediately below it, before `_bc_gather_decisions` at line 761).
    - `_bc_emit_payload_breakdown` (line 1319) — the JSONL emitter that already carries `filter_dropped_tokens`, `tier1_savings_tokens`, and `tier1_invocations`. T01 extends it with one additive integer field `tier2_savings_tokens`.
    - Call-site at line 1723: `_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true` runs against the assembled payload BEFORE the `cat "$PAYLOAD_CAPTURE"` (line 1724) and BEFORE `_bc_emit_payload_breakdown` (line 1725). T01 inserts `_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true` IMMEDIATELY AFTER the tier1 call.
    - `PAYLOAD_CAPTURE="$TMPDIR_BUILD/_payload_capture.txt"` (line 1716) — the capture file the pipeline rewrites in place.
- `compression:` block in `.orchestrator/config.yml` already carries `compression.enabled`, `compression.knowledge_filter.*`, `compression.underperformance.*`, and `compression.tier1.*`. T01 appends a new `compression.tier2.*` sub-block under the existing `compression:` map; preserve every existing key byte-identical. Same change in `templates/orchestrator-config-default.yml`.
- `references/compression-grammar.md` `## Tier: tier2` (lines 191–211) is the contract:
  - applies-to: `payload-section-body` for `Knowledge`, `Task Plan`, `Upstream Context`. Other sections out of scope.
  - preserves: all cross-tier vocabulary patterns; the trailing `protected_tail_ratio` of the section byte-identical; the section heading line itself (head-drop never deletes the heading); the in-band tier2 marker once emitted (downstream tier3 wraps but never mutates kvpairs).
  - savings ceiling (P00 probe, 80% CI): low 25.33% / mean 25.49% / high 25.68%; model assumption is "head-drops ~40% of EXCESS over the 1500-tok tail threshold on any section that exceeds it (preserves last 1500 tok verbatim)".
  - failure semantics: self-check on output via `pres_check_section ... tier2`; on failure, pass section through unmodified plus `tier_preservation_violation` JSONL emit. Protected-tail breach (rare/should-be-impossible) emits a distinct `tier2_preservation_breach` record — T01 does NOT need to emit this in normal operation since boundary-refusal makes the breach unreachable; the record type is reserved for the grammar contract and exercised in T02's verifiers as a documented-but-unreachable path (no behavioral assertion required).
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` is the byte-identity disable-flag golden. T01 must not break it: when `compression.enabled: false`, the entire pipeline (filter + tier1 + tier2) short-circuits and the golden remains byte-identical. T02's `m018-p04-tier2-disable-flag.sh` verifier asserts this.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans: compound chains > 2; plain subshells; `$(...|...)` shell forms; process substitution `<(...)` / `>(...)`. Bash 3.2 — no `declare -A`. T01 follows MEM004's dispatch-internal carve-out (build-context.sh `_bc_*` helpers may use awk/pipes inside their bodies — the carve-out applies to dispatch-internal helpers, NOT to verifier scripts and NOT to agent-facing payload bytes).

## Description

Land Tier 2 snip inside `scripts/dispatch/build-context.sh`. After T01:

1. The build-context.sh assembled payload (captured to `$PAYLOAD_CAPTURE` after Tier 1 runs) passes through a Tier 2 head-drop stage that detects each in-scope section (`## Knowledge`, `## Task Plan`, `## Upstream Context`), measures the section's body-token count, and — if it exceeds `compression.tier2.section_budget_tokens` (default 1500) — head-drops the leading bytes that exceed the budget while preserving the trailing `compression.tier2.protected_tail_ratio` (default 0.3) of the section's pre-snip body byte-identical. The section heading line and any frontmatter that immediately follows the heading are never deleted.
2. The head-drop boundary is computed as a **line-aligned cut point**: T2 walks backward from the byte the budget would naively cut at, looking for a line whose start does not split a preserved-pattern row, and retreats further if the cut line lies inside a multi-line preserved span (frontmatter delimiter to delimiter, opening 4+-backtick code-fence to its matching closing fence at the same backtick-count). When no safe boundary exists in the head-drop range, the section passes through unmodified plus a `tier_preservation_violation` JSONL record names tier=`tier2` and the offending pattern (the cross-tier label of the spanning regex).
3. After the head-drop completes, `pres_check_section "<section>" <pre_file> <post_file> tier2` runs over the section bodies. On failure, the section reverts to the pre-snip body and `pres_emit_violation` records the violation. Strict-multiplicity tier2 semantics are exactly what the boundary-refusal detector is built to satisfy: any preserved-pattern occurrence inside the dropped head would change the post-vs-pre count by at least one and the self-check would catch it. The boundary-refusal detector is the "fail-fast before the snip" guard; the self-check is the "fail-safe after the snip" guard.
4. Tier 2 emits an in-band marker IMMEDIATELY AFTER the section heading line of every section it modifies:
   `<!-- compressed:tier2 head_dropped=<dropped_tokens> protected_tail_ratio=<R> -->`
   The marker is on its own line. The kvpair grammar matches the cross-tier vocabulary entry `<!-- compressed:tier[0-9]+ [^>]*-->` verbatim. `<dropped_tokens>` is the integer-quartile-tokens count of the dropped head bytes; `<R>` is the configured ratio formatted with two-decimal precision (e.g., `0.30`).
5. `_bc_emit_payload_breakdown` is extended with one additive integer field: `tier2_savings_tokens` (sum of dropped-head tokens across all in-scope sections in this dispatch). Pre-T2 records remain valid JSON; rollups read missing fields as 0.
6. `compression.tier2.*` config keys land in `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml`:
   - `compression.tier2.enabled` (default `true`)
   - `compression.tier2.section_budget_tokens` (default `1500`)
   - `compression.tier2.protected_tail_ratio` (default `0.3`)
7. Disable semantics:
   - `compression.enabled: false` → entire pipeline short-circuits (P02/P03 contract preserved).
   - `compression.tier2.enabled: false` → only Tier 2 short-circuits; the knowledge filter and Tier 1 still run.
   - `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env var still wins over both (existing test seam).

T01 does NOT ship the verifiers (T02), the fixtures (T02), the fixture-staging helper (T02), or the P04-SUMMARY (T02). T01 ships ONLY the production code that T02's verifiers exercise.

### Section grammar (canonical input shape T01 detects)

The build-context.sh-assembled payload organizes top-level sections by `^## <Section>` markdown headings. The in-scope section names per the grammar contract are:

```
## Knowledge
## Task Plan
## Upstream Context
```

A section body extends from the line AFTER its heading up to (but not including) the next `^## ` heading or end-of-file. T01's head-drop operates on the section body only — the heading line and any blank line immediately following it are never deleted.

### Boundary-refusal detector (the load-bearing inner loop)

The naive head-drop boundary is the byte index inside the section body at which keeping the suffix gives a `protected_tail_ratio`-sized preserved tail (default 0.3 of the pre-snip body). Computed in characters: `cut_byte = floor(body_len * (1 - protected_tail_ratio))`. The naive cut may land inside a preserved span. T01's detector retreats the cut to the nearest safe line boundary above the protected tail, refusing the snip outright if no safe boundary exists.

A line is **unsafe to cut at** when the line is part of an open multi-line preserved span. Multi-line spans T01 detects:

1. **YAML frontmatter delimiters** — pairs of `^---$` lines. A cut between the opening and closing `---` would orphan one delimiter.
2. **Code fences** — pairs of `^\`{3,}[a-zA-Z0-9_-]*$` lines at matching backtick-count (MIT-01: 4+-backtick fences nest inside 3-backtick fences and only close at a matching 4+-backtick line). A cut between the opening and closing fence would orphan the opener.
3. **In-band tier markers** — single-line `<!-- compressed:tier[0-9]+ [^>]*-->`. A previously-emitted marker (from a prior tier in the pipeline) must not be split. Single-line spans count as "unsafe at cut" only if the cut would land mid-line — line-aligned cuts cannot split a single-line marker, so marker-handling reduces to the line-aligned guarantee.

Single-line preserved patterns (paths, MEM IDs, command names, URLs, JSONL records, scaffold markers) are protected automatically by line-aligned cuts: no cut between two complete lines can split a single-line pattern. The detector only needs the multi-line span tracker.

**Algorithm:**

```
1. Walk the section body line-by-line, tracking nesting state for frontmatter
   (in_fm: bool) and code fences (fence_open_ticks: int, 0 when closed).
2. For each line index, record whether it is "inside a multi-line span" (i.e.,
   in_fm == 1 OR fence_open_ticks > 0 at the START of that line).
3. The naive cut byte determines the naive cut line — the line at which the
   cumulative byte count first crosses cut_byte.
4. Walk DOWN from the naive cut line toward line 0 looking for the first line
   whose "inside a multi-line span" flag is FALSE. That line's start byte is
   the safe head-drop boundary.
5. If the walk reaches the section heading line (i.e., no safe boundary above
   the protected tail), the section is passed through unmodified plus a
   tier_preservation_violation record names tier=tier2 and pattern as the
   spanning vocabulary entry (yaml-frontmatter-delim or code-fence).
```

The walk-down direction is correct: we want a cut at or above the naive cut byte (not below), because cutting below would shrink the protected tail beyond the configured ratio. If retreating eats into more than the budget allows the head-drop to still produce savings, T2 still emits the smaller savings — the budget is a maximum, not a minimum (see grammar contract: "budget" framing, not "target reduction").

### In-band marker emission

After the head-drop, the section is reassembled as:

```
## <Section>
<!-- compressed:tier2 head_dropped=<dropped_tokens> protected_tail_ratio=<R> -->
<verbatim post-cut bytes — the trailing protected_tail_ratio of the pre-snip body>
```

Where `<dropped_tokens>` is `tok(dropped_chars)` using the same `int((c+3)/4)` quartile estimator that Tier 1 uses (mirrors `chars_to_tokens_quartile` from `scripts/lib/pricing.sh`). `<R>` is the configured `protected_tail_ratio` formatted as `printf "%.2f"`.

The blank line that typically follows the section heading is preserved if it was present in the pre-snip body — the marker is inserted ABOVE that blank line so the visual structure stays consistent.

## Steps

### Step 1 — Append `compression.tier2.*` to `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml`

Use `Edit` to append after the existing `compression.tier1:` block in both files. Insert below it (still nested under `compression:`):

```yaml
  # M018/P04 — Tier 2 snip (head-drop with protected tail ratio).
  # When an in-scope section body's body-token count exceeds
  # `section_budget_tokens`, the leading bytes are head-dropped while the
  # trailing `protected_tail_ratio` of pre-snip section bytes survives
  # byte-identical. An in-band marker
  # `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` names
  # the snip. The cut is line-aligned and refuses to split frontmatter,
  # 4+-backtick code fences, or other multi-line preserved spans
  # (cross-tier vocabulary in `scripts/lib/preservation-check.sh`). In-scope
  # sections: `## Knowledge`, `## Task Plan`, `## Upstream Context`.
  tier2:
    enabled: true
    section_budget_tokens: 1500
    protected_tail_ratio: 0.3
```

Indentation: two-space, matching the existing `knowledge_filter:`, `underperformance:`, and `tier1:` siblings.

### Step 2 — Add `kf_get_tier2_*` accessors to `scripts/lib/knowledge-filter.sh`

Locate the existing `kf_get_tier1_cache_dir` function (line ~370) and append the three new accessors immediately below it, mirroring the tier1 pattern verbatim:

```bash
# ---------------------------------------------------------------------------
# kf_get_tier2_<key> <project_root>  ->  scalar
# M018/P04/T01: Tier 2 snip config accessors. Each returns the scalar value
# from compression.tier2.<key> or the documented default when absent.
# ---------------------------------------------------------------------------
kf_get_tier2_enabled() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.enabled)"
  if [ "$val" = "false" ]; then
    printf 'false\n'
  else
    printf 'true\n'
  fi
}

kf_get_tier2_section_budget_tokens() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.section_budget_tokens)"
  if [ -z "$val" ]; then
    printf '1500\n'
  else
    printf '%s\n' "$val"
  fi
}

kf_get_tier2_protected_tail_ratio() {
  local project_root="${1:-}"
  local cfg val
  cfg="$(kf_resolve_config_path "$project_root")"
  val="$(kf_read_compression_scalar "$cfg" tier2.protected_tail_ratio)"
  if [ -z "$val" ]; then
    printf '0.3\n'
  else
    printf '%s\n' "$val"
  fi
}
```

Also extend the file's top-of-file `Public surface` comment block to list the three new accessors (cosmetic — keeps the documented exports in sync with code).

### Step 3 — Add `TIER2_*` config reads to `build-context.sh`

In `scripts/dispatch/build-context.sh`, locate the existing tier1 config-read block (line ~189–192). Add immediately below the `TIER1_CACHE_DIR=` line:

```bash
# M018/P04/T01: Tier 2 snip config.
TIER2_ENABLED="$(kf_get_tier2_enabled "$PROJECT_ROOT")"
TIER2_SECTION_BUDGET_TOKENS="$(kf_get_tier2_section_budget_tokens "$PROJECT_ROOT")"
TIER2_PROTECTED_TAIL_RATIO="$(kf_get_tier2_protected_tail_ratio "$PROJECT_ROOT")"
```

(Use the `kf_get_tier2_*` accessors exactly as the surrounding tier1 reads do — same shape, same defaults-via-accessor contract.)

### Step 4 — Author the Tier 2 head-drop function `_bc_apply_tier2`

Place this function adjacent to `_bc_apply_tier1` (immediately below it; before `_bc_gather_decisions` at line ~761). The function reads the captured-payload file path on argument 1 and rewrites the file in place via a temp file + `mv` for atomicity. It returns 0 on success and on no-op short-circuit; it returns 0 (passthrough) on internal errors and emits a one-line stderr warning if needed. Stats are written to `$TMPDIR_BUILD/_tier2_stats.txt` for the emitter to read.

```bash
# M018/P04/T01: Tier 2 snip — section head-drop with protected tail.
#
# Argument 1: path to the captured payload file (already through Tier 1, prior
# to _bc_emit_payload_breakdown). The function rewrites the file in place
# when head-drop fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes a stats line to $TMPDIR_BUILD/_tier2_stats.txt of the form:
#       savings_tokens=<N>
#     The caller (_bc_emit_payload_breakdown) reads this file to populate
#     the additive `tier2_savings_tokens` field.
#
# Short-circuits (passthrough; stats file written with savings_tokens=0):
#   - $COMPRESSION_ENABLED != "true"
#   - $TIER2_ENABLED != "true"
#   - The capture file contains zero in-scope `^## ` sections.
#   - Every in-scope section's body token-count is at or below
#     $TIER2_SECTION_BUDGET_TOKENS.
#
# Boundary-refusal: when the line-aligned cut would land inside a
# multi-line preserved span (frontmatter `^---$` pair or `^`{3,}[a-zA-Z0-9_-]*$`
# code-fence pair at matching backtick-count), the cut retreats above the
# span; if no safe boundary exists at or above the naive cut byte and
# below the protected tail, the section passes through unmodified plus a
# tier_preservation_violation JSONL emit (tier=tier2, pattern=spanning
# vocabulary label).
#
# Preservation self-check:
#   - After head-drop, runs pres_check_section "<section>" <pre> <post> tier2
#     against the section bodies (pre = pre-snip body file, post = post-snip
#     body file). On failure, restores the pre-snip body byte-identical and
#     emits tier_preservation_violation via pres_emit_violation.
#
# AP-009 compliance: no compound chains > 2; no plain subshells; no
# $(...|...). Awk does the heavy lifting in a single invocation. The
# pres_check_section invocation is the standard library shape (same as
# tier1's call).
# MEM004 carve-out: dispatch-internal helper, like _bc_apply_tier1.
_bc_apply_tier2() {
  local capture_file="$1"
  if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$TIER2_ENABLED" != "true" ]; then
    return 0
  fi
  if [ ! -f "$capture_file" ]; then
    return 0
  fi

  local pre_file out_file stats_file
  pre_file="$TMPDIR_BUILD/_tier2_pre.txt"
  out_file="$TMPDIR_BUILD/_tier2_out.txt"
  stats_file="$TMPDIR_BUILD/_tier2_stats.txt"
  cp "$capture_file" "$pre_file"

  # Single awk pass:
  #   - Stream the input line by line.
  #   - Buffer each in-scope section's body (between its `## <Section>`
  #     heading and the next `## ` heading or EOF).
  #   - Track multi-line preserved spans line-by-line so each buffered line
  #     carries a "safe-to-cut-above-this-line" flag.
  #   - At section close, decide whether to head-drop:
  #       body_tokens > budget? compute naive cut, retreat to safe boundary,
  #       emit `## <Section>\n<!-- compressed:tier2 ... -->\n<tail>` or pass
  #       through verbatim plus emit a violation marker for the bash caller
  #       to pick up (via $TMPDIR_BUILD/_tier2_violations.txt).
  #
  # Inputs threaded as awk variables:
  #   budget   — section_budget_tokens
  #   ratio    — protected_tail_ratio (e.g. 0.3)
  #   stf      — stats_file
  #   vlf      — violations_file
  awk -v budget="$TIER2_SECTION_BUDGET_TOKENS" \
      -v ratio="$TIER2_PROTECTED_TAIL_RATIO" \
      -v stf="$stats_file" \
      -v vlf="$TMPDIR_BUILD/_tier2_violations.txt" \
      '
      function tok(c) { return int((c + 3) / 4) }
      function in_scope(name) {
        return (name == "Knowledge" || name == "Task Plan" || name == "Upstream Context")
      }
      function flush_section(   body_chars, body_tokens, cut_byte, i, cum, cut_line, j, drop_chars, drop_tokens, head_safe, fence_state, fm_state) {
        # body_buf has section body in body_lines[1..body_n], joined with
        # newlines on emit. body_unsafe[i] == 1 when line i sits inside an
        # open multi-line preserved span.
        if (!in_scope(sec_name)) {
          # Out-of-scope: emit as captured.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        body_chars = 0
        for (i = 1; i <= body_n; i++) {
          # +1 for the newline that joins back at emit time.
          body_chars += length(body_lines[i]) + 1
        }
        body_tokens = tok(body_chars)
        if (body_tokens <= budget + 0) {
          # Under budget — pass through verbatim.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        # Naive cut byte = floor(body_chars * (1 - ratio)).
        cut_byte = int(body_chars * (1.0 - ratio))
        # Walk forward in body lines accumulating until we cross cut_byte.
        cum = 0
        cut_line = body_n  # default sentinel (will retreat below)
        for (i = 1; i <= body_n; i++) {
          if (cum + length(body_lines[i]) + 1 > cut_byte) {
            cut_line = i
            break
          }
          cum += length(body_lines[i]) + 1
        }
        # Retreat: walk DOWN from cut_line toward line 1 until body_unsafe[i] == 0.
        head_safe = 0
        for (j = cut_line; j >= 1; j--) {
          if (body_unsafe[j] != 1) {
            head_safe = j
            break
          }
        }
        if (head_safe == 0) {
          # No safe boundary found — pass through unmodified, log violation.
          printf "%s", sec_raw
          # Find the spanning pattern label (best-effort).
          if (body_unsafe[cut_line] == 1) {
            printf "section=%s pattern=%s\n", sec_name, body_unsafe_label[cut_line] >> vlf
          } else {
            printf "section=%s pattern=%s\n", sec_name, "unknown" >> vlf
          }
          close(vlf)
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        # Compute drop_chars = cumulative bytes of lines [1..head_safe-1].
        drop_chars = 0
        for (i = 1; i < head_safe; i++) {
          drop_chars += length(body_lines[i]) + 1
        }
        if (drop_chars == 0) {
          # Cut at line 1 means nothing actually dropped — pass through.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        drop_tokens = tok(drop_chars)
        # Emit: heading line + marker + post-cut body.
        printf "%s\n", sec_heading
        printf "<!-- compressed:tier2 head_dropped=%d protected_tail_ratio=%.2f -->\n", drop_tokens, ratio + 0
        for (i = head_safe; i <= body_n; i++) {
          printf "%s", body_lines[i]
          if (i < body_n) {
            printf "\n"
          }
        }
        # Trailing newline iff the captured section ended with one (sec_raw
        # already encoded that; we mirror it by checking the last char of
        # the captured raw).
        savings_tok += drop_tokens
        sec_name=""; sec_raw=""; body_n=0
      }
      function open_section(line,   m) {
        # Any prior section is flushed by the caller before open_section is
        # called. Parse `## <Section>` heading.
        if (match(line, /^## [A-Za-z][^\n]*$/)) {
          sec_heading = line
          # Section name = heading minus the `## ` prefix; strip any
          # ` (N entries)`-style suffix introduced by the assembler.
          sub(/^## /, "", line)
          # Match the bare section identifier (one of Knowledge / Task Plan /
          # Upstream Context) by prefix-string compare to keep awk simple.
          if (line ~ /^Knowledge( |$)/)        { sec_name = "Knowledge" }
          else if (line ~ /^Task Plan( |$)/)   { sec_name = "Task Plan" }
          else if (line ~ /^Upstream Context( |$)/) { sec_name = "Upstream Context" }
          else                                  { sec_name = "OTHER" }
          sec_raw = sec_heading "\n"
          body_n = 0
          # Reset multi-line span trackers — sections are independent.
          fm_open = 0
          fence_open_ticks = 0
        }
      }
      BEGIN { sec_name=""; sec_raw=""; body_n=0; savings_tok=0; fm_open=0; fence_open_ticks=0 }
      /^## / {
        # New section header → flush any prior section, then open.
        if (sec_name != "") { flush_section() }
        open_section($0)
        next
      }
      sec_name == "" {
        # Pre-first-section bytes (manifest, frontmatter) — emit verbatim.
        print
        next
      }
      {
        # Body line of current section.
        body_n += 1
        body_lines[body_n] = $0
        # Compute "is this line INSIDE a multi-line span at the START of the
        # line?" — that is the unsafe flag the cut-retreat walker reads.
        body_unsafe[body_n] = (fm_open == 1 || fence_open_ticks > 0) ? 1 : 0
        body_unsafe_label[body_n] = (fm_open == 1) ? "yaml-frontmatter-delim" : (fence_open_ticks > 0 ? "code-fence" : "")
        # Update span state AFTER recording the flag (so the line that opens
        # a span is itself safe — the cut may land at the OPENER, but a cut
        # below the opener falls inside the span and is unsafe).
        if ($0 == "---") {
          if (fm_open == 0) { fm_open = 1 } else { fm_open = 0 }
        } else if (match($0, /^`{3,}[a-zA-Z0-9_-]*$/)) {
          # Count backticks at start.
          ticks = 0
          for (k = 1; k <= length($0); k++) {
            if (substr($0, k, 1) == "`") { ticks += 1 } else { break }
          }
          if (fence_open_ticks == 0) {
            fence_open_ticks = ticks
          } else if (ticks == fence_open_ticks) {
            # Matching closer — close.
            fence_open_ticks = 0
          }
          # Mismatched ticks inside an open fence — leave fence_open_ticks
          # unchanged (the inner line is just content of the outer fence).
        }
        # sec_raw mirrors the captured bytes for the verbatim-passthrough path.
        sec_raw = sec_raw $0 "\n"
        next
      }
      END {
        if (sec_name != "") { flush_section() }
        printf "savings_tokens=%d\n", savings_tok > stf
        close(stf)
      }
      ' "$pre_file" > "$out_file"

  # Pick up any boundary-refusal violations the awk pass logged.
  if [ -f "$TMPDIR_BUILD/_tier2_violations.txt" ]; then
    if type pres_emit_violation >/dev/null 2>&1; then
      local _t2_log _vline _vsec _vpat
      _t2_log="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
      if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
        _t2_log="$ORCH_ROOT/execution-log.jsonl"
      fi
      while IFS= read -r _vline; do
        # _vline shape: `section=<name> pattern=<label>`.
        _vsec="$(printf '%s' "$_vline" | sed -n 's/^section=\([^ ]*\).*$/\1/p')"
        _vpat="$(printf '%s' "$_vline" | sed -n 's/.* pattern=\(.*\)$/\1/p')"
        pres_emit_violation "tier2" "$_vsec" "$_vpat" "$_t2_log" 2>/dev/null || true
      done < "$TMPDIR_BUILD/_tier2_violations.txt"
    fi
    rm -f "$TMPDIR_BUILD/_tier2_violations.txt" 2>/dev/null || true
  fi

  # Preservation self-check on the rewritten payload as a whole. Strict
  # tier2 multiplicity — every preserved-pattern occurrence in the pre
  # payload must occur in the post payload (the head-drop of an in-scope
  # section legitimately removes content; the boundary-refusal detector
  # is the guarantee that the removed content carried zero preserved
  # patterns. If the self-check disagrees, the snip is undone.)
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier2" "$pre_file" "$out_file" tier2 >/dev/null 2>&1; then
      if type pres_emit_violation >/dev/null 2>&1; then
        local _t2_log2
        _t2_log2="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
        if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
          _t2_log2="$ORCH_ROOT/execution-log.jsonl"
        fi
        pres_emit_violation "tier2" "payload" "cross-tier" "$_t2_log2" 2>/dev/null || true
      fi
      cp "$pre_file" "$capture_file"
      printf 'savings_tokens=0\n' > "$stats_file"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"
  return 0
}
```

Notes on the awk implementation:

- The `body_unsafe` flag is computed for each body line at the START of the line, BEFORE the line itself is processed for span-open/close. That gives the correct invariant: "if I cut JUST ABOVE this line, am I inside an open span?" The line that OPENS a fence has `body_unsafe[i] == 0` because the span was not yet open at the start of that line — cutting above the opener is safe (the opener and everything below it falls into the protected tail). Cutting below the opener but above the closer is unsafe.
- `body_unsafe_label[]` records which span class is open at each unsafe line so the violation message names the right cross-tier pattern.
- The 4+-backtick detection (MIT-01) is built into the regex `^\`{3,}[a-zA-Z0-9_-]*$` and the explicit `ticks == fence_open_ticks` matching: a 3-backtick line CANNOT close an open 4-backtick fence (different tick count), so nested fences are tracked correctly by tick-count.
- `protected_tail_ratio` is forced to numeric via `ratio + 0` in arithmetic and `printf "%.2f"` for the marker emit. The accessor returns the textual scalar (e.g., `0.3`), and awk converts on first arithmetic use.
- The `END` block writes `savings_tokens=<N>` to `$stats_file`; the emitter (Step 6) reads that file with the same defaulting pattern as the existing `_tier1_stats.txt` reader.
- `sec_raw` accumulates the captured section bytes for the verbatim-passthrough path (under-budget sections, out-of-scope sections, and refusal cases). This avoids re-stitching `body_lines[]` with newline-joining quirks for the passthrough path.

### Step 5 — Wire `_bc_apply_tier2` into the dispatch path

`build-context.sh` already calls `_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true` at line 1723 between `_bc_assemble_manifest_and_emit` and `cat "$PAYLOAD_CAPTURE"`. Insert the Tier 2 call IMMEDIATELY AFTER the tier1 call:

```bash
_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
# M018/P04/T01: Tier 2 snip runs against the post-tier1 captured payload BEFORE
# the receiving agent sees the bytes (cat below) and BEFORE the breakdown
# emitter samples it (so emitter section sizes reflect post-tier2 reality).
# Short-circuits when `compression.enabled: false` (P02 byte-identity contract)
# or when `compression.tier2.enabled: false` (per-tier disable).
_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true
cat "$PAYLOAD_CAPTURE"
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
```

(The existing `_bc_emit_payload_filter || true` and `_bc_emit_compression_underperformance || true` at lines 1726–1727 are unaffected.)

### Step 6 — Extend `_bc_emit_payload_breakdown` with the `tier2_savings_tokens` additive field

In `_bc_emit_payload_breakdown` (line ~1319), find the existing `tier1_savings_tokens` read block (around line 1407+ — it reads `$TMPDIR_BUILD/_tier1_stats.txt`). Add a sibling block immediately after it:

```bash
  # M018/P04/T01 (CON-5): additive `tier2_savings_tokens` field. Reads
  # $TMPDIR_BUILD/_tier2_stats.txt written by _bc_apply_tier2. Defaults to 0
  # when tier2 was disabled, the file is absent, or no in-scope section
  # exceeded the budget.
  local tier2_savings_tokens=0
  local _bc_pb_t2_stats="$TMPDIR_BUILD/_tier2_stats.txt"
  if [ -f "$_bc_pb_t2_stats" ]; then
    tier2_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) { sub("savings_tokens=", "", $i); print $i; exit }
      }
    }' "$_bc_pb_t2_stats")"
    if [ -z "$tier2_savings_tokens" ]; then tier2_savings_tokens=0; fi
  fi
```

Then update the printf format string at line ~1436 to insert `"tier2_savings_tokens":%d,` IMMEDIATELY AFTER the `tier1_invocations` field (preserving every other field in current order):

```bash
  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier1_invocations":%d,"tier2_savings_tokens":%d,"model":"%s","source":"estimate","timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$payload_chars" "$payload_tokens" \
    "$section_tokens_json" "$filter_dropped_tokens" \
    "$tier1_savings_tokens" "$tier1_invocations" \
    "$tier2_savings_tokens" \
    "$model" "$ts" \
    >> "$log_file" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown append failed on %s\n' "$log_file" >&2
    return 0
  }
```

CON-5 invariants: pre-T2 records remain valid JSON; T01 only ADDS one field. Rollups treat missing fields as 0.

### Step 7 — Self-test: dispatch the build-context.sh against the existing P03 fixture

Run:

```
bash scripts/dispatch/build-context.sh M018 P04 T01-self-test
```

against the current state with `compression.enabled: true`. The execution-log.jsonl should now show a `payload_breakdown` record with `tier2_savings_tokens` field present (0 if no in-scope section exceeded the budget — that's fine; T02's verifiers exercise a fixture with real over-budget sections).

Run:

```
ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh M018 P04 T01-self-test
```

The captured payload bytes must remain byte-identical to the pre-P04 path under disable. (T02 wires the golden-payload regression verifier; T01's self-check is an interactive sanity check.)

Also confirm `bash -n scripts/dispatch/build-context.sh` succeeds (syntax check).

## Must-Haves

- Tier 2 head-drop fires on in-scope sections (`## Knowledge`, `## Task Plan`, `## Upstream Context`) whose body-token count exceeds `compression.tier2.section_budget_tokens`, removing head bytes above the budget while leaving the trailing `protected_tail_ratio` byte-identical (T02 verifier `m018-p04-tier2-head-drop.sh`).
- Tier 2 emits the in-band `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` marker immediately after every modified section's heading line (T02 verifier `m018-p04-tier2-marker.sh`).
- Boundary-refusal: when the line-aligned cut would split a 4+-backtick code fence or a frontmatter delimiter pair, the cut retreats above the span; with no safe boundary, the section passes through unmodified plus a `tier_preservation_violation` (tier=`tier2`) JSONL emit (T02 verifier `m018-p04-tier2-boundary-refusal.sh`).
- `payload_breakdown` records carry an additive integer `tier2_savings_tokens` field; pre-T2 records remain valid JSON (T02 verifier `m018-p04-tier2-emitter-additivity.sh`).
- `compression.enabled: false` short-circuits the entire pipeline; `compression.tier2.enabled: false` short-circuits only Tier 2 (T02 verifier `m018-p04-tier2-disable-flag.sh`).
- Body-level preservation self-check via `pres_check_section ... tier2`; failure passes the section through unmodified plus a `tier_preservation_violation` JSONL emit (T02 verifier `m018-p04-tier2-preservation-self-check.sh`).

## Verification

- `bash scripts/verify/m018-p04-tier2-head-drop.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-marker.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-boundary-refusal.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-emitter-additivity.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-disable-flag.sh` — PASS.
- `bash scripts/verify/m018-p04-tier2-preservation-self-check.sh` — PASS.

T02 ships these verifiers; they exercise T01's production code. Until T02 lands, T01 is verifiable via the self-test in Step 7 plus a `bash -n scripts/dispatch/build-context.sh` syntax check.

## Inputs

### From Previous Tasks

(None within P04 — T01 is the first task.)

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the dispatch payload assembler. Key insertion points:
  - line ~189–192 (tier1 config-read block; tier2 reads land immediately below).
  - line ~588 (`_bc_apply_tier1`; `_bc_apply_tier2` lands immediately below it, before `_bc_gather_decisions` at line 761).
  - line ~1319 (`_bc_emit_payload_breakdown`); line ~1407 (the `tier1_savings_tokens` read block; tier2 read lands immediately after); line ~1436 (the JSONL printf format).
  - line ~1723 (the `_bc_apply_tier1` call site; the `_bc_apply_tier2` call lands immediately after).
- `scripts/lib/preservation-check.sh` — sourceable. T01 uses `pres_check_section` and `pres_emit_violation` (tier2 strict-multiplicity branch). The `PRES_PATTERNS_REGEX` array is referenced by the boundary-refusal detector through the explicit awk regex constants in the implementation (NOT via array-indirection — awk variable scoping makes that awkward; the two multi-line regexes that matter live verbatim in the awk script).
- `scripts/lib/knowledge-filter.sh` — sourceable. T01 adds three new accessors (`kf_get_tier2_*`) mirroring `kf_get_tier1_*`. Same `kf_resolve_config_path` + `kf_read_compression_scalar` plumbing.
- `scripts/lib/pricing.sh` — sourceable; `chars_to_tokens_quartile` defines the `(chars+3)/4` token estimator T01 mirrors in awk via the `tok()` helper (identical to the tier1 implementation).
- `.orchestrator/config.yml` — Step 1 appends to the `compression:` map (current end of `compression.tier1:` block is around line 75 — locate `cache_dir:` + insert below).
- `templates/orchestrator-config-default.yml` — Step 1 appends the same block.
- `references/compression-grammar.md` `## Tier: tier2` (lines 191–211) — contract.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — P02/P03 disable-flag golden; T01 must NOT change its bytes when `compression.enabled: false`.

## Constraints

- **AP-009 (Bash shape guard)**: zero compound chains > 2 in shell-shape; zero plain subshells; zero `$(...|...)` shell forms. Awk-internal `cmd | getline` is permitted (it's awk-internal, not shell-shape) — but T01's awk implementation does not need shell-out; SHA-256 is not required for Tier 2 since the tier has no cache.
- **Bash 3.2 compatibility**: no `declare -A`; no associative arrays; parallel indexed arrays only. The awk implementation can use awk associative arrays freely (awk is awk, not bash).
- **CON-5 (additive emitters)**: `payload_breakdown` records gain ONE new field (`tier2_savings_tokens`); no existing field is removed or renamed; pre-T2 records remain valid JSON.
- **Constitution Principle VI (originals authoritative)**: T01 writes ONLY to `$TMPDIR_BUILD/*` (transient), `execution-log.jsonl` (additive emit), and the in-flight `$PAYLOAD_CAPTURE`. No canonical file (knowledge tree, spec, plan, roadmap) is touched. Tier 2 has NO cache directory — head-drop is destructive on the dispatch-time payload; the originals on disk are untouched.
- **MIT-01 (4+-backtick code-fence regex)**: T01's boundary-refusal detector MUST honor the `^\`{3,}[a-zA-Z0-9_-]*$` regex from `PRES_PATTERNS_REGEX[1]`. The fence-state tracker counts the opening backticks and closes only on a matching backtick-count line — a 3-backtick line cannot close a 4-backtick fence. T02's `m018-p04-tier2-boundary-refusal.sh` verifier exercises a fixture with a 4-backtick-fenced over-budget section to assert this directly.
- **Disable contract**: when `compression.enabled: false` OR `ORCH_OVERRIDE_COMPRESSION_ENABLED=false`, T01 MUST short-circuit before any payload mutation. The P02 golden payload (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) is the regression contract — T02's `m018-p04-tier2-disable-flag.sh` verifier asserts byte-identity.
- **MEM004 (Pure Lib Extraction)**: T01's `_bc_apply_tier2` is dispatch-internal, like the existing `_bc_apply_knowledge_filter` and `_bc_apply_tier1`. It does not need to live in a separate `scripts/lib/tier2.sh` (single call site; no second consumer in scope). If P05 or beyond demands cross-call-site reuse, the function migrates to `scripts/lib/tier2.sh` then.

## Expected Output

- `scripts/dispatch/build-context.sh` grew by ~200 lines (the `_bc_apply_tier2` function plus the four config-read lines plus the 10–15-line emitter additions plus the call-site insertion).
- `scripts/lib/knowledge-filter.sh` grew by ~45 lines (three new `kf_get_tier2_*` accessors).
- `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml` carry the new `compression.tier2.*` block under the existing `compression:` map.
- `bash -n scripts/dispatch/build-context.sh` succeeds (syntax check).
- A self-test invocation of build-context.sh produces a `payload_breakdown` JSONL line whose JSON parses cleanly (`python3 -c 'import json,sys;[json.loads(l) for l in open(sys.argv[1])]' execution-log.jsonl`) and contains a `tier2_savings_tokens` integer-valued key.
- No verifier files yet — T02 ships those.
