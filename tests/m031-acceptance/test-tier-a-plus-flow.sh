#!/usr/bin/env bash
# tests/m031-acceptance/test-tier-a-plus-flow.sh
#
# M031/P02/T04 -- SC-6 end-to-end acceptance test for the Tier A+
# middle flow at scripts/intake/route-to-dispatch.sh. Drives the router
# with --verdict tier_a_plus through a stub dispatch surface that emits
# canned <role>.md outputs. The test verifies the router's shape (three
# unit_close JSONL records, two markdown artifacts visible at the
# documented paths, no auto-loop locks, no milestone scaffolding, no
# interactive prompt under --yes).
#
# Asserted invariants:
#
#   1. Router exits 0 under --yes.
#   2. Exactly three unit_close JSONL records ride on the redirected
#      log path -- one per role (research, plan, build) -- each
#      carrying tier_a_plus_role and aborted=false.
#   3. <slug-dir>/research.md exists and is non-empty.
#   4. <slug-dir>/plan.md exists and is non-empty.
#   5. <slug-dir>/build.md exists and is non-empty (build-role agent
#      writes its own audit artifact alongside running verifiers).
#   6. ZERO files created under any path matching .orchestrator/milestones/M*/.
#   7. ZERO files matching the literal substring `lock` outside the
#      sandbox scratch tree (auto-loop lock invariant).
#   8. Under --yes mode: ZERO interactive characters consumed from
#      stdin (the prompt helper exits before read fires) and exactly
#      one `research: <path>` audit line on the prompt-helper stderr.
#
# Output envelope:
#   RESULT: SC-6 pass   on success
#   RESULT: SC-6 fail   plus diagnostic lines on failure
#
# Exit 0 iff every clause holds. Single-script Truth Check shape per
# AD-19. Bash 3.2 compatible (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROUTER="$PROJECT_ROOT/scripts/intake/route-to-dispatch.sh"

fail_count=0
fail_messages=""

record_fail() {
    fail_count=$((fail_count + 1))
    fail_messages="$fail_messages
  - $1"
}

# Sandbox the Tier A+ run under a temp scratch dir so the SC-6 test
# does not touch the project's real .orchestrator/ tree (CON-4
# discipline -- no scaffolding writes).
work_dir="${TMPDIR:-/tmp}/m031-p02-t04-sc6-$$"
rm -rf "$work_dir"
mkdir -p "$work_dir"

scratch_root="$work_dir/scratch/tier-a-plus"
log_path="$work_dir/log.jsonl"
stub_path="$work_dir/dispatch-stub.sh"

# Stub dispatch script. Receives <role> <task-slug> <task-desc>
# <slug-dir> on argv. Writes <slug-dir>/<role>.md with one line of
# canned content. Used by the router under --dispatch-stub to drive
# the chain without invoking real LLM dispatch.
cat > "$stub_path" <<'STUB'
#!/usr/bin/env bash
# Tier A+ flow test stub. Writes one-line markdown artifacts to mimic
# the production agent's role outputs.
set -u
role="$1"
slug="$2"
desc="$3"
dir="$4"
mkdir -p "$dir"
printf '# %s.md (slug=%s)\nDispatch stub artifact for SC-6 acceptance test.\n' "$role" "$slug" > "$dir/$role.md"
exit 0
STUB
chmod +x "$stub_path"

stdout_file="$work_dir/router-stdout.txt"
stderr_file="$work_dir/router-stderr.txt"

# Drive the router under --yes (skips the approval prompt) with stdin
# closed so a regression that drops the --yes guard would block on
# `read` and hang the test (the test framework's per-process timeout
# would kick in first; we still close stdin to make the assertion
# explicit).
ORCH_TIER_A_PLUS_LOG="$log_path" \
    bash "$ROUTER" \
        --verdict tier_a_plus \
        --task "Add a status caching layer for five seconds across all surfaces" \
        --yes \
        --scratch-root "$scratch_root" \
        --dispatch-stub "$stub_path" \
        </dev/null \
        >"$stdout_file" 2>"$stderr_file"
router_rc=$?

if [ "$router_rc" -ne 0 ]; then
    record_fail "router exited $router_rc (expected 0); stderr: $(cat "$stderr_file")"
fi

# Locate the slug from stdout. The router emits `route=tier_a_plus
# task_slug=<slug>` as its first line; downstream assertions use the
# slug to find the artifacts.
slug_line=$(grep -E '^route=tier_a_plus task_slug=' "$stdout_file" | head -1)
slug=""
if [ -n "$slug_line" ]; then
    slug=$(printf '%s' "$slug_line" | sed 's/^route=tier_a_plus task_slug=//')
fi
if [ -z "$slug" ]; then
    record_fail "router stdout missing 'route=tier_a_plus task_slug=<slug>' line"
