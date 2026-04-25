---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M020"
name: "Preferences helper (lib/preferences.sh)"
depends_on: []
---

## Prerequisites

- M020-CONTEXT.md AD-5: preferences are flat key-value scalar YAML; parsing strategy is grep+sed-based shell helper, NOT a full YAML parser. No `yq` dependency.
- M020-CONTEXT.md DC-8 THREAT-007 disposition: per-key resolution. Each key resolves INDEPENDENTLY with project>user>built-in-default precedence; partial overlap (project declares key A, user declares key B) is NOT a conflict — each key picks its winning source on its own.
- spec 025 FR-6: preferences live at `~/.orchestrator/preferences.yml` (user) and `.orchestrator/preferences.yml` (project). Project wins over user where both declare the same key.
- spec 025 acceptance scenario US-5/3 + Edge Case "Preferences file declares a threshold outside the valid range": malformed values fall back to default with a stderr diagnostic; the operator's preferences file is never rewritten.
- M020-CONTEXT.md DC-5 (Jaccard threshold default 0.7), OQ-1 (staleness threshold default 14 days), OQ-2 (operator identity fallback `unknown@local`).
- M020 cross-cutting concern (FR-8 / CON-1, "Read-only-during-dispatch invariant"): preferences.sh is a pure read helper; it MUST NOT mutate any file. All output flows to stdout; diagnostics flow to stderr.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no associative arrays. Parallel scalars or per-key case statements only.
- AD-19 (`commands/plan-phase.md` "Truth Check command shape"): every verifier script's body may use any internal shell construct; AD-19 governs the SHAPE of the `bash <script>` invocations the orchestrator's outer Bash tool issues, not the internals of those scripts.

## Description

Create a NEW pure-function helper at `scripts/knowledge/lib/preferences.sh` that implements FR-6 / US-5 preference resolution. The helper is sourceable (double-source-guarded per the P03/P05 convention) and exposes a single callable surface:

**`pref_resolve <key>`** — echoes the effective scalar value for `<key>` on stdout. Resolution algorithm:

1. If `<key>` is not in the closed-enum vocabulary {`default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`}, emit `FAIL: pref_resolve: unknown key '<key>'` on stderr and return non-zero exit. No stdout output.
2. Compute the project preferences path as `${PROJECT_ROOT:-<derived-project-root>}/.orchestrator/preferences.yml`. If the file exists AND contains a syntactically-clean `<key>: <value>` line AND `<value>` is valid for the key's type, echo `<value>` and return 0.
3. Else compute the user preferences path as `${HOME}/.orchestrator/preferences.yml`. If the file exists AND contains a syntactically-clean `<key>: <value>` line AND `<value>` is valid for the key's type, echo `<value>` and return 0.
4. Else echo the built-in default for `<key>` and return 0.

When step 2 or step 3 finds a `<key>: <value>` line whose value is INVALID (non-numeric for numeric keys, out-of-range for bounded keys, value outside the closed enum for `default_state_filter`), the helper:

- Skips that source (does NOT use the malformed value).
- Emits a single-line stderr diagnostic of the form `WARN: pref_resolve: malformed value for '<key>' in '<file>': '<raw-value>' — falling back to <next-source-or-default>`.
- Continues to the next source per the precedence chain.
- NEVER mutates the file (operator-owned file).

The five keys and their type/range constraints + built-in defaults:

| Key | Type | Range | Built-in default |
|-----|------|-------|------------------|
| `default_state_filter` | string | closed enum {`candidate`, `graduated`, `archived`} | `graduated` |
| `similarity_threshold` | float | `0.0 <= x <= 1.0` | `0.7` |
| `staleness_threshold` | int | `1 <= x <= 365` | `14` (days) |
| `preferred_cluster_size` | int | `1 <= x <= 50` | `8` |
| `operator_identifier` | string | non-empty, no `\n` or surrounding whitespace | `unknown@local` |

Path resolution honors environment-variable overrides for fixture isolation (matches the P01–P05 verifier convention):

- `PROJECT_ROOT` env var (when exported by a verifier) overrides the script-derived project root for the project-preferences path.
- `HOME` env var (standard POSIX) controls the user-preferences path.

`preferences.sh` is sourced by `scripts/knowledge/query.sh` (T02 of this phase) and from inside the `--cluster` short-circuit of `scripts/knowledge/consolidate-artifacts.sh` (T03 of this phase). It is NOT a callable surface from dispatch (FR-8 / CON-1 — preferences are operator-owned configuration, but `pref_resolve` itself is read-only and dispatch-safe through the consumer scripts).

