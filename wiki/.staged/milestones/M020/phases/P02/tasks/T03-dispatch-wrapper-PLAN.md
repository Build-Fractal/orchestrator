---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M020"
name: "Dispatch-interface query passthrough wrapper (OQ-4)"
depends_on: ["T02"]
---

## Prerequisites

- T01 + T02: `scripts/knowledge/query.sh` is contract-stable: `--topic <X> [--state <S>] [--format ids|json]`, default state filter `graduated`, default format `ids`, side-effect-free, JSON document parseable, no-match diagnostic emitted.
- Pre-existing on disk: `scripts/dispatch/dispatch-interface.sh` (331 lines). Header (lines 1–43) sources `scripts/lib/pricing.sh` and declares `SCRIPT_DIR`, `REGISTRY`, `ADAPTERS_DIR`, `_DI_PROJECT_ROOT`. Main argument parsing block runs lines 45–64; the rest of the file (66–331) handles backend resolution, adapter dispatch, error emission, and JSONL usage logging.

## Description

Add a `--query` subcommand passthrough to `scripts/dispatch/dispatch-interface.sh`. The wrapper is the OQ-4 closure: callers invoke `bash scripts/dispatch/dispatch-interface.sh --query --topic <X> [--state <S>] [--format ids|json]` and the dispatch layer delegates to `scripts/knowledge/query.sh` with byte-equivalent stdout. This keeps the [M024](../../../../../milestones/M024/index.md) universal-intake router (downstream) decoupled from the knowledge subdirectory layout — it talks to one dispatch entry-point.

CON-4 mandate: dispatch-interface.sh's existing surface — `--task-plan`, `--payload`, `--intensity-metadata`, `--backend` — MUST remain byte-equivalent. The `--query` branch is a pre-flight early-exit hooked BEFORE the existing argument parsing loop. If `--query` is the FIRST argument, the script forwards every remaining argument to `query.sh` via `exec` and never reaches the backend resolution path.

Scope:
- Insert a 6-line `--query` early-exit block immediately after the `BACKEND=""` initializer and before the existing `while [[ $# -gt 0 ]]` loop.
- Resolve the query script path from `SCRIPT_DIR` (already declared on line 31): `$SCRIPT_DIR/../knowledge/query.sh`.
- `exec bash "$query_script" "$@"` — preserves exit code, stdout, stderr; eliminates the dispatch-interface's pricing/JSONL emitter side-effects (which are inappropriate for a side-effect-free read-only query).
- Ship `scripts/verify/m020-p02-dispatch-query-wrapper.sh` enforcing byte-equivalent stdout against direct `query.sh` invocation.

Out of scope:
- Cross-cutting integration test (T04).
- Restructuring dispatch-interface.sh's pricing or JSONL emitter (orthogonal to FR-2).
- Adding non-query subcommands.

## Steps

### Step 1: Locate the insertion point in `scripts/dispatch/dispatch-interface.sh`

Open `/Users/brettkellgren/Sites/orchestrator/scripts/dispatch/dispatch-interface.sh` and find the block at lines 45–50 (line numbers approximate; match by content):

```bash
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
BACKEND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
```

### Step 2: Insert the `--query` early-exit block

Insert immediately after `BACKEND=""` and before `# Parse arguments`:

```bash
# --- M020/P02/T03: --query subcommand passthrough (OQ-4) ---------------------
# When the FIRST argument is --query, delegate to scripts/knowledge/query.sh
# and exec out, preserving exit code + stdout + stderr byte-equivalent. Never
# reaches backend resolution or the dispatch_usage JSONL emitter — query is
# a side-effect-free knowledge-layer read (FR-8 / CON-1 / SC-7).
if [ "${1:-}" = "--query" ]; then
  shift
  query_script="$SCRIPT_DIR/../knowledge/query.sh"
  if [ ! -x "$query_script" ]; then
    echo "FAIL: query.sh missing or not executable at $query_script" >&2
    exit 1
  fi
  exec bash "$query_script" "$@"
fi
# -----------------------------------------------------------------------------
```

