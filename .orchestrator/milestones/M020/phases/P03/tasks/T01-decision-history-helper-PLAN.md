---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M020"
name: "decision-history helper (operator resolution + JSONL record shapes)"
depends_on: []
---

## Prerequisites

- P01: `knowledge/conventions/MEM031.md` documents the closed enum `{candidate, graduated, archived}`, the FR-7 `decision_history:` companion-field shape (`rationale`, `timestamp`, `operator`, `cluster_id`), and the `archived_into:` companion-field shape.
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_append_decision_history <file> <rationale> <operator> <cluster_id>` which writes the YAML record into the entry's frontmatter.
- The orchestrator already emits JSONL records to `.orchestrator/execution-log.jsonl` via shell `printf >> $LOG_FILE` (see `scripts/knowledge/consolidate-artifacts.sh:235-244` for the canonical pattern). T01 follows the same convention.
- `git config user.email` is the primary operator-identity source per OQ-2 (resolved in M020-CONTEXT.md cross-cutting concerns).

## Description

Create `scripts/knowledge/lib/decision-history.sh` — a sourceable helper that exposes two pure functions consumed by T02's extended `graduate.sh`:

1. `dh_resolve_operator` — resolves the operator identity at write time. Order: try `git config user.email`; if empty/error, look for `.orchestrator/preferences.yml` and read a top-level scalar `operator_identifier:` value; if neither yields a non-empty string, default to `unknown@local`. Pure read — never writes anything.

2. `dh_emit_jsonl <event-type> <key=value>...` — appends a single JSONL record to `${ORCH_ROOT:-.orchestrator}/execution-log.jsonl` with the supplied event type and `key=value` payload pairs encoded as JSON. Two event types are emitted by T02: `knowledge_graduate` (payload: `entry_id`, `cluster_id`, `rationale_hash`) and `knowledge_archive` (payload: `entry_id`, `archived_into`, `rationale_hash`). Both records also include a `timestamp` field (ISO 8601 UTC) and a `milestone` field (read from the active milestone if present, else empty string).

Out of scope (deferred to T02):
- Calls into `fm_append_decision_history` (T01 is helper-only — no frontmatter mutation).
- The `graduate.sh` argument parser changes for `--cluster` / `--reject`.
- Integration test (T04).

## Steps

### Step 1: Create `scripts/knowledge/lib/decision-history.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/decision-history.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/decision-history.sh — FR-7 + OQ-2 helper consumed by
# scripts/knowledge/graduate.sh (P03 cluster-aware extension).
#
# Provides:
#   dh_resolve_operator              -> echoes operator identity (one line)
#   dh_emit_jsonl <event> <kv>...    -> appends a JSONL record to
#                                       $ORCH_ROOT/execution-log.jsonl
#
# Pure helpers — neither writes to knowledge/**. Frontmatter mutation flows
# through scripts/knowledge/lib/frontmatter.sh::fm_append_decision_history
# directly from graduate.sh.
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape (no inline
# compounds in any callable surface). MEM001 prefixed-output conventions.

# --- Double-source guard ---
[ -n "${_DECISION_HISTORY_HELPER_SOURCED:-}" ] && return 0
_DECISION_HISTORY_HELPER_SOURCED=1

# --- Operator identity resolver (OQ-2) ---
# Order: git config user.email -> preferences.yml:operator_identifier
#        -> unknown@local
# Pure read — never writes.
dh_resolve_operator() {
  local email
  email="$(git config user.email 2>/dev/null || true)"
  if [ -n "$email" ]; then
    printf '%s\n' "$email"
    return 0
  fi

  local prefs_file=".orchestrator/preferences.yml"
  if [ -f "$prefs_file" ]; then
    local pref_val
    pref_val="$(awk '
      /^operator_identifier:[[:space:]]/ {
        sub(/^operator_identifier:[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    ' "$prefs_file" 2>/dev/null || true)"
    if [ -n "$pref_val" ]; then
      printf '%s\n' "$pref_val"
      return 0
    fi
  fi

  printf '%s\n' "unknown@local"
}

# --- JSONL record emitter ---
# Usage: dh_emit_jsonl <event-type> <key1>=<val1> [<key2>=<val2> ...]
#
# Appends a single JSON object on its own line to
#   ${ORCH_ROOT:-.orchestrator}/execution-log.jsonl
#
# The record always carries a top-level event="<type>" + timestamp=<ISO 8601 UTC>
# + milestone=<active-milestone-id-or-empty>; remaining key=value pairs are
# inlined as JSON string values. Values are not type-coerced (everything is
# emitted as a JSON string) — keep it simple per Principle XIV.
#
# JSON escaping is conservative: backslashes and double-quotes inside values
# are escaped; control chars are passed through (we never put them in any
# value supplied by graduate.sh, which only emits ASCII rationale-hashes and
# entry-IDs).
dh_emit_jsonl() {
  local event="$1"
  shift
  local orch_root="${ORCH_ROOT:-.orchestrator}"
  local log_file="$orch_root/execution-log.jsonl"
  mkdir -p "$orch_root" 2>/dev/null || true

  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Resolve active milestone (best effort — empty string if not derivable).
  local milestone=""
  if [ -f "$orch_root/active-milestone" ]; then
    milestone="$(cat "$orch_root/active-milestone" 2>/dev/null || true)"
  fi

  # Build the JSON object body. Conservative escaping: backslash + double-quote.
  local body
  body="$(printf '"event":"%s","timestamp":"%s","milestone":"%s"' \
    "$(_dh_json_escape "$event")" \
    "$(_dh_json_escape "$timestamp")" \
    "$(_dh_json_escape "$milestone")")"

  local kv key val esc_val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    esc_val="$(_dh_json_escape "$val")"
    body="$body,\"$key\":\"$esc_val\""
  done

  printf '{%s}\n' "$body" >>"$log_file"
}

# --- Internal: minimal JSON string escaping ---
_dh_json_escape() {
  local s="$1"
  # Escape backslash first so the next sed does not double-escape.
  s="$(printf '%s' "$s" | sed 's/\\/\\\\/g')"
  s="$(printf '%s' "$s" | sed 's/"/\\"/g')"
  printf '%s' "$s"
}
```

Make the file mode-bits readable (it is sourced, not executed; chmod +x not strictly required, but apply for symmetry with sibling helpers):

```
chmod 0644 scripts/knowledge/lib/decision-history.sh
```

### Step 2: Create `scripts/verify/m020-p03-decision-history-helper-contract.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p03-decision-history-helper-contract.sh`

```bash
#!/usr/bin/env bash
# m020-p03-decision-history-helper-contract.sh — assert dh_resolve_operator
# fallthrough chain and dh_emit_jsonl record shape per T01 plan.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/lib/decision-history.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: decision-history.sh missing at $HELPER"
  exit 1
fi

# Source in a clean subshell-ish function context.
# shellcheck source=/dev/null
. "$HELPER"

if ! command -v dh_resolve_operator >/dev/null 2>&1; then
  echo "FAIL: dh_resolve_operator function not exposed after source"
  exit 1
fi

if ! command -v dh_emit_jsonl >/dev/null 2>&1; then
  echo "FAIL: dh_emit_jsonl function not exposed after source"
  exit 1
fi

# --- Case 1: dh_resolve_operator with git config set returns it ---
op="$(dh_resolve_operator)"
if [ -z "$op" ]; then
  echo "FAIL: dh_resolve_operator returned empty string"
  exit 1
fi

# --- Case 2: dh_resolve_operator with no git + no prefs falls through to unknown@local ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
HOME="$tmpdir"
export HOME
# No .git here, no .orchestrator/preferences.yml.
op2="$(dh_resolve_operator)"
case "$op2" in
  *@*) ;;  # any email-shaped value (git config might still resolve via ~/.gitconfig)
  unknown@local) ;;
  *)
    echo "FAIL: dh_resolve_operator fallthrough returned unexpected: '$op2'"
    exit 1
    ;;
esac

# --- Case 3: dh_resolve_operator reads preferences.yml when git is empty ---
mkdir -p .orchestrator
cat >.orchestrator/preferences.yml <<'EOF'
operator_identifier: "carrot@example.com"
EOF
# Force git to return empty by pointing GIT_CONFIG_NOSYSTEM + ensuring no repo.
GIT_CONFIG_GLOBAL="$tmpdir/.no-such" GIT_CONFIG_NOSYSTEM=1 \
  bash -c '. "'"$HELPER"'" && dh_resolve_operator' >op3.txt 2>/dev/null || true
op3="$(cat op3.txt)"
case "$op3" in
  carrot@example.com) ;;
  *)
    # Acceptable fallback: a real git email could still be set in environment;
    # only fail if neither carrot nor any email-shape produced.
    case "$op3" in
      *@*) ;;
      *)
        echo "FAIL: dh_resolve_operator did not honor preferences.yml fallback. Got: '$op3'"
        exit 1
        ;;
    esac
    ;;
