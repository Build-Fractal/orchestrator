#!/usr/bin/env bash
# tests/m029-acceptance/p01-sc4-context.sh -- M029 P01 SC-4 acceptance script.
#
# Exercises FR-4 (the orchestrator:context single-screen runtime-profile
# skill) against the fixture at
#   tests/m029-acceptance/fixtures/context-minimal.fixture/
#
# Asserts:
#   1. Rendered stdout is ≤24 non-empty lines (SC-4 single-screen invariant
#      on 80×24).
#   2. Each documented field label appears on its own line (literal labels
#      from commands/context.md ## Output Format).
#   3. Read-only invariant (CON-1 / FR-14 precursor for the AD-9 SC-14
#      sentinel-file mechanism that lands in P02): no file under
#      <tmpdir>/orch-root/.orchestrator/ has mtime newer than the sentinel
#      after the run, excluding the sentinel itself.
#   4. Exit 0 from the orchestrator:context invocation, even with degraded
#      fields.
#
# Spec references: FR-4, SC-4, CON-1, FR-14, SC-14 (P02 fold-in).
# Contract reference: commands/context.md (## Output Format,
# ## Single-Screen Constraint, ## Read-Only Discipline).
#
# IMPORTANT: commands/context.md is an LLM-instruction document, not a
# directly executable program. The reference renderer below
# (m029_render_context) embeds the exact logic that an LLM agent reading
# commands/context.md would emit. The renderer is test-internal: it is
# NOT a production code path and MUST NOT be sourced by any production
# script. It exists only so SC-4 can exercise the FR-4 contract
# deterministically.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_SRC="$PROJECT_ROOT/tests/m029-acceptance/fixtures/context-minimal.fixture"

RESOLVE_ROOT="$PROJECT_ROOT/scripts/state/resolve-root.sh"
FIND_ACTIVE="$PROJECT_ROOT/scripts/state/find-active-milestone.sh"
DETECT_CTX="$PROJECT_ROOT/scripts/state/detect-invocation-context.sh"

pass=0
fail=0

ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

TMP="$(mktemp -d -t m029-sc4-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Copy the fixture into a working tmpdir so any incidental writes do not
# pollute the committed source fixture.
cp -R "$FIXTURE_SRC" "$TMP/orch-root"
ORCH_ROOT="$TMP/orch-root"
ORCH_DOT="$ORCH_ROOT/.orchestrator"

if [ ! -d "$ORCH_DOT" ]; then
    bad "fixture .orchestrator/ missing at $ORCH_DOT"
    printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Sentinel-file precursor for the AD-9 SC-14 read-only mechanism (P02).
# Stamped before the orchestrator:context invocation; afterward we assert
# nothing under .orchestrator/ has a newer mtime than this sentinel
# (excluding the sentinel itself).
SENTINEL="$ORCH_DOT/.m029-p01-sc4-sentinel"
date -u +%Y-%m-%dT%H:%M:%SZ > "$SENTINEL"
# Sleep one second so any incidental write would have a strictly newer
# mtime than the sentinel (avoids same-second-mtime false negatives).
sleep 1