The block:
- Uses `[ "${1:-}" = "--query" ]` (POSIX, bash 3.2-safe) instead of `[[ ]]` to keep the early-exit shape minimal and identical to other `[ ]` guards in the file.
- Calls `shift` to drop the `--query` token before the exec — `query.sh` does not recognize `--query` as a flag.
- Pre-flight checks the script's existence and executable bit; otherwise the `exec` failure mode is opaque.
- Uses `exec bash "$query_script" "$@"` (NOT `exec "$query_script"`) so the script's shebang is honored uniformly across runtimes (matches the verifier scripts' invocation pattern).

### Step 3: Create `scripts/verify/m020-p02-dispatch-query-wrapper.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p02-dispatch-query-wrapper.sh`

```bash
#!/usr/bin/env bash
# m020-p02-dispatch-query-wrapper.sh — assert dispatch-interface.sh --query
# delegates to query.sh with byte-equivalent stdout (OQ-4).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DISPATCH="$ROOT/scripts/dispatch/dispatch-interface.sh"
QUERY="$ROOT/scripts/knowledge/query.sh"

if [ ! -x "$DISPATCH" ]; then
  echo "FAIL: dispatch-interface.sh missing or not executable at $DISPATCH"
  exit 1
fi
if [ ! -x "$QUERY" ]; then
  echo "FAIL: query.sh missing or not executable at $QUERY"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM770.md" <<'EOF'
---
id: MEM770
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM770: passthrough fixture
EOF

cat >"$tmpdir/knowledge/patterns/MEM771.md" <<'EOF'
---
id: MEM771
topic: ""
tags: [auth]
last_verified: 2026-04-20
status: graduated
---

# MEM771: tag passthrough fixture
EOF

export PROJECT_ROOT="$tmpdir"

# 1. Direct query.sh invocation.
direct_ids="$(bash "$QUERY" --topic auth 2>/dev/null)"

# 2. Through the dispatch wrapper.
wrapped_ids="$(bash "$DISPATCH" --query --topic auth 2>/dev/null)"

if [ "$direct_ids" != "$wrapped_ids" ]; then
  echo "FAIL: ids stdout differs between direct and dispatch-wrapped invocation"
  echo "Direct:"
  echo "$direct_ids"
  echo "Wrapped:"
  echo "$wrapped_ids"
  exit 1
fi

# 3. Same with --format json.
direct_json="$(bash "$QUERY" --topic auth --format json 2>/dev/null)"
wrapped_json="$(bash "$DISPATCH" --query --topic auth --format json 2>/dev/null)"

if [ "$direct_json" != "$wrapped_json" ]; then
  echo "FAIL: json stdout differs between direct and dispatch-wrapped invocation"
  echo "Direct: $direct_json"
  echo "Wrapped: $wrapped_json"
  exit 1
fi

# 4. Exit code propagation: invalid --state should exit non-zero through both.
direct_rc=0
bash "$QUERY" --topic auth --state bogus >/dev/null 2>&1 || direct_rc=$?

wrapped_rc=0
bash "$DISPATCH" --query --topic auth --state bogus >/dev/null 2>&1 || wrapped_rc=$?

if [ "$direct_rc" -eq 0 ] || [ "$wrapped_rc" -eq 0 ]; then
  echo "FAIL: invalid --state should exit non-zero. direct=$direct_rc wrapped=$wrapped_rc"
  exit 1
fi
if [ "$direct_rc" != "$wrapped_rc" ]; then
  echo "FAIL: exit codes differ. direct=$direct_rc wrapped=$wrapped_rc"
  exit 1
fi

# 5. Wrapper does NOT alter knowledge/ tree.
post="$tmpdir/post-files.txt"
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$post"
if ! grep -q "MEM770" "$post"; then
  echo "FAIL: knowledge tree perturbed by dispatch wrapper"
  exit 1
fi

echo "PASS: dispatch-interface --query passthrough is byte-equivalent to direct query.sh"
exit 0
```

`chmod +x` the script.

### Step 4: Smoke-check that dispatch-interface.sh's existing surface is intact

The contract guard for non-query invocations is the existing test suite (`tests/test-dispatch-branch-discipline.sh`, `tests/integration/`). T03 does NOT add a separate verifier for the existing surface — the inserted block is unreachable when `$1 != "--query"`, so the existing parsing path is byte-equivalent by construction. CON-4 surface preservation is reasoned at the patch level, not asserted as a Tier-1 verifier here. T04 will exercise the wrapper end-to-end through the integration test.