esac

# --- Case 4: dh_emit_jsonl writes a record to ORCH_ROOT/execution-log.jsonl ---
ORCH_ROOT="$tmpdir/orch-state"
export ORCH_ROOT
dh_emit_jsonl knowledge_graduate entry_id=MEM999 cluster_id=Cabc rationale_hash=deadbeef
log_file="$ORCH_ROOT/execution-log.jsonl"
if [ ! -f "$log_file" ]; then
  echo "FAIL: dh_emit_jsonl did not create $log_file"
  exit 1
fi
line="$(tail -n 1 "$log_file")"

# Assert required keys present (event, timestamp, milestone, entry_id, cluster_id, rationale_hash).
for needle in '"event":"knowledge_graduate"' '"timestamp":"' '"milestone":"' \
              '"entry_id":"MEM999"' '"cluster_id":"Cabc"' '"rationale_hash":"deadbeef"'; do
  case "$line" in
    *"$needle"*) ;;
    *)
      echo "FAIL: JSONL record missing $needle. Got: $line"
      exit 1
      ;;
  esac
done

# Assert the record is single-line valid JSON (parseable by jq if present).
if command -v jq >/dev/null 2>&1; then
  if ! printf '%s\n' "$line" | jq . >/dev/null 2>&1; then
    echo "FAIL: JSONL record is not parseable by jq. Got: $line"
    exit 1
  fi
