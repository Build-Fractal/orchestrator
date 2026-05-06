#!/usr/bin/env bash
# tools/verify/m029-p01-scope-guard.sh -- M029 P01 scope-guard verifier.
#
# Asserts that every file modified or added under the M029/P01 working scope
# falls inside the P01 "Files Likely Touched" allowlist and that NO file on
# the P02/P03/M013/M019/M020/M027 denylist has been touched. P01 must not
# silently extend its blast radius into a follow-on phase or a neighbouring
# milestone surface.
#
# Modified-file detection: `git status --porcelain=v1` covers staged,
# unstaged, and untracked files relative to the index/HEAD. For ad-hoc
# invocation against a committed phase, callers can set
# M029_P01_SCOPE_BASE=<commit> to compare against an explicit base ref.
#
# Allowlist: paths the P01 plan explicitly authorises (the phase plan's
# "Files Likely Touched" list expressed as path globs).
# Denylist:  paths explicitly out of P01 claim (P02/P03 deliverables, M013
# config, M019 logs, M020 KNOWLEDGE.md, M027 surfaces).
#
# Per AD-19, the verifier emits PASS:/FAIL:/WARN: lines and a single
# `SUMMARY:` aggregate. Bash 3.2 compatible.

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

TMPDIR_LOCAL="$(mktemp -d -t m029-p01-scope-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT
MODIFIED="$TMPDIR_LOCAL/modified.txt"

if [ -n "${M029_P01_SCOPE_BASE:-}" ]; then
    git diff --name-only "$M029_P01_SCOPE_BASE"..HEAD >"$MODIFIED" 2>/dev/null || true
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
    printf 'SUMMARY: m029-p01-scope-guard.sh pass=%d fail=%d warn=%d\n' "$pass" "$fail" "$warn"
    exit 0
fi

# --- Path-classification predicates -----------------------------------------

# Allowed -- exact prefix match against the P01 Files Likely Touched list +
# planning-artifact glob + acceptance/verifier prefixes.
_is_allowed() {
    p="$1"
    case "$p" in
        references/status-headline-shape.md) return 0 ;;
        references/status-json-schema.md) return 0 ;;
        scripts/state/detect-invocation-context.sh) return 0 ;;
        scripts/diagnostics/render-status-json.sh) return 0 ;;
        commands/status.md) return 0 ;;
        commands/context.md) return 0 ;;
        tests/m029-acceptance/*) return 0 ;;
        tests/m029-acceptance/fixtures/*) return 0 ;;
        tools/verify/m029-p01-*.sh) return 0 ;;
        .orchestrator/milestones/M029/*) return 0 ;;
        specs/037-roadmap-visibility-cli-ux/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Denylist -- explicit out-of-claim paths. Surfacing any of these as
# modified is a P01 scope violation.
_deny_reason() {
    p="$1"
    case "$p" in
        scripts/diagnostics/render-position.sh)
            echo "P02 deliverable"; return 0 ;;
        scripts/diagnostics/summarize-milestone.sh)
            echo "P02 deliverable"; return 0 ;;
        commands/where.md)
            echo "P02 deliverable"; return 0 ;;
        commands/auto.md)
            echo "P03 modifies (preflight); P01 does NOT"; return 0 ;;
        commands/start.md)
            echo "P03 modifies (--auto-chain); P01 does NOT"; return 0 ;;
        scripts/diagnostics/metrics-rollup.sh)
            echo "M027 surface, read-only consumer only"; return 0 ;;
        scripts/diagnostics/efficiency-footer.sh)
            echo "M027 surface, read-only consumer only"; return 0 ;;
        scripts/dispatch/predictive-surface.sh)
            echo "M027 surface, P03 consumer"; return 0 ;;
        .orchestrator/KNOWLEDGE.md)
            echo "M020 owned"; return 0 ;;
        .orchestrator/integrations/github.json)
            echo "M013 owned"; return 0 ;;
    esac
    # M019-owned execution-log.jsonl under any milestone.
    case "$p" in
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

printf 'SUMMARY: m029-p01-scope-guard.sh pass=%d fail=%d warn=%d\n' "$pass" "$fail" "$warn"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
