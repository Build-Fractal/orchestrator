---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M043"
name: "Fallback-only footgun warning emitter + both surfaces + fixture matrix"
depends_on: []
---

## Prerequisites

These files exist on disk before this task runs (verified at plan-authoring time):

- `scripts/wiki/resolve-deploy-target.sh` — P01 shared resolver. Usage:
  `bash scripts/wiki/resolve-deploy-target.sh <project-root>` prints
  `github-pages` (default / explicit / absent key) or `cloudflare-access`;
  exits `2` + stderr on an unknown enum value.
- `scripts/diagnostics/run-doctor.sh` — the doctor orchestrator. It runs each
  sub-check via the `run_check "<name>" "$SCRIPT_DIR/<script>.sh" "<args>" "<advisory>"`
  helper. `<advisory>` is `1` for advisory checks (increment `advisory_warnings`,
  do NOT count toward `checks_total` or flip health). The helper greps the
  sub-check's stdout for a `^DOCTOR:` line and parses `status=<word>` (statuses
  `ok`/`skip` → pass; `warn`/`drift`/`missing`/unknown → not-pass).
- `commands/status.md` — the `orchestrator:status` instruction document (markdown,
  agent-followed; not a bash script).

## Description

Author the fallback-only GitHub-Pages footgun warning emitter and wire it into
the two surfaces named by FR-10 (`orchestrator:doctor` via `run-doctor.sh`, and
`orchestrator:status`). Per **AD-2** the warning is the **fallback branch only**:
it fires on the (private repo + `github-pages`) tuple **regardless of GitHub
plan**, carries an "ignore if you're on GitHub Enterprise Cloud" note, and is
silent on every other (visibility × deploy_target) combination. There is **no
plan-detection logic** — no `gh api` plan probe. This is SC-6's fallback branch.

The emitter is a single framework-owned script shared by both surfaces. Build the
SC-6 single-branch fixture matrix and the two verifiers that prove (a) the
fire/silence behavior + Enterprise note and (b) both surfaces are wired with no
plan probe.

## Steps

### Step 1 — Author `scripts/diagnostics/check-wiki-pages-exposure.sh`

Framework-owned doctor sub-check (sibling of `check-orphaned.sh` etc.). Bash 3.2
/ POSIX-sh; `set -u`; exits `0` always (advisory; degrade gracefully). Write it
verbatim to this contract:

```bash
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
#     not-github-pages => silent. ---
target="$(bash "$ROOT/scripts/wiki/resolve-deploy-target.sh" "$ROOT" 2>/dev/null)" || target="unknown"

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
```

Key contract points the verifiers depend on:
- The warning body contains the literal phrase `ignore if you are on GitHub Enterprise Cloud` (the AD-2 note) and the literal `cloudflare-access` pointer.
- doctor mode always ends with a `DOCTOR: name=wiki_pages_exposure status=warn|ok` line.
- status mode prints the warning body ONLY when firing and nothing otherwise.
- No `gh api` call and no plan/Enterprise probe appears anywhere in the script.

### Step 2 — Wire into `run-doctor.sh`

In `scripts/diagnostics/run-doctor.sh`, add ONE advisory `run_check` line into the
"Run all checks" block (after the existing advisory checks, e.g. right after the
`run_check "Corpus-Exhaustion Gate" ...` line and before the Anomaly Detection
block). Add exactly:

```bash
run_check "Wiki Pages Exposure" "$SCRIPT_DIR/check-wiki-pages-exposure.sh" "--mode doctor --root $PROJECT_ROOT" "1"
```

The trailing `"1"` marks it advisory (a fired warning increments
`advisory_warnings`, never flips health to `NEEDS_ATTENTION`).

### Step 3 — Wire into `commands/status.md`

In `commands/status.md`, add a new top-level section immediately AFTER the
`## Blockers` section and BEFORE `## Execution History`. Author it as agent
instruction prose (status.md is followed, not executed):

```markdown
## Wiki Deploy Exposure Warning (M043 / FR-10)

Surface the fallback-only GitHub-Pages footgun warning. Run:

    bash scripts/diagnostics/check-wiki-pages-exposure.sh --mode status --root "$PROJECT_DIR"

The emitter is fallback-only per AD-2: it prints a warning block ONLY when the
repo is private AND `wiki.deploy_target` is `github-pages` (with an "ignore if
Enterprise Cloud" note); it prints nothing on every other combination and never
runs a GitHub-plan probe. If the script emits any output, surface it verbatim as
a warning callout in the status report; if it is silent, render nothing for this
section. The check is read-only and advisory — it never changes the milestone
state or the recommended next action.
```