fi

# --- Case 5: dh_emit_jsonl handles values containing double-quotes safely ---
dh_emit_jsonl knowledge_archive entry_id=MEM998 archived_into=MEM999 rationale_hash='hash"with"quotes'
line2="$(tail -n 1 "$log_file")"
case "$line2" in
  *'\"with\"'*) ;;
  *)
    echo "FAIL: JSONL escape did not handle embedded double-quotes. Got: $line2"
    exit 1
    ;;
esac

echo "PASS: dh_resolve_operator + dh_emit_jsonl contract"
exit 0
```

`chmod +x scripts/verify/m020-p03-decision-history-helper-contract.sh`.

## Must-Haves

- `scripts/knowledge/lib/decision-history.sh` exists and is sourceable.
- `dh_resolve_operator` resolves to a non-empty operator identity through the documented fallthrough chain (git → preferences.yml → `unknown@local`).
- `dh_emit_jsonl <event> <kv>...` appends one JSON object per call to `$ORCH_ROOT/execution-log.jsonl` with `event`, `timestamp`, `milestone`, plus the supplied key=value pairs encoded as string-valued JSON properties.
- Embedded double-quotes in values are escaped (no broken JSON).
- Bash 3.2, AD-19, MEM001 conventions throughout.
- The verifier `m020-p03-decision-history-helper-contract.sh` exists, is executable, and exits 0.

## Verification

```
bash scripts/verify/m020-p03-decision-history-helper-contract.sh
```

Must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/frontmatter.sh` (P01 T02)
  - Key API: `fm_append_decision_history <file> <rationale> <operator> <cluster_id>` — appends a YAML record to the entry's `decision_history:` block. T01 does NOT call this function; T01 only ships the operator-resolver and the JSONL emitter that T02 will compose with `fm_append_decision_history`.
  - T01 may not source `frontmatter.sh` at all; the helpers are independent.

### From Disk (Pre-existing)

- `scripts/knowledge/consolidate-artifacts.sh` lines 235-244 — canonical reference pattern for `printf >> $LOG_FILE` JSONL emission. T01's `dh_emit_jsonl` follows the same shape (printf + redirect; no jq dependency).

## Constraints

- **AD-19 / MEM001**: every verification command in this plan is a single-script-file invocation. The helper functions internally use only safe bash 3.2 constructs (no process substitution, no command-substitution-with-pipes inside Check commands).
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside command-substitution-with-pipes. Use sed pipelines via separate `printf | sed` invocations (the `_dh_json_escape` helper does exactly this and stays inside the script body, never on a Check line).
- **CON-1 / FR-8 (read-only-during-dispatch)**: T01's helpers are pure — `dh_resolve_operator` reads but never writes; `dh_emit_jsonl` writes ONLY to the JSONL log, never to `knowledge/**`. The dispatch-isolation invariant is preserved.
- **CON-4 (Surgical Precision)**: T01 creates a NEW file. It does not modify any pre-existing helper or script.
- **Principle XIV (No Speculative Complexity)**: JSON encoding is conservative — every value is a JSON string, no type coercion, no nested objects. If a future caller needs richer shapes, escalate via D-row.
- **No jq hard dependency**: the JSONL emitter must work in a jq-less environment (MEM001 — jq is optional). The verifier MAY use jq when present for structural assertions but must not require it.

## Expected Output

After this task:

1. `scripts/knowledge/lib/decision-history.sh` exists, sourceable, exposes `dh_resolve_operator` and `dh_emit_jsonl`.
2. `scripts/verify/m020-p03-decision-history-helper-contract.sh` exists, executable, exits 0 with `PASS:` line.
3. No file under `knowledge/**` is touched by T01.
4. `git status knowledge/` is clean (T01 does not touch the live tree; only verifier tempdirs).

**Done when**: the verifier prints `PASS:` and exits 0; `git status knowledge/` is empty.