## Steps

### Step 1: Create `scripts/knowledge/lib/preferences.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/preferences.sh`

Reference implementation:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/preferences.sh — FR-6 / US-5 preferences resolution helper.
#
# Provides:
#   pref_resolve <key>
#       Echoes the effective scalar value of <key> on stdout, applying
#       project>user>built-in-default precedence per-key (THREAT-007).
#       Closed-enum keys: default_state_filter, similarity_threshold,
#       staleness_threshold, preferred_cluster_size, operator_identifier.
#       Built-in defaults: graduated, 0.7, 14, 8, unknown@local.
#       Malformed values fall back with a single-line stderr diagnostic;
#       the preferences file is NEVER mutated.
#       Path resolution honors PROJECT_ROOT and HOME env vars for fixture
#       isolation (P01/P02/P05 verifier convention).
#
# Pure read helper — no writes anywhere. AD-19 single-script-invocation safe.
# Bash 3.2 compatible (MEM001). MEM001 prefixed-output conventions.

# --- Double-source guard ---
[ -n "${_PREFERENCES_HELPER_SOURCED:-}" ] && return 0
_PREFERENCES_HELPER_SOURCED=1

# --- Built-in defaults (single source of truth) ---
_PREF_DEFAULT_default_state_filter="graduated"
_PREF_DEFAULT_similarity_threshold="0.7"
_PREF_DEFAULT_staleness_threshold="14"
_PREF_DEFAULT_preferred_cluster_size="8"
_PREF_DEFAULT_operator_identifier="unknown@local"

# --- Closed-enum key vocabulary ---
_pref_is_known_key() {
  case "$1" in
    default_state_filter|similarity_threshold|staleness_threshold|preferred_cluster_size|operator_identifier)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Per-key validators. Return 0 iff $2 is a valid value for key $1. ---
_pref_validate_value() {
  local key="$1"
  local val="$2"
  case "$key" in
    default_state_filter)
      case "$val" in
        candidate|graduated|archived) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    similarity_threshold)
      # Float in [0.0, 1.0]. Accept N, N.NN, .NN forms.
      printf '%s\n' "$val" | awk '
        /^[0-9]+(\.[0-9]+)?$|^\.[0-9]+$/ {
          v = $0 + 0.0
          if (v >= 0.0 && v <= 1.0) { exit 0 } else { exit 1 }
        }
        { exit 1 }
      '
      return $?
      ;;
    staleness_threshold)
      # Int in [1, 365].
      case "$val" in
        ''|*[!0-9]*) return 1 ;;
      esac
      [ "$val" -ge 1 ] && [ "$val" -le 365 ]
      ;;
    preferred_cluster_size)
      # Int in [1, 50].
      case "$val" in
        ''|*[!0-9]*) return 1 ;;
      esac
      [ "$val" -ge 1 ] && [ "$val" -le 50 ]
      ;;
    operator_identifier)
      # Non-empty, no embedded newline or surrounding whitespace.
      [ -n "$val" ] || return 1
      case "$val" in
        ' '*|*' '|*$'\n'*) return 1 ;;
      esac
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Read a scalar key from a YAML file (grep+sed; AD-5 strategy). ---
# Echoes the raw scalar on stdout if found; empty stdout + return 1 if absent.
# Strips surrounding whitespace and surrounding single/double quotes.
_pref_read_scalar() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return 1
  local raw
  raw="$(grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null | head -1 \
    | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]*\$//; s/^['\"]//; s/['\"]\$//")"
  [ -n "$raw" ] || return 1
  printf '%s\n' "$raw"
  return 0
}

# --- Resolve the project preferences path (PROJECT_ROOT-aware). ---
_pref_project_path() {
  local root
  if [ -n "${PROJECT_ROOT:-}" ]; then
    root="$PROJECT_ROOT"
  else
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  fi
  printf '%s/.orchestrator/preferences.yml\n' "$root"
}

# --- Resolve the user preferences path (HOME-aware). ---
_pref_user_path() {
  printf '%s/.orchestrator/preferences.yml\n' "${HOME:-/tmp}"
}

