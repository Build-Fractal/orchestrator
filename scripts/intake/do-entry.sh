#!/usr/bin/env bash
# scripts/intake/do-entry.sh
# M046/P03/T02 -- DEPRECATION SHIM.
#
# `orchestrator:do` is deprecated. Its entire four-branch one-shot routing
# table was GENERALIZED into scripts/intake/auto-entry.sh (M046/P03/T01),
# which now backs the unified `orchestrator:auto <arg>` entry. This file is
# now a THIN forwarding shim: it emits exactly one deprecation-notice line to
# stderr, then forwards ALL SIX legacy `do` flags plus `--ambiguity-mode
# prompt` verbatim to auto-entry.sh, and exits with auto-entry.sh's exit code
# unchanged (FR-3).
#
# Why `--ambiguity-mode prompt`: it preserves `do`'s legacy interactive
# low-confidence behavior EXACTLY. A below-floor `do` caller still gets the
# Tier A vs Tier B interactive prompt (honoring --no-prompt-mode), NOT the
# auto-native AUTO:BLOCK_AMBIGUITY default. This is what keeps scripted `do`
# callers from silently changing behavior across the cutover (US2 / SC-2).
#
# SC-2 byte-parity: this shim produces BYTE-IDENTICAL artifacts to a direct
# `bash scripts/intake/auto-entry.sh --ambiguity-mode prompt "$@"` invocation.
# The only difference on the `do` path is the single stderr deprecation notice
# emitted by THIS script before the forward. No routing logic lives here.
#
# Removal runway (D021 / #Q-3): this shim ships as a deprecation shim in the
# M046 release and is retained through AT LEAST the next published minor
# release; removal is gated NO EARLIER than one published release after this
# deprecation ships. The concrete target-removal version is v0.12.0 (see
# commands/do.md). Removal is a separate future change, not part of M046.
#
# --yes boundary (D020 / FR-5): `--yes` keeps its NARROW meaning under the
# shim exactly as before -- it skips the single attended confirmation prompt.
# It does NOT grant any unattended/destructive authority. `--unattended`
# (shipped P04) is the sole gate for that envelope. The shim forwards --yes
# unchanged; no broadening occurs here.
#
# CLI surface (forwarded verbatim to auto-entry.sh):
#   --task <description>            the task description.
#   --yes                           skip the Tier A+ approval prompt.
#   --config <path>                 override active config.yml lookup.
#   --dispatch-stub <script>        stand in for the agent runtime.
#   --scratch-root <dir>            forwarded to route-to-dispatch.sh.
#   --no-prompt-mode <A|B|C>        bypass the interactive low-conf `read`.
#
# Env-var overrides:
#   ORCH_DO_ENTRY_LOG               override the JSONL unit_close record path.
#                                   Passed through the environment to
#                                   auto-entry.sh's low-conf branch unchanged
#                                   (no shim action needed -- it is inherited).
#
# Invariants:
#   - Bash 3.2 compatible (MEM001): no associative arrays, no process
#     substitution.
#   - No `eval` (auto-safety classifier flags `eval` as FORBIDDEN_IN_AUTO).
#     A direct `bash scripts/intake/auto-entry.sh ... "$@"` invocation
#     preserves argv boundaries and passes the classify-command classifier.
#   - Pure forward + one notice line. Flag semantics are NOT changed here.
#   - CON-7 / D020 hygiene: no scaffold-placeholder marker bracket-TODO byte
#     pattern in any prose, comment, or output.

set -u

usage() {
  cat >&2 <<'USAGE'
usage: do-entry.sh --task <description>
                   [--yes]
                   [--config <path>]
                   [--dispatch-stub <script>]
                   [--scratch-root <dir>]
                   [--no-prompt-mode <A|B|C>]

  DEPRECATED: forwards to scripts/intake/auto-entry.sh (--ambiguity-mode
  prompt). Migrate to 'orchestrator:auto <task>'.

  --task             required: the task description (one shell argument).
  --yes              skip the Tier A+ approval prompt (forwarded to router).
  --config           test seam: override active config.yml lookup.
  --dispatch-stub    test seam: stand in for the agent runtime on the
                     Tier A degenerate fast-path; forwarded to router on
                     the Tier A+ branch.
  --scratch-root     test seam: forwarded to router on the Tier A+ branch.
  --no-prompt-mode   test seam: bypass interactive `read` on the
                     low-confidence-prompt branch.

Env:
  ORCH_DO_ENTRY_LOG  override JSONL unit_close record path.
USAGE
  exit 64
}

# Preserve `-h`/`--help` and usage-error exit-64 semantics unchanged: intercept
# the help flags here so `do-entry.sh --help` still prints the do usage and
# exits 64 rather than forwarding to auto-entry.sh's own usage.
for _arg in "$@"; do
  case "$_arg" in
    -h|--help) usage ;;
  esac
done

# One-line deprecation notice to STDERR (never stdout, so artifact parity holds).
printf 'do-entry: DEPRECATED — %s\n' \
  "'orchestrator:do' is now 'orchestrator:auto'. This shim forwards to auto-entry.sh and will be removed no earlier than one published release after this deprecation ships (target-removal version v0.12.0; see commands/do.md). Migrate to 'orchestrator:auto <task>'." >&2

# Forward ALL flags verbatim, prepending --ambiguity-mode prompt to preserve
# do's legacy interactive low-conf behavior. Direct invocation (no eval) keeps
# argv boundaries intact and returns auto-entry.sh's exit code unchanged.
bash scripts/intake/auto-entry.sh --ambiguity-mode prompt "$@"
exit $?