## Must-Haves

- `scripts/dispatch/dispatch-interface.sh` recognises `--query` as the FIRST argument and `exec`s `scripts/knowledge/query.sh` with the remaining arguments forwarded.
- The early-exit block is unreachable for non-query invocations (`$1 != "--query"`) — preserves all existing dispatch surface byte-equivalent (CON-4).
- Stdout, stderr, and exit code are byte-equivalent between direct `query.sh` invocation and `dispatch-interface.sh --query` invocation.
- The wrapper does NOT trigger pricing-lib JSONL emission (FR-8 / CON-1: query is read-only and observability-clean).
- `scripts/verify/m020-p02-dispatch-query-wrapper.sh` exists, is executable, and exits 0.

## Verification

```
bash scripts/verify/m020-p02-dispatch-query-wrapper.sh
```

Must print `PASS:` and exit 0. Cross-task invariants (T01 + T02 verifiers continuing to pass) are validated at phase-completion time per the phase plan's `## Verification Commands`, not here.

## Inputs

### From Previous Tasks

- `scripts/knowledge/query.sh` (T01 + T02)
  - Key API: `bash query.sh --topic <X> [--state <S>] [--format ids|json]`. T03 forwards arguments verbatim and never inspects them.
  - Stable contract: exit codes, stdout, and stderr are pass-through.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` (331 lines)
  - Key landmarks T03 relies on:
    - Line 31 (approx.): `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` — used to locate `query.sh` at `$SCRIPT_DIR/../knowledge/query.sh`.
    - Lines 45–48: variable initializers (`TASK_PLAN`, `PAYLOAD`, `INTENSITY_METADATA`, `BACKEND`) — insertion point is immediately AFTER `BACKEND=""`.
    - Lines 50–64: existing argument parsing loop — must be reachable for non-query invocations (the `if … --query` block above only fires when `$1 == "--query"`, so the loop is preserved byte-equivalent).
- `scripts/lib/pricing.sh` — sourced unconditionally at lines 38–43; T03 must NOT remove this. The exec-out from the `--query` branch happens AFTER the source (which is harmless: pricing.sh is idempotent and side-effect-free at source time per its sourced-guard pattern).

## Constraints

- **AD-19 / MEM001**: Check + verification commands are single-script-file shape. The dispatch-interface.sh body uses `[[ ]]` and pipes internally; T03's inserted block uses POSIX `[ ]` for compactness and self-evident bash 3.2 safety.
- **CON-4 (Surgical Precision)**: T03 modifies dispatch-interface.sh by inserting a single self-contained block ≤12 lines. No existing line is removed; no existing line is rewritten beyond the FR-2 reference comment at the block boundary.
- **Bash 3.2**: the inserted block uses `${1:-}`, `[ … = … ]`, `shift`, and `exec` — all bash 3.2 native. No `[[ ]]` regex, no `<<<` here-strings.
- **FR-8 / CON-1 (read-only-during-dispatch)**: the wrapper exec-outs to `query.sh` BEFORE entering the dispatch-usage JSONL emitter. The query path emits no JSONL records.
- **Principle XV (Surgical Precision)**: dispatch-interface.sh's existing 13 surface flags + 4 backend-resolution paths are byte-equivalent post-T03. The `--query` branch is unreachable when `$1 != "--query"`.
- **CON-2 (context budget)**: by exec-ing out, T03 inherits query.sh's metadata-only output. Bodies are never streamed.

## Expected Output

After this task:

1. `scripts/dispatch/dispatch-interface.sh` is now ~343 lines (T03 adds ~12). The new block sits between line 48 (`BACKEND=""`) and the `# Parse arguments` comment.
2. `scripts/verify/m020-p02-dispatch-query-wrapper.sh` exists, is executable, and exits 0 with `PASS: dispatch-interface --query passthrough is byte-equivalent to direct query.sh`.
3. `git diff scripts/dispatch/dispatch-interface.sh` shows ONLY the inserted block — no other lines touched.
4. `git status knowledge/` is clean.

**Done when**: the wrapper verifier passes; no other line of dispatch-interface.sh is modified; all T01 + T02 verifiers still pass.
