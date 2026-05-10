---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M018"
name: "Preservation-contract self-check library + density pre-check API"
depends_on: []
---

## Prerequisites

- P01 closed (2026-04-27): `references/compression-grammar.md` v1.0.1 (status: Reviewed) is on disk. Its `## Preserved-Pattern Vocabulary` table (lines 117–135) names ten cross-tier byte patterns every tier transformation must preserve.
- P01-SUMMARY MIT-08/09/10 carryover: this task implements MIT-10 (the regex-driven pattern walker spec) and the API surface for MIT-08 (density pre-check + tier2 passthrough fallback). Full MIT-08 enforcement gates P06; P02 only needs the API contract.
- Bash 3.2 + POSIX sh constraints apply (MEM001). No `declare -A`. Use parallel indexed arrays (`arr_k_0`, `arr_v_0`) if maps are needed.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans compound chains > 2, plain subshells, `$(... | ...)`, process substitution. Library functions MUST stay within these shape rules.

## Description

Author `scripts/lib/preservation-check.sh` — the load-bearing reusable library that P03 (T1 microcompact), P04 (T2 snip), and P06 (T3 auto-compact) will source to perform pre-/post-transform preservation checks against the cross-tier vocabulary defined in `references/compression-grammar.md`.

The library is sourceable (no `set -eu` at file scope, no top-level side effects beyond function declaration). It defines three exported functions:

1. **`pres_check_section <section_id> <pre_file> <post_file> [tier]`** — regex-driven pattern walker. Reads `<pre_file>` and `<post_file>`. For each preserved-pattern row in the cross-tier vocabulary, extracts every match in `<pre_file>` and asserts each match's exact byte sequence appears in `<post_file>` AT LEAST ONCE (tier3 semantics — see grammar `## Tier: tier3`) OR in the same multiplicity (tier1/tier2 semantics — see grammar `## Tier: tier1`/`## Tier: tier2`). The fourth optional arg `[tier]` defaults to `tier2` (strict multiplicity); pass `tier3` for at-least-once semantics. Returns 0 on PASS, 1 on first violation. Prints one `VIOLATION:` line to stderr per first failed pattern (single-violation diagnostic — the caller is expected to bail on first failure per FR-2 fail-closed semantics).

2. **`pres_emit_violation <tier> <section> <pattern> <log_file>`** — appends a `tier_preservation_violation` JSONL record to `<log_file>`. Schema (verbatim from `references/compression-grammar.md` line 371):
   ```json
   {"record_type":"tier_preservation_violation","tier":"<tier>","section":"<section>","pattern":"<regex>","timestamp":"<ISO8601 UTC>"}
   ```
   Single-line JSONL append. Bail-safe: directory-create failure logs to stderr and returns 0 (never crashes the dispatcher). The function never reads or modifies any file other than `<log_file>`.

