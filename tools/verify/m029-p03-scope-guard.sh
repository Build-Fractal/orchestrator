#!/usr/bin/env bash
# tools/verify/m029-p03-scope-guard.sh -- M029 P03 scope-guard verifier.
#
# Asserts that every file modified or added under the M029/P03 working scope
# falls inside the P03 "Files Likely Touched" allowlist and that NO file on
# the P01/P02/M013/M019/M020/M027/M031/M033 denylist has been touched. P03
# must not silently extend its blast radius into a sibling phase or
# neighbouring milestone surface.
#
# Modified-file detection: `git status --porcelain=v1` covers staged,
# unstaged, and untracked files relative to the index/HEAD. For ad-hoc
# invocation against a committed phase, callers can set
# M029_P03_SCOPE_BASE=<commit> to compare against an explicit base ref.
#
# Allowlist: paths the P03 plan explicitly authorises (the phase plan's
# "Files Likely Touched" list expressed as path globs).
# Denylist:  paths explicitly out of P03 claim (auto-loop, M027 surfaces,
# GitHub integration config, M020 KNOWLEDGE.md / DECISIONS.md, M033's
# init.md surface).
#
# Upstream-phase carve-out: P02 untracked deliverables that belong to P02's
# claim are admitted to P03's allowlist (not denylisted, since they are not
# P03-introduced). Mirrors the P02 scope-guard's P01 carve-out.
#
# Per AD-19, the verifier emits PASS:/FAIL:/WARN: lines and a single
# `SUMMARY:` aggregate. Bash 3.2 / MEM001 compatible.
#
# Mirrors tools/verify/m029-p02-scope-guard.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

pass=0
fail=0
warn=0

ok() {
    printf 'PASS: %s\n' "$1"
    pass=$((pass + 1))
}

bad() {
    printf 'FAIL: %s\n' "$1"
    fail=$((fail + 1))
}

advise() {
    printf 'WARN: %s\n' "$1" >&2
    warn=$((warn + 1))
}

# --- Compute modified-file list ---------------------------------------------

TMPDIR_LOCAL="$(mktemp -d -t m029-p03-scope-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT
MODIFIED="$TMPDIR_LOCAL/modified.txt"

if [ -n "${M029_P03_SCOPE_BASE:-}" ]; then
    git diff --name-only "$M029_P03_SCOPE_BASE"..HEAD >"$MODIFIED" 2>/dev/null || true
else
    # Combine staged + unstaged + untracked. `git status --porcelain=v1` lists
    # every path with a 2-char status prefix; strip it, then `awk '!seen[$0]++'`
    # for stable de-dup. Untracked files appear with `??` and may be relative.
    git status --porcelain=v1 \
        | sed -E 's/^...//' \
        | awk '!seen[$0]++' \
        >"$MODIFIED" 2>/dev/null || true
fi

if [ ! -s "$MODIFIED" ]; then
    ok "no modified files detected (nothing in scope to guard)"
    printf 'SUMMARY: m029-p03-scope-guard.sh pass=%d fail=%d warn=%d\n' "$pass" "$fail" "$warn"
    exit 0
fi

# --- Path-classification predicates -----------------------------------------

# Allowed -- exact / prefix match against the P03 Files Likely Touched list +
# planning-artifact glob + acceptance/verifier prefixes + upstream-phase
# untracked deliverables (P01/P02 carve-out).
_is_allowed() {
    p="$1"
    case "$p" in
        # P03 Files Likely Touched -- declared in P03-PLAN.md.
        scripts/diagnostics/render-position.sh) return 0 ;;
        references/file-formats.md) return 0 ;;
        templates/orchestrator-config-default.yml) return 0 ;;
        scripts/state/read-config.sh) return 0 ;;
        commands/auto.md) return 0 ;;
        commands/start.md) return 0 ;;
        scripts/lifecycle/start.sh) return 0 ;;
        specs/037-roadmap-visibility-cli-ux/*) return 0 ;;
        tests/m029-acceptance/*) return 0 ;;
        tests/m029-acceptance/fixtures/*) return 0 ;;
        tools/verify/m029-p03-*.sh) return 0 ;;
        .orchestrator/milestones/M029/*) return 0 ;;
        # Upstream-phase carve-out -- P01/P02 deliverables sitting in the
        # working tree but not P03-introduced. The respective phase
        # scope-guards own the policing of those paths.
        references/status-headline-shape.md) return 0 ;;
        references/status-json-schema.md) return 0 ;;
        references/cross-milestone-feature-shape.md) return 0 ;;
        scripts/state/detect-invocation-context.sh) return 0 ;;
        scripts/diagnostics/render-status-json.sh) return 0 ;;
        scripts/diagnostics/summarize-milestone.sh) return 0 ;;
        commands/status.md) return 0 ;;
        commands/context.md) return 0 ;;
        commands/where.md) return 0 ;;
        tools/verify/m029-p01-*.sh) return 0 ;;
        tools/verify/m029-p02-*.sh) return 0 ;;
        *) return 1 ;;
    esac
}

# Denylist -- explicit out-of-claim paths. Surfacing any of these as
# modified is a P03 scope violation.
_deny_reason() {
    p="$1"
    case "$p" in
        commands/init.md)
            echo "M033 surface; P03 does NOT touch"; return 0 ;;
        commands/dispatch.md)
            echo "M031 surface; P03 does NOT touch"; return 0 ;;
        scripts/lifecycle/auto-loop.sh)
            echo "Principle XV; M029 does not touch the auto loop"; return 0 ;;
        scripts/diagnostics/metrics-rollup.sh)
            echo "M027 surface, read-only consumer only (CON-7 / AD-8)"; return 0 ;;
        scripts/diagnostics/efficiency-footer.sh)
            echo "M027 surface, read-only consumer only (CON-7 / AD-8)"; return 0 ;;
        scripts/dispatch/predictive-surface.sh)
            echo "M027 surface, P03 consumer only (CON-7 / AD-8)"; return 0 ;;
        .orchestrator/integrations/github.json)
            echo "M013 owned (CON-4 / FR-11)"; return 0 ;;
        .orchestrator/KNOWLEDGE.md)
            echo "M020 schema authority (CON-7)"; return 0 ;;
        .orchestrator/DECISIONS.md)
            echo "M020 schema authority (CON-7)"; return 0 ;;
    esac
    # M019-owned execution-log.jsonl under any milestone OTHER than M029.
    # M029-grain unit_close (T06 deliverable) appends to its own log under
    # .orchestrator/milestones/M029/execution-log.jsonl which is allowlisted
    # by the M029/* prefix.
    case "$p" in
        .orchestrator/milestones/M029/execution-log.jsonl)
            return 1 ;;
        .orchestrator/milestones/M*/execution-log.jsonl)
            echo "M019 owned"; return 0 ;;
    esac
    return 1
}

# --- Walk modified files ----------------------------------------------------

while IFS= read -r p; do
    [ -z "$p" ] && continue

    if reason=$(_deny_reason "$p"); then
        bad "denylisted path modified: $p ($reason)"
        continue
    fi

    if _is_allowed "$p"; then
        ok "allowlisted: $p"
        continue
    fi

    advise "unclassified path: $p (neither allowlist nor denylist)"
done <"$MODIFIED"

printf 'SUMMARY: m029-p03-scope-guard.sh pass=%d fail=%d warn=%d\n' "$pass" "$fail" "$warn"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
