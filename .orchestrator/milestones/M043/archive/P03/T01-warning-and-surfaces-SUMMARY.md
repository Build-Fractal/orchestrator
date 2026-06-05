---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M043"
provides:
  - "scripts/diagnostics/check-wiki-pages-exposure.sh — fallback-only GitHub-Pages footgun emitter (FR-10 / AD-2); fires on (private + github-pages) regardless of plan, silent elsewhere, carries the 'ignore if Enterprise Cloud' note; --mode doctor|status; ORCH_WIKI_REPO_VISIBILITY test seam; no plan/billing probe"
  - "both FR-10 surfaces wired: run-doctor.sh advisory run_check registration + commands/status.md status-surface section"
  - "tests/fixtures/m043-p03/ five-combo SC-6 fixture matrix (private/public x github-pages/cloudflare-access + private-default absent-key)"
  - "tools/verify/m043-p03-warning-matrix.sh (SC-6 fire/silence) + tools/verify/m043-p03-doctor-wiring.sh (wiring + AD-2 no-plan-probe boundary)"
requires:
  - "from:P01 what:scripts/wiki/resolve-deploy-target.sh shared resolver (github-pages | cloudflare-access; exit 2 on unknown enum)"
  - "from:disk what:scripts/diagnostics/run-doctor.sh run_check advisory helper + commands/status.md instruction document"
affects:
  - "phase P03 closure (this task's two verifiers are P03 SC-6 + FR-10-wiring gates)"
key_files:
  - "scripts/diagnostics/check-wiki-pages-exposure.sh,scripts/diagnostics/run-doctor.sh,commands/status.md,tests/fixtures/m043-p03/,tools/verify/m043-p03-warning-matrix.sh,tools/verify/m043-p03-doctor-wiring.sh"
key_decisions:
  - "PLAN DEFECT CORRECTED: the emitter as written resolved the P01 resolver SCRIPT via $ROOT/scripts/wiki/resolve-deploy-target.sh, but $ROOT is the config-root passed via --root (a fixture dir holding only .orchestrator/config.yml). The resolver script does not exist under fixture roots, so target always degraded to 'unknown' and every FIRE row went silent. Fixed by locating the resolver SCRIPT via SCRIPT_DIR (RESOLVER=\"$SCRIPT_DIR/../wiki/resolve-deploy-target.sh\"; framework siblings) while still passing $ROOT as the resolver's config-root argument (resolver reads <ROOT>/.orchestrator/config.yml). This is also correct for production where the diagnosed project's config-root differs from the framework install. Gate unchanged — fix made the emitter actually fire on the canonical (private + github-pages) tuple rather than weakening the verifier."
  - "AD-2 fallback-only preserved: visibility via gh repo view --json visibility (allowed) / ORCH_WIKI_REPO_VISIBILITY seam; no gh api plan probe, no Enterprise-plan detection in executable code; unknown visibility degrades to silent"
  - "advisory wiring: run_check trailing '1' so a fired warning increments advisory_warnings and never flips doctor health to NEEDS_ATTENTION"
patterns_established:
  - "shared framework-owned doctor sub-check invoked from two surfaces (run-doctor advisory + status.md prose) with a --mode doctor|status split; doctor mode always emits a trailing DOCTOR: ... status=warn|ok line for the run_check parser, status mode emits warning body only when firing"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P03/tasks/T01-warning-and-surfaces-PLAN.md"
duration: "implementation"
verification_result: "pass"
completed_at: "2026-06-04T00:00:00Z"
---

Shipped the fallback-only GitHub-Pages footgun warning emitter and wired it into both FR-10 surfaces. `scripts/diagnostics/check-wiki-pages-exposure.sh` (Bash 3.2 / POSIX-sh, `set -u`, exits 0 always) fires the warning only on the (private repo + `wiki.deploy_target: github-pages`) tuple regardless of GitHub plan, carries the literal "ignore if you are on GitHub Enterprise Cloud" note + a `cloudflare-access` pointer, and is silent on every other (visibility x deploy_target) combination. Visibility resolves via the `ORCH_WIKI_REPO_VISIBILITY` test seam, else `gh repo view --json visibility`, else unknown -> silent. No `gh api` plan probe / Enterprise-plan detection anywhere in executable code (AD-2). Doctor mode emits a trailing `DOCTOR: name=wiki_pages_exposure status=warn|ok` line; status mode emits the body only when firing.

Wired: `run-doctor.sh` gained one advisory `run_check "Wiki Pages Exposure" ... "--mode doctor --root $PROJECT_ROOT" "1"` line after the Corpus-Exhaustion Gate (trailing "1" = advisory, never flips health). `commands/status.md` gained a `## Wiki Deploy Exposure Warning (M043 / FR-10)` section between `## Blockers` and `## Execution History` instructing the agent to run the emitter in `--mode status` and surface output verbatim, silent otherwise. Built the five-combo SC-6 fixture matrix under `tests/fixtures/m043-p03/` plus the two verifiers.

PLAN DEFECT CORRECTED (one): the plan's verbatim emitter invoked the P01 resolver script as `bash "$ROOT/scripts/wiki/resolve-deploy-target.sh" "$ROOT"`. `$ROOT` is the `--root` config-root, which in the fixture matrix is a fixture directory containing only `.orchestrator/config.yml` and no `scripts/wiki/`. The resolver script therefore did not exist under `$ROOT`, the invocation failed, `target` degraded to `unknown`, and all four FIRE rows of the matrix verifier went silent (the gate caught a real bug, not a false-fail). Fix: locate the resolver SCRIPT relative to the emitter's own install dir (`RESOLVER="$SCRIPT_DIR/../wiki/resolve-deploy-target.sh"`, since `scripts/diagnostics/` and `scripts/wiki/` are framework siblings) while still passing `$ROOT` as the resolver's config-root argument (the resolver reads `<ROOT>/.orchestrator/config.yml`). This separates "where the resolver script lives" (framework install) from "which project's config to read" ($ROOT) and is correct both for the fixtures and for production where a diagnosed project's config-root differs from the framework install. The verifier was left unchanged — the gate was kept intact and the emitter was fixed to fire on the canonical tuple.

Verification:
- `bash tools/verify/m043-p03-warning-matrix.sh` -> `SUMMARY: m043-p03-warning-matrix.sh fail=0` (8/8 PASS: private+github-pages FIRES with Enterprise-Cloud note + cloudflare-access pointer, private+absent-key default FIRES, four SILENT rows, unknown-visibility degrades to silent).
- `bash tools/verify/m043-p03-doctor-wiring.sh` -> `SUMMARY: m043-p03-doctor-wiring.sh fail=0` (6/6 PASS: emitter exists, run-doctor registers it advisory with trailing "1", doctor mode prints status=ok when silent, status.md references it, no plan/billing probe in executable lines).