### Step 4 — Build the SC-6 fixture matrix

Create five placeholder-pure project-config fixtures (each a minimal
`<combo>/.orchestrator/config.yml` with only the `wiki:` block the resolver
reads). Visibility is NOT stored in the fixture — it is injected by the verifier
via `ORCH_WIKI_REPO_VISIBILITY`.

`tests/fixtures/m043-p03/private-github-pages/.orchestrator/config.yml`:
```yaml
wiki:
  deploy_target: github-pages
```

`tests/fixtures/m043-p03/private-cloudflare/.orchestrator/config.yml`:
```yaml
wiki:
  deploy_target: cloudflare-access
```

`tests/fixtures/m043-p03/public-github-pages/.orchestrator/config.yml`:
```yaml
wiki:
  deploy_target: github-pages
```

`tests/fixtures/m043-p03/public-cloudflare/.orchestrator/config.yml`:
```yaml
wiki:
  deploy_target: cloudflare-access
```

`tests/fixtures/m043-p03/private-default/.orchestrator/config.yml` (absent
`deploy_target` key → resolver returns the `github-pages` default → must still
fire when private):
```yaml
wiki:
  landing_cards: []
```

### Step 5 — Author `tools/verify/m043-p03-warning-matrix.sh` (SC-6 fallback branch)

Project-owned behavioral verifier (single-script-file, AD-19). Drives the emitter
in `--mode status` (clean output: non-empty = fired, empty = silent) against each
fixture with an injected visibility, asserting the exact SC-6 fallback matrix.
Mirror the P02 verifier shape (`check()` helper, `PASS:`/`FAIL:` lines, final
`SUMMARY: ... fail=N`).

```bash
#!/usr/bin/env bash
# m043-p03-warning-matrix.sh — SC-6 (FR-10 / AD-2 fallback branch). The warning
# fires on exactly (private + github-pages) regardless of plan, carries the
# "ignore if Enterprise Cloud" note, and is silent on every other combination.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
EMIT="scripts/diagnostics/check-wiki-pages-exposure.sh"
FX="tests/fixtures/m043-p03"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

# run_emit <visibility> <fixture-subdir> -> echoes status-mode stdout
run_emit() {
  ORCH_WIKI_REPO_VISIBILITY="$1" bash "$EMIT" --mode status --root "$FX/$2" 2>/dev/null
}

# --- FIRE rows ---
out="$(run_emit private private-github-pages)"
[ -n "$out" ]; check "private + github-pages FIRES" $?
printf '%s' "$out" | grep -qi 'Enterprise Cloud'
check "fired text carries the 'ignore if Enterprise Cloud' note" $?
printf '%s' "$out" | grep -q 'cloudflare-access'
check "fired text points to the cloudflare-access target" $?

out="$(run_emit private private-default)"
[ -n "$out" ]; check "private + absent-key (default github-pages) FIRES" $?

# --- SILENT rows ---
out="$(run_emit private private-cloudflare)"
[ -z "$out" ]; check "private + cloudflare-access is SILENT" $?

out="$(run_emit public public-github-pages)"
[ -z "$out" ]; check "public + github-pages is SILENT" $?

out="$(run_emit public public-cloudflare)"
[ -z "$out" ]; check "public + cloudflare-access is SILENT" $?

# --- unknown visibility degrades to SILENT even on github-pages ---
out="$(run_emit unknown private-github-pages)"
[ -z "$out" ]; check "unknown visibility + github-pages degrades to SILENT" $?

echo "SUMMARY: m043-p03-warning-matrix.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Step 6 — Author `tools/verify/m043-p03-doctor-wiring.sh`

Asserts both surfaces are wired and the AD-2 no-plan-detection boundary holds.

```bash
#!/usr/bin/env bash
# m043-p03-doctor-wiring.sh — FR-10 wiring + AD-2 no-plan-detection boundary.
# Asserts: (a) run-doctor.sh registers the emitter as an advisory sub-check;
# (b) the emitter prints a DOCTOR: line in doctor mode; (c) commands/status.md
# references the emitter; (d) the emitter contains NO plan-detection probe.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
EMIT="scripts/diagnostics/check-wiki-pages-exposure.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

[ -f "$EMIT" ]; check "emitter exists" $?

