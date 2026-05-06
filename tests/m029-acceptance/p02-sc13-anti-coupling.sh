#!/usr/bin/env bash
# tests/m029-acceptance/p02-sc13-anti-coupling.sh
#
# M029 P02 / SC-13 acceptance script.
#
# Asserts the no-GitHub-API anti-coupling invariant (FR-11 / CON-4):
# the M029 spec body does NOT issue any normative requirement for the
# render path to read `/integrations/github` AND the renderer body
# does NOT reference the `/integrations/github` path. v1 of
# `orchestrator:where` is wiki-is-the-view; GitHub fold-in is deferred
# to demand-driven post-launch `external-tool-adapters` work.
#
# Spec-scan scope carve-out (T04 fixture-author note):
#   The literal substring `/integrations/github` appears in
#   `specs/037-roadmap-visibility-cli-ux/spec.md` itself in three
#   contexts that are NOT couplings:
#     - FR-11 (line ~138) — documents that the M013 sidecar at
#       `.orchestrator/integrations/github.json` REMAINS readable by
#       `orchestrator:github-status` / `orchestrator:github-sync` and
#       is explicitly NOT read by the v1 `where` render path.
#     - SC-13 (line ~157) — DEFINES this very check, so naturally
#       quotes the literal string it greps for.
#     - Lines ~198 / ~247 — Reference / Dependency sections naming
#       the M013 sidecar negatively (i.e. as a path NOT consumed by
#       the v1 render).
#   These are documentation surfaces, not coupling. The SC-13 check's
#   load-bearing assertion is on the RENDERER body. The spec-side
#   scan therefore restricts itself to checking that the spec does
#   not contain any `read .*\.orchestrator/integrations/github` style
#   imperative (which would constitute an actual normative coupling).
#   The conversus/ subdirectory is review meta-discussion of the
#   spec — also excluded from the spec-coupling scan.
#
# Two greps rather than one wildcard: spec is a tree, renderer is a
# single file; combining would mask which surface had the leak. Per
# AD-19, exit codes are captured via straight `grep ...; rc=$?`
# rather than `if grep | grep`.
#
# Spec references: FR-11, CON-4, SC-13.
#
# Bash 3.2 compatible. AD-19: single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPEC_FILE="$PROJECT_ROOT/specs/037-roadmap-visibility-cli-ux/spec.md"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# Gate: spec.md exists.
if [ ! -f "$SPEC_FILE" ]; then
    bad "M029 spec.md missing at $SPEC_FILE"
    printf 'SUMMARY: p02-sc13-anti-coupling.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: renderer exists.
if [ ! -f "$RENDERER" ]; then
    bad "renderer missing at $RENDERER"
    printf 'SUMMARY: p02-sc13-anti-coupling.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Spec-side anti-coupling: scan the spec body for any imperative read
# of the GitHub sidecar from the render path. The pattern targets the
# normative coupling shape `read .* /integrations/github` rather than
# any literal string mention (which is documented as expected above).
set +e
grep -E -- 'read[s]?[[:space:]]+[^[:space:]]*/integrations/github' "$SPEC_FILE" >/dev/null 2>&1
spec_imperative_rc=$?
set -e

if [ "$spec_imperative_rc" -ne 0 ]; then
    ok "SC-13 spec anti-coupling (no normative read-imperative against /integrations/github in spec.md)"
else
    bad "SC-13 spec anti-coupling violated -- spec.md contains a read-imperative for /integrations/github"
    grep -nE -- 'read[s]?[[:space:]]+[^[:space:]]*/integrations/github' "$SPEC_FILE" >&2 || true
fi

# Renderer-side anti-coupling: literal substring scan -- the load-
# bearing assertion. The renderer body MUST contain no `/integrations/github`
# reference at all (no read, no path construction, no comment).
set +e
grep -F -- '/integrations/github' "$RENDERER" >/dev/null 2>&1
renderer_rc=$?
set -e

if [ "$renderer_rc" -ne 0 ]; then
    ok "SC-13 renderer anti-coupling (no /integrations/github literal in render-position.sh)"
else
    bad "SC-13 renderer anti-coupling violated -- /integrations/github found in render-position.sh"
    grep -nF -- '/integrations/github' "$RENDERER" >&2 || true
fi

printf 'SUMMARY: p02-sc13-anti-coupling.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