# --- Try one source: read scalar, validate, echo + return 0 OR diagnose + return 1. ---
# Args: <key> <file> <next-source-label-for-diagnostic>
_pref_try_source() {
  local key="$1"
  local file="$2"
  local next="$3"
  local raw
  raw="$(_pref_read_scalar "$file" "$key")" || return 1
  if _pref_validate_value "$key" "$raw"; then
    printf '%s\n' "$raw"
    return 0
  fi
  printf "WARN: pref_resolve: malformed value for '%s' in '%s': '%s' — falling back to %s\n" \
    "$key" "$file" "$raw" "$next" >&2
  return 1
}

# --- Public: pref_resolve <key>. ---
pref_resolve() {
  local key="${1:-}"
  if [ -z "$key" ]; then
    echo "FAIL: pref_resolve: missing key argument" >&2
    return 1
  fi
  if ! _pref_is_known_key "$key"; then
    echo "FAIL: pref_resolve: unknown key '$key'" >&2
    return 1
  fi

  local proj_file user_file
  proj_file="$(_pref_project_path)"
  user_file="$(_pref_user_path)"

  # Step 1: project file (highest precedence).
  _pref_try_source "$key" "$proj_file" "user-or-default" && return 0

  # Step 2: user file.
  _pref_try_source "$key" "$user_file" "default" && return 0

  # Step 3: built-in default.
  local default_var="_PREF_DEFAULT_${key}"
  printf '%s\n' "${!default_var}"
  return 0
}
```

### Step 2: Create `scripts/verify/m020-p06-preferences-helper-contract.sh`

Verifier asserts:

- `scripts/knowledge/lib/preferences.sh` exists and is sourceable.
- After sourcing, `pref_resolve` is a defined function (`type -t pref_resolve` returns `function`).
- For each of the five keys, calling `pref_resolve <key>` against an empty fixture environment (tempdir `HOME` + tempdir `PROJECT_ROOT` with no preferences files present) returns the documented built-in default (`graduated`, `0.7`, `14`, `8`, `unknown@local`) on stdout with exit 0.

Use the `pass()`/`fail()` parallel-scalar pattern from MEM002. Tempdir + trap cleanup. Set `HOME` and `PROJECT_ROOT` to fresh tempdirs with no preferences files inside.

### Step 3: Create `scripts/verify/m020-p06-preferences-precedence.sh`

Verifier asserts project>user>default precedence per-key:

- Set `HOME=<user-tempdir>` and `PROJECT_ROOT=<project-tempdir>`.
- Write `<user-tempdir>/.orchestrator/preferences.yml` with `similarity_threshold: 0.8`.
- Write `<project-tempdir>/.orchestrator/preferences.yml` with `similarity_threshold: 0.6`.
- Assert `pref_resolve similarity_threshold` echoes `0.6` (project wins).
- Remove the project file. Assert `pref_resolve similarity_threshold` echoes `0.8` (user wins).
- Remove the user file. Assert `pref_resolve similarity_threshold` echoes `0.7` (default).
- Repeat for `default_state_filter` (project=`candidate`, user=`graduated` → `candidate`; user-only → `graduated`; none → `graduated`).
- Repeat for `staleness_threshold` (project=7, user=21, none → 14).
- Per-key partial-overlap assertion (THREAT-007): write project file with ONLY `similarity_threshold: 0.5` and user file with ONLY `staleness_threshold: 30`. Assert `pref_resolve similarity_threshold` → `0.5` AND `pref_resolve staleness_threshold` → `30` (each key resolves independently).

### Step 4: Create `scripts/verify/m020-p06-preferences-malformed-fallback.sh`

Verifier asserts malformed-value fallback semantics:

- Set `HOME=<user-tempdir>` and `PROJECT_ROOT=<project-tempdir>`.
- Write project file with `similarity_threshold: not-a-number`. Assert `pref_resolve similarity_threshold` echoes `0.7` on stdout, exits 0, AND emits a stderr line matching `^WARN: pref_resolve: malformed value for 'similarity_threshold'`.
- Assert the project file is byte-identical before and after the call (md5 snapshot).
- Write project file with `similarity_threshold: 1.5` (out-of-range). Same assertions.
- Write project file with `default_state_filter: zombie` (outside closed enum). Assert stdout = `graduated`, stderr matches `malformed value for 'default_state_filter'`.
- Write project file with `staleness_threshold: -1`. Assert stdout = `14`, stderr matches the warn pattern.
- Project malformed + user valid: project file `similarity_threshold: not-a-number`, user file `similarity_threshold: 0.9`. Assert stdout = `0.9` (falls through project to user), stderr emits the warn for project only.

### Step 5: Create `scripts/verify/m020-p06-preferences-key-vocabulary.sh`

Verifier asserts unknown-key rejection:

- Set up empty fixture environment.
- Call `pref_resolve some_unknown_key`. Assert: stdout is empty, stderr matches `^FAIL: pref_resolve: unknown key 'some_unknown_key'`, exit code is non-zero.
- Call `pref_resolve` with no arguments. Assert: stdout is empty, stderr matches `missing key argument`, exit code is non-zero.
- For sanity, call `pref_resolve` for each of the five known keys. Assert each call exits 0 (does not regress key-acceptance under the same code path).

## Must-Haves

This task addresses the following P06 must-haves:

- Truth: preferences.sh exists, is sourceable, exposes `pref_resolve <key>` (Check: `m020-p06-preferences-helper-contract.sh`).
- Truth: `pref_resolve` honors project>user>default precedence per-key (Check: `m020-p06-preferences-precedence.sh`).
- Truth: `pref_resolve` falls back on malformed values with stderr diagnostic, no file mutation (Check: `m020-p06-preferences-malformed-fallback.sh`).
- Truth: `pref_resolve` rejects unknown keys (Check: `m020-p06-preferences-key-vocabulary.sh`).
- Artifact: `scripts/knowledge/lib/preferences.sh` (min 100 lines, contains "pref_resolve").
- Artifact: each of the four T01 verifier scripts.

## Verification

```bash
bash scripts/verify/m020-p06-preferences-helper-contract.sh
bash scripts/verify/m020-p06-preferences-precedence.sh
bash scripts/verify/m020-p06-preferences-malformed-fallback.sh
bash scripts/verify/m020-p06-preferences-key-vocabulary.sh
```

Each script must exit 0. AD-19 compliant: each is a single `bash <script>` invocation with no compound chains.

## Inputs

### From Previous Tasks

None — T01 has no upstream P06 dependencies.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/frontmatter.sh` (P01) — not sourced by preferences.sh, but referenced for the double-source-guard convention pattern. Convention: `[ -n "${_<NAME>_SOURCED:-}" ] && return 0; _<NAME>_SOURCED=1`.
- `tests/test-knowledge-query.sh` (P02) — referenced for the tempdir + `HOME` + `PROJECT_ROOT` fixture-isolation pattern that the four T01 verifiers must use verbatim.