3. **`pres_density_pre_check <section_file> <max_density_pct>`** — MIT-08 groundwork. Computes a coarse "preservation density" metric — `(count of preserved-pattern matches) / (total bytes / 100)` — and returns 0 (proceed) when density is below `<max_density_pct>`, returns 1 (refuse) when density exceeds the threshold. P06 will call this BEFORE invoking tier3's LLM summarization to enforce MIT-08's deterministic-fallback-to-tier2-passthrough on dense input. P02 ships only the API; no caller wires it yet (the wiring is documented in T01's expected output but not enforced — P02 verifier checks the function exists and returns sane values on a fixture, not that any caller invokes it).

The library also exposes a sourceable constant array of preserved-pattern regexes — `PRES_PATTERNS_REGEX_<N>` parallel indexed array (bash 3.2: no associative arrays) — so callers can iterate without re-parsing the grammar contract on every invocation. Patterns are hardcoded verbatim from `references/compression-grammar.md` lines 125–134; a comment in the library cross-references the grammar contract version (`v1.0.1`) so future grammar bumps trigger an explicit edit + verifier run.

## Steps

1. **Create `scripts/lib/preservation-check.sh`**. Shebang `#!/usr/bin/env bash`. NO `set -eu` at file scope (the file is sourced; `set -e` would propagate). Top-of-file comment block names the library version, the grammar contract version it pins to (`v1.0.1`), the export surface (the three functions + `PRES_PATTERNS_REGEX_*` array), and the AP-009 / AD-19 shape rules.

2. **Declare the preserved-pattern array** (bash 3.2 parallel indexed arrays). Use a *single* indexed array `PRES_PATTERNS_REGEX` with one row per pattern — simpler than parallel arrays for a flat list, still 3.2 safe. Patterns (verbatim from grammar contract):

   ```bash
   PRES_PATTERNS_REGEX=(
     '^---$'                                                                   # YAML frontmatter delimiter
     '^`{3,}[a-zA-Z0-9_-]*$'                                                  # Code fence (open or close, 3+ backticks)
     '/[A-Za-z0-9_./-]+\.(sh|md|yml|yaml|jsonl?|py|txt)'                       # Absolute file path
     'scripts/[A-Za-z0-9_./-]+\.sh'                                            # Repo-relative script path
     '\bMEM[0-9]{3}\b'                                                         # MEM ID
     'orchestrator:[a-z-]+'                                                    # Command name
     'https?://[^[:space:])]+'                                                  # URL
     '^\{.*\}$'                                                                 # JSONL record (full-line {...})
     '&lt;TODO:[^&gt;]+&gt;'                                                    # Scaffold-placeholder marker
     '<!-- compressed:tier[0-9]+ [^>]*-->'                                     # In-band compression marker
   )
   PRES_PATTERN_NAMES=(
     'yaml-frontmatter-delim'
     'code-fence'
     'absolute-path'
     'repo-relative-script-path'
     'mem-id'
     'command-name'
     'url'
     'jsonl-record'
     'scaffold-todo'
     'compression-marker'
   )
   ```

   Note: `PRES_PATTERNS_REGEX` and `PRES_PATTERN_NAMES` are parallel indexed arrays of equal length. Index `i` in the regex array names pattern `i` in the names array. This is the bash 3.2-safe shape (MEM001).

3. **Implement `pres_check_section`**:

   ```bash
   pres_check_section() {
     local section_id="$1" pre_file="$2" post_file="$3"
     local tier="${4:-tier2}"
     local i=0 regex name pre_count post_count
     local pat_count="${#PRES_PATTERNS_REGEX[@]}"
     while [ "$i" -lt "$pat_count" ]; do
       regex="${PRES_PATTERNS_REGEX[$i]}"
       name="${PRES_PATTERN_NAMES[$i]}"
       pre_count=$(grep -cE "$regex" "$pre_file" 2>/dev/null || echo 0)
       post_count=$(grep -cE "$regex" "$post_file" 2>/dev/null || echo 0)
       case "$tier" in
         tier3)
           # tier3: every pattern present in pre MUST appear in post AT LEAST ONCE
           if [ "$pre_count" -gt 0 ] && [ "$post_count" -eq 0 ]; then
             printf 'VIOLATION: section=%s pattern=%s tier=%s pre=%d post=%d\n' \
               "$section_id" "$name" "$tier" "$pre_count" "$post_count" >&2
             return 1
           fi
           ;;
         *)
           # tier1/tier2/default: strict multiplicity
           if [ "$pre_count" -ne "$post_count" ]; then
             printf 'VIOLATION: section=%s pattern=%s tier=%s pre=%d post=%d\n' \
               "$section_id" "$name" "$tier" "$pre_count" "$post_count" >&2
             return 1
           fi
           ;;
       esac
       i=$(( i + 1 ))
     done
     return 0
   }
   ```

   Shape compliance: no `$(...|...)`. Each `grep -cE` is a single command piped to nothing else; the `|| echo 0` is a top-level alternation on a single substitution, which AP-009 permits (compound chains > 2 are banned, but `cmd || cmd` at the top of a `$(...)` is one pipe-free substitution).

4. **Implement `pres_emit_violation`**:

   ```bash
   pres_emit_violation() {
     local tier="$1" section="$2" pattern="$3" log_file="$4"
     local ts log_dir
     ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
     log_dir=$(dirname "$log_file")
     mkdir -p "$log_dir" 2>/dev/null || {
       printf 'preservation-check: emit skipped (mkdir failed on %s)\n' "$log_dir" >&2
       return 0
     }
     # JSON-escape pattern: backslash, double-quote.
     local pattern_esc
     pattern_esc=$(printf '%s' "$pattern" | sed 's/\\/\\\\/g; s/"/\\"/g')
     printf '{"record_type":"tier_preservation_violation","tier":"%s","section":"%s","pattern":"%s","timestamp":"%s"}\n' \
       "$tier" "$section" "$pattern_esc" "$ts" \
       >> "$log_file" 2>/dev/null || true
     return 0
   }
   ```

   Bail-safe: directory-create or append failure logs and returns 0. The library never crashes the dispatcher.

5. **Implement `pres_density_pre_check`**:

   ```bash
   pres_density_pre_check() {
     local section_file="$1" max_density_pct="$2"
     [ ! -f "$section_file" ] && return 0
     local total_bytes total_matches=0 i=0 regex pat_count
     total_bytes=$(wc -c < "$section_file" | tr -d ' ')
     [ "$total_bytes" -eq 0 ] && return 0
     pat_count="${#PRES_PATTERNS_REGEX[@]}"
     while [ "$i" -lt "$pat_count" ]; do
       regex="${PRES_PATTERNS_REGEX[$i]}"
       local m
       m=$(grep -cE "$regex" "$section_file" 2>/dev/null || echo 0)
       total_matches=$(( total_matches + m ))
       i=$(( i + 1 ))
     done
     # Density = matches / (bytes / 100) = matches * 100 / bytes (integer math).
     local density_x100
     density_x100=$(( total_matches * 10000 / total_bytes ))
     # Compare against max_density_pct * 100 (so 5% threshold -> 500).
     local threshold_x100=$(( max_density_pct * 100 ))
     if [ "$density_x100" -gt "$threshold_x100" ]; then
       printf 'DENSITY-REFUSE: section=%s density_x100=%d threshold_x100=%d\n' \
         "$section_file" "$density_x100" "$threshold_x100" >&2
       return 1
     fi
     return 0
   }
   ```

   Returns 1 (refuse) when preserved-pattern density exceeds the configured threshold. P06 will plumb this in front of tier3's LLM call. Returns 0 on missing file (fail-open — preservation density of an empty section is 0).

6. **Verify the library is sourceable** by adding a smoke-test stub at the end (idempotent guard so the file's body still works when sourced):

   ```bash
   # Self-test entry point — run as `bash scripts/lib/preservation-check.sh selftest`
   if [ "${BASH_SOURCE[0]:-$0}" = "$0" ] && [ "${1:-}" = "selftest" ]; then
     tmp=$(mktemp -d)
     printf 'MEM020 says hello\n```\nfoo\n```\n' > "$tmp/pre.txt"
     printf 'MEM020 says hello\n```\nbar\n```\n' > "$tmp/post.txt"
     pres_check_section "test" "$tmp/pre.txt" "$tmp/post.txt" tier2
     rc=$?
     rm -rf "$tmp"
     if [ "$rc" -eq 0 ]; then
       printf 'PASS: pres_check_section selftest\n'
       exit 0
     else
       printf 'FAIL: pres_check_section selftest rc=%d\n' "$rc"
       exit 1
     fi
   fi
   ```

7. **Smoke-test the library locally**:

   ```bash
   bash scripts/lib/preservation-check.sh selftest
   ```

   Expected: `PASS: pres_check_section selftest` to stdout, exit 0.

## Must-Haves

This task addresses the phase truth:

- The preservation-contract self-check library exposes `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check`. (Verified by `bash scripts/verify/m018-p02-preservation-check-api.sh` which T04 ships.)

## Verification

```
bash scripts/lib/preservation-check.sh selftest
```

Expected output: `PASS: pres_check_section selftest` and exit 0.

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/
```

