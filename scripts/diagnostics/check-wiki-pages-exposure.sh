#!/usr/bin/env bash
# scripts/diagnostics/check-wiki-pages-exposure.sh — M043 P03 (FR-10 / AD-2).
# Fallback-only GitHub-Pages footgun warning. Fires on the (private repo +
# wiki.deploy_target: github-pages) tuple REGARDLESS OF PLAN, with an "ignore if
# Enterprise Cloud" note; silent on every other (visibility x deploy_target)
# combination. NO plan-detection logic (no `gh api` plan probe) — AD-2 dropped
# the reliable-detection and both-branch variants from M043 scope.
#
# Two CON-6 enforcement sites already defend the Cloudflare path structurally
# (P01 FR-3a pre-deploy health check + P02 provisioner); this advisory warning
# hardens the DEFAULT github-pages path by turning the pbj-central silent-
# exposure / silent-422-freeze failure modes loud.
#
# Modes:
#   --mode doctor  (default) emit the warning body when firing, then ALWAYS a
#                  trailing `DOCTOR: name=wiki_pages_exposure status=warn|ok`
#                  line for run-doctor.sh's run_check parser (advisory).
#   --mode status  emit ONLY the warning body when firing; nothing when silent
#                  (no DOCTOR line) — for the orchestrator:status surface.
#
# Repo visibility: ORCH_WIKI_REPO_VISIBILITY env seam (test-only) wins; else
# `gh repo view --json visibility -q .visibility` run from the project root;
# else "unknown". Unknown visibility => SILENT (never false-alarm on a repo we
# cannot confirm is private). Visibility detection is distinct from the dropped
# plan detection (AD-2 removed the PLAN probe, not the VISIBILITY read).
#
# Bash 3.2 / POSIX-sh: no associative arrays, no process substitution.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MODE="doctor"

while [ $# -gt 0 ]; do
  case "$1" in
    --root)  ROOT="$2"; shift 2 ;;
    --mode)  MODE="$2"; shift 2 ;;
    *) printf 'check-wiki-pages-exposure: unknown option: %s\n' "$1" >&2; exit 0 ;;
  esac
done

# --- resolve deploy_target (P01 resolver). Non-zero (unknown enum) => treat as
#     not-github-pages => silent. The resolver SCRIPT lives next to this one
#     (framework install: scripts/diagnostics/ and scripts/wiki/ are siblings),
#     so locate it via $SCRIPT_DIR; $ROOT is the config-root the resolver reads
#     (<ROOT>/.orchestrator/config.yml). These two roots are distinct when the
#     project being diagnosed differs from the framework install (and in the
#     fixture matrix, where $ROOT is a config-only fixture dir). ---
RESOLVER="$SCRIPT_DIR/../wiki/resolve-deploy-target.sh"
target="$(bash "$RESOLVER" "$ROOT" 2>/dev/null)" || target="unknown"

# --- resolve repo visibility ---
if [ -n "${ORCH_WIKI_REPO_VISIBILITY:-}" ]; then
  visibility="$ORCH_WIKI_REPO_VISIBILITY"
elif command -v gh >/dev/null 2>&1; then
  visibility="$( (cd "$ROOT" && gh repo view --json visibility -q .visibility) 2>/dev/null || true)"
  [ -n "$visibility" ] || visibility="unknown"
else
  visibility="unknown"
fi

# Normalize gh's "private"/"public"/"internal" casing.
vis_lc="$(printf '%s' "$visibility" | tr '[:upper:]' '[:lower:]')"

fire=0
if [ "$target" = "github-pages" ] && [ "$vis_lc" = "private" ]; then
  fire=1
fi

emit_warning() {
  printf '⚠ Wiki deploy exposure (FR-10): this repo is private and wiki.deploy_target is `github-pages`.\n'
  printf '  A private, access-controlled GitHub Pages site is a GitHub Enterprise Cloud–only feature.\n'
  printf '  On Free / Pro / Team this means ONE of two silent failure modes:\n'
  printf '    • Public exposure — the published site (and the whole .orchestrator/ corpus it surfaces)\n'
  printf '      is world-readable to anyone with the URL.\n'
  printf '    • Silent 422 freeze — if an Enterprise entitlement lapses, actions/deploy-pages returns\n'
  printf '      HTTP 422 on every push while the build job stays green; the live wiki freezes silently.\n'
  printf '  Fix: set `wiki.deploy_target: cloudflare-access` (a plan-independent, Access-gated target)\n'
  printf '  and re-run `orchestrator:wiki-init --deploy`. See references/installation.md (Wiki Deploy Targets).\n'
  printf '  (ignore if you are on GitHub Enterprise Cloud — private Pages is supported there.)\n'
}

if [ "$MODE" = "status" ]; then
  if [ "$fire" -eq 1 ]; then emit_warning; fi
  exit 0
fi

# doctor mode
if [ "$fire" -eq 1 ]; then
  emit_warning
  printf 'DOCTOR: name=wiki_pages_exposure status=warn\n'
else
  printf 'DOCTOR: name=wiki_pages_exposure status=ok\n'
fi
exit 0