## Constraints

- **CON-1 / FR-8 (read-only)**: `pref_resolve` MUST NOT write to any file under any condition. Verifier `m020-p06-preferences-malformed-fallback.sh` enforces this with an md5 snapshot of the preferences file before/after each call.
- **AD-5 (scalar-only YAML)**: parse with `grep` + `sed` only. Do NOT introduce a `yq` dependency or call any external YAML parser. If the M020 schema later requires nested structures, a new D-row authorizes the parser swap; this task is not the place.
- **MEM001 (Bash 3.2)**: no `declare -A`. Use parallel scalars or `case` statements for the per-key vocabulary + validators.
- **AD-19 (single-script-invocation shape)**: each verifier's external test runner invokes it as a single `bash <script>` command. Internal shell constructs (subshells, pipes, etc.) inside the verifier scripts are unrestricted; AD-19 governs the orchestrator's outer Bash tool calls only.
- **MEM002 (test conventions)**: verifiers use the `pass()`/`fail()` parallel-scalar pattern; tempdir + trap cleanup; tempdir-based `HOME` and `PROJECT_ROOT` for fixture isolation (no live `~/.orchestrator/` or repo-root `.orchestrator/` access).
- **CON-4 (surgical precision)**: this task creates new files only — no in-place edits to other M020 files.

## Expected Output

After T01 ships:

```
$ bash scripts/verify/m020-p06-preferences-helper-contract.sh
PASS: lib/preferences.sh exists and is sourceable
PASS: pref_resolve is a defined function after source
PASS: pref_resolve default_state_filter -> graduated (built-in default)
PASS: pref_resolve similarity_threshold -> 0.7 (built-in default)
PASS: pref_resolve staleness_threshold -> 14 (built-in default)
PASS: pref_resolve preferred_cluster_size -> 8 (built-in default)
PASS: pref_resolve operator_identifier -> unknown@local (built-in default)
RESULT: 7/7 PASS
exit 0
```

Similar `RESULT: <N>/<N> PASS` exit-0 output from the other three verifiers.