The phase-level must-have check at the end of the phase will exercise this library indirectly via T04's verifier. T01 itself is verified by the selftest above; the phase-level verifier exists only after T04 ships it.

## Inputs

### From Previous Tasks

None. T01 has no upstream task in P02.

### From Disk (Pre-existing)

- `references/compression-grammar.md` (v1.0.1, status: Reviewed) — the source of truth for the preserved-pattern vocabulary. Specifically the `## Preserved-Pattern Vocabulary` table (lines 117–135) and the `## Failure Semantics (FR-2)` `tier_preservation_violation` record schema (lines 368–378). The library hardcodes the vocabulary; a grammar bump triggers an explicit edit.
- `.orchestrator/scratch/m018-section-distribution-output.json` `.model_assumptions.filter` block — informs the density-threshold default (the filter assumes ~30% drop on Knowledge; density_pct on a typical Knowledge section sits well below 5% per the probe).

## Constraints

- **Bash 3.2 compatibility (MEM001)** — no `declare -A`, no `[[ =~ ]]` with extended regex flags beyond what 3.2 ships, no `mapfile`/`readarray` (4.0+).
- **AP-009 / AD-19 shape rules** — no compound chains > 2, no `$(...|...)`, no plain subshells `( ... )`, no process substitution `<(...)`. Pattern: each function uses sequential statements; iteration uses `while [ "$i" -lt "$N" ]; do ... ; i=$(( i + 1 )); done`.
- **Sourceable** — no top-level `set -eu` (the file is sourced by `build-context.sh` later). The `selftest` block is gated by the `${BASH_SOURCE[0]:-$0}" = "$0"` idiom.
- **Pure-ish** — `pres_emit_violation` is the only function with file-write side effects (named via parameter; never opens files implicitly). `pres_check_section` and `pres_density_pre_check` read files but do not write.
- **Bail-safe** — every function with file I/O catches errors and returns 0 (never crashes the dispatcher). Failures log to stderr only.
- **AGENTS.md dual-write convention** — this task does NOT edit CLAUDE.md or AGENTS.md. T04 handles the dual-write recent-changes refresh.

## Expected Output

- New file: `scripts/lib/preservation-check.sh` (~120–180 lines including comments, the three functions, the parallel arrays, and the selftest block).
- Smoke test passes: `bash scripts/lib/preservation-check.sh selftest` exits 0 and prints `PASS:`.
- The library is sourceable from any caller via `. "$PROJECT_ROOT/scripts/lib/preservation-check.sh"`. After sourcing, `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check`, and the `PRES_PATTERNS_REGEX` / `PRES_PATTERN_NAMES` arrays are in scope.

No callers wire the library yet — T02 wires the filter caller; P03/P04/P06 wire the tier callers. T01's job is to ship the API.