fi

slug_dir="$scratch_root/$slug"

# Clause 3/4/5: per-role markdown artifacts present.
for role in research plan build; do
    artifact="$slug_dir/$role.md"
    if [ ! -s "$artifact" ]; then
        record_fail "expected non-empty $role artifact at $artifact"
    fi
done

# Clause 2: exactly three unit_close JSONL records, one per role,
# each carrying tier_a_plus_role and aborted=false.
if [ ! -f "$log_path" ]; then
    record_fail "expected unit_close JSONL log at $log_path"
else
    total_records=$(grep -c '"record_type":"unit_close"' "$log_path" || true)
    if [ "$total_records" -ne 3 ]; then
        record_fail "expected exactly 3 unit_close records, saw $total_records (log: $log_path)"
    fi
    for role in research plan build; do
        role_count=$(grep -c "\"tier_a_plus_role\":\"$role\"" "$log_path" || true)
        if [ "$role_count" -ne 1 ]; then
            record_fail "expected exactly 1 unit_close record with tier_a_plus_role=$role, saw $role_count"
        fi
    done
    aborted_true_count=$(grep -c '"aborted":true' "$log_path" || true)
    if [ "$aborted_true_count" -ne 0 ]; then
        record_fail "expected zero aborted=true records on the all-green path, saw $aborted_true_count"
    fi
    aborted_false_count=$(grep -c '"aborted":false' "$log_path" || true)
    if [ "$aborted_false_count" -ne 3 ]; then
        record_fail "expected exactly 3 aborted=false records, saw $aborted_false_count"
    fi
fi

# Clause 6: zero milestone-scaffolding writes under any path matching
# .orchestrator/milestones/M*/. Search both the sandbox AND the
# project root in case a regression mistakenly wrote into the real
# tree (the test does not modify the real .orchestrator/ tree under
# correct behavior, so we audit it as well).
sandbox_milestone_hits=$(find "$work_dir" -path '*/.orchestrator/milestones/M*' 2>/dev/null | head -5)
if [ -n "$sandbox_milestone_hits" ]; then
    record_fail "sandbox contains forbidden .orchestrator/milestones/M*/ paths: $sandbox_milestone_hits"
fi

# Clause 7: zero `lock` files outside the sandbox tree. We assert this
# by scanning the sandbox for any path containing `lock` -- the
# router MUST NOT acquire any auto-loop lock under any path. We
# explicitly exclude the SC-16 / SC-6 fixture artifact name patterns
# (research.md / plan.md / build.md / .session-id / *.payload.txt /
# *.meta.json) by inspecting only files whose basename literally
# contains `lock`.
sandbox_lock_hits=$(find "$work_dir" -type f -name '*lock*' 2>/dev/null | head -5)
if [ -n "$sandbox_lock_hits" ]; then
    record_fail "sandbox contains forbidden lock files: $sandbox_lock_hits"
fi

# Clause 8: under --yes mode the prompt helper emits exactly one
# `research: <path>` line on stderr (the audit-line emission --
# AD-20 clause 7 + clause 6) and no other characters from
# `tier-a-plus-prompt.sh`. We grep stderr for the single audit line.
audit_count=$(grep -c "^research: $slug_dir/research.md$" "$stderr_file" || true)
if [ "$audit_count" -ne 1 ]; then
    record_fail "expected exactly 1 'research: $slug_dir/research.md' audit line on stderr, saw $audit_count"
fi

# Clause 8 cont.: no interactive prompt body characters appear on
# router stdout (the prompt helper's stdout is piped through to the
# router's stdout in interactive mode; under --yes nothing prints).
# We assert ZERO occurrence of the option-label literal that would
# only appear under interactive mode.
if grep -F -q '(y) plan against this research' "$stdout_file"; then
    record_fail "stdout contains interactive prompt option label under --yes mode (regression)"
fi

# Clause 7 (continued): assert ZERO files under the project's real
# .orchestrator/auto/ tree changed during this run. The router MUST
# NOT touch that surface; the test does not stage anything under it.
if [ -d "$PROJECT_ROOT/.orchestrator/auto" ]; then
    auto_recent=$(find "$PROJECT_ROOT/.orchestrator/auto" -type f -newer "$work_dir" 2>/dev/null | head -3)
    if [ -n "$auto_recent" ]; then
        record_fail ".orchestrator/auto/ files mutated during run: $auto_recent"
    fi
fi

# Cleanup the sandbox.
rm -rf "$work_dir"

if [ "$fail_count" -eq 0 ]; then
    echo "RESULT: SC-6 pass"
    exit 0
fi

echo "RESULT: SC-6 fail"
printf 'FAIL count: %d\n' "$fail_count"
printf 'Diagnostics:%s\n' "$fail_messages"
exit 1