# (a) run-doctor registers it, advisory (trailing "1" arg)
grep -q 'check-wiki-pages-exposure.sh' scripts/diagnostics/run-doctor.sh
check "run-doctor.sh registers the emitter" $?
grep -E 'run_check "Wiki Pages Exposure".*check-wiki-pages-exposure.sh.*"1"' scripts/diagnostics/run-doctor.sh >/dev/null
check "emitter is registered as an advisory check (trailing \"1\")" $?

# (b) doctor mode prints a DOCTOR: line (ok on a silent run)
ORCH_WIKI_REPO_VISIBILITY=public bash "$EMIT" --mode doctor --root . 2>/dev/null | grep -q '^DOCTOR: name=wiki_pages_exposure status=ok'
check "doctor mode prints DOCTOR: ... status=ok when silent" $?

# (c) status.md references it
grep -q 'check-wiki-pages-exposure.sh' commands/status.md
check "commands/status.md references the emitter (status surface)" $?

# (d) AD-2: no plan-detection logic in the emitter's EXECUTABLE lines.
# Strip full-line comments first — the emitter's own header documents that it
# has "no gh api plan probe" / "NO plan-detection logic", and those explanatory
# comment tokens must not trip this check. Match only a real plan/billing probe
# in code: a `gh api` call, a `--json plan|billing` field, or an Enterprise-plan
# parse. The legitimate `gh repo view --json visibility` (visibility != plan
# detection, AD-2) and the "GitHub Enterprise Cloud" warning text are NOT matched.
code="$(grep -v '^[[:space:]]*#' "$EMIT")"
if printf '%s\n' "$code" | grep -Eq 'gh api|--json (plan|billing)|plan_name|isEnterprise'; then p=1; else p=0; fi
[ "$p" -eq 0 ]
check "emitter executable lines contain NO plan/billing probe (AD-2)" $?

echo "SUMMARY: m043-p03-doctor-wiring.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

## Must-Haves

- Truth: fallback-only warning fires on exactly (private + github-pages), silent elsewhere, Enterprise note present.
  - Check: `bash tools/verify/m043-p03-warning-matrix.sh`
- Truth: both surfaces wired (run-doctor + status.md), no plan-detection logic.
  - Check: `bash tools/verify/m043-p03-doctor-wiring.sh`
- Artifact: `scripts/diagnostics/check-wiki-pages-exposure.sh` (min 60 lines, contains "ignore if Enterprise Cloud")
- Artifact: the five `tests/fixtures/m043-p03/*/.orchestrator/config.yml` fixtures
- Artifact: `tools/verify/m043-p03-warning-matrix.sh`, `tools/verify/m043-p03-doctor-wiring.sh`

## Verification

```bash
bash tools/verify/m043-p03-warning-matrix.sh
bash tools/verify/m043-p03-doctor-wiring.sh
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `scripts/wiki/resolve-deploy-target.sh` — invoked by the emitter to resolve
  `deploy_target`. Contract: `bash resolve-deploy-target.sh <root>` → stdout
  `github-pages` | `cloudflare-access`; exit `2` on unknown enum.
- `scripts/diagnostics/run-doctor.sh` — modified to register the emitter via the
  `run_check "<name>" "<script>" "<args>" "<advisory=1>"` helper (advisory line
  inserted into the "Run all checks" block).
- `commands/status.md` — modified to add the status-surface section invoking the
  emitter in `--mode status`.

## Constraints

- **AD-2 fallback-only** — fire on (private + github-pages) regardless of plan;
  silent on all other (visibility × target) combinations; "ignore if Enterprise
  Cloud" note in the warning text; NO plan-detection logic anywhere.
- **Advisory** — register with the `run_check` advisory flag (`1`); a fired
  warning must NOT flip the doctor health report to `NEEDS_ATTENTION`.
- **Graceful degradation** — exit `0` always; unknown visibility → silent.
- **Bash 3.2 / POSIX-sh** — no associative arrays, no process substitution in
  the emitter. (The verifiers may use `$(...)` freely — they are test harness,
  not framework runtime, and run under bash not POSIX sh.)
- **Single-script-file Check commands (AD-19)** — every verifier is invoked as
  `bash tools/verify/m043-p03-*.sh`.
- **Scope** — touch only the files in this task's must-haves; do not modify the
  P01/P02 deliverables or the `github-pages` emit path.

## Expected Output

`bash tools/verify/m043-p03-warning-matrix.sh` prints a `PASS:` line per matrix
row and `SUMMARY: m043-p03-warning-matrix.sh fail=0`.
`bash tools/verify/m043-p03-doctor-wiring.sh` prints `PASS:` lines for each
wiring assertion and `SUMMARY: m043-p03-doctor-wiring.sh fail=0`.