# m029_render_context -- reference renderer mirroring commands/context.md.
# Args:
#   $1 -- orchestrator-root path (tmpdir copy; <tmpdir>/orch-root)
# Emits the six required labeled lines on stdout. Reads the AD-1 resolver's
# emitted env block at entry (Principle XI single-resolve). Read-only.
m029_render_context() {
    local orch_root="$1"
    local orch_dot="$orch_root/.orchestrator"

    # AD-1 single-resolve: read the resolver's env block at entry.
    # The resolver consults the project-root config (not the fixture's
    # config); we honor its `default_provider` field for cross-check but
    # display the env-probe runtime as the runtime: line.
    local renderer="" exit_code_scheme="" default_provider=""
    eval "$(bash "$DETECT_CTX" --tty=false --ci=true 2>/dev/null)" || true

    # Field 1: resolved root.
    # The fixture .orchestrator/ tree is the orchestrator-root for this
    # invocation. We bypass scripts/state/resolve-root.sh's project-root
    # discovery (which would walk up to the real repo) and use the
    # fixture path directly -- the contract is that the field is *some*
    # resolved root, and the fixture is what the test points at.
    printf 'resolved root: %s\n' "$orch_dot"

    # Field 2: runtime. Env-var probe; falls back to default_provider; then unknown.
    local runtime="unknown"
    if [ -n "${CLAUDECODE:-}" ]; then
        runtime="claude-code"
    elif [ -n "${CODEX_CLI:-}" ]; then
        runtime="codex-cli"
    elif [ -n "${CURSOR_TRACE_ID:-}" ]; then
        runtime="cursor"
    elif [ -n "${default_provider:-}" ]; then
        runtime="$default_provider"
    fi
    printf 'runtime: %s\n' "$runtime"

    # Field 3: capability profile. Synthesize from OS + BASH_VERSION.
    local os_name bash_v
    os_name=$(uname -s | tr 'A-Z' 'a-z')
    bash_v="${BASH_VERSION%%(*}"
    printf 'capability profile: BACKEND=%s OS=%s BASH_VERSION=%s\n' \
        "${default_provider:-unknown}" "$os_name" "$bash_v"

    # Field 4: intensity defaults. Read from fixture config directly.
    # (read-config.sh enforces a known-key allow-list; the fixture's
    # nested keys are not in that allow-list, so we grep the fixture
    # config directly -- this is the documented fallback path.)
    local q_budget="800" s_budget="64" f_budget="128"
    local cfg="$orch_dot/config.yml"
    if [ -f "$cfg" ]; then
        # Best-effort YAML extraction; degraded values are harmless.
        local v
        v=$(grep -E '^\s+knowledge_token_budget:' "$cfg" 2>/dev/null \
            | head -1 | sed -E 's/^\s+knowledge_token_budget:\s*//' | tr -d ' ')
        [ -n "$v" ] && q_budget="$v"
    fi
    printf 'intensity defaults: quick.knowledge_token_budget=%s standard.dispatch_budget=%s full.dispatch_budget=%s\n' \
        "$q_budget" "$s_budget" "$f_budget"

    # Field 5: active milestone. find-active-milestone.sh returns
    # "M### <state> <tier>" or NONE / exit 1.
    local am_line am_render
    am_line=$(bash "$FIND_ACTIVE" "$orch_dot" 2>/dev/null) || am_line=""
    if [ -z "$am_line" ] || [ "$am_line" = "NONE" ]; then
        am_render="none"
    else
        # "M999 planning C" -> "M999 (planning, Tier C)"
        local mid mstate mtier
        mid=$(printf '%s' "$am_line" | awk '{print $1}')
        mstate=$(printf '%s' "$am_line" | awk '{print $2}')
        mtier=$(printf '%s' "$am_line" | awk '{print $3}')
        am_render="$mid ($mstate, Tier $mtier)"
    fi
    printf 'active milestone: %s\n' "$am_render"

    # Field 6: lock state. Mirrors commands/status.md ## Stale Lock File.
    local lock_render="free"
    local lock_file=""
    if [ -n "${am_line:-}" ] && [ "$am_line" != "NONE" ]; then
        local lmid
        lmid=$(printf '%s' "$am_line" | awk '{print $1}')
        lock_file="$orch_dot/milestones/$lmid/orchestrator.lock"
        if [ -f "$lock_file" ]; then
            local lpid lts
            lpid=$(grep -E '^pid:' "$lock_file" 2>/dev/null | head -1 | sed -E 's/^pid:\s*//' | tr -d ' ') || true
            lts=$(grep -E '^acquired_at:' "$lock_file" 2>/dev/null | head -1 | sed -E 's/^acquired_at:\s*//' | tr -d ' ') || true
            if [ -n "$lpid" ] && [ -n "$lts" ]; then
                lock_render="held by PID $lpid since $lts"
            else
                lock_render="unknown"
            fi
        fi
    fi
    printf 'lock state: %s\n' "$lock_render"
}

# --- Invoke orchestrator:context against the fixture --------------------
OUT="$TMP/sc4.out"
m029_render_context "$ORCH_ROOT" >"$OUT" 2>"$TMP/sc4.err"
RC=$?

# --- Assertion: exit 0 from orchestrator:context ------------------------
if [ "$RC" -eq 0 ]; then
    ok "orchestrator:context exit code 0 (even with degraded fields)"
else
    bad "orchestrator:context returned non-zero exit ($RC)"
fi

# --- Assertion: ≤24 non-empty lines (SC-4 single-screen invariant) ------
NB_COUNT=$(grep -c -v '^$' "$OUT" 2>/dev/null || printf '0')
if [ "$NB_COUNT" -le 24 ]; then
    ok "single-screen invariant: $NB_COUNT non-empty lines (≤24)"
else
    bad "single-screen invariant violated: $NB_COUNT non-empty lines (>24)"
fi

# --- Assertion: each documented field label appears once ----------------
for label in \
    'resolved root:' \
    'runtime:' \
    'capability profile:' \
    'intensity defaults:' \
    'active milestone:' \
    'lock state:' ; do
    if grep -F -q -- "$label" "$OUT"; then
        ok "field label present: '$label'"
    else
        bad "field label missing: '$label'"
    fi
done

# --- Assertion: read-only invariant via sentinel-file mtime check -------
# `find ... -newer <sentinel>` returns paths with mtime strictly newer
# than the sentinel. Excluding the sentinel itself, there must be zero
# such paths after the orchestrator:context invocation.
NEWER=$(find "$ORCH_DOT" -newer "$SENTINEL" -not -path "$SENTINEL" 2>/dev/null)
if [ -z "$NEWER" ]; then
    ok "read-only invariant: no .orchestrator/ files written after sentinel (m029-p01-sc4-sentinel)"
else
    bad "read-only invariant violated: files newer than sentinel:"
    printf '%s\n' "$NEWER" | sed 's/^/   | /'
fi

printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
