---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M033"
provides:
  - "scripts/lifecycle/start.sh FR-16 additive extension (--with-github flag + WITH_GITHUB global + github_init_passthrough function + post-wiki-init invocation gate in main() + stub-mode dispatch + github_init_invoked JSONL emit + sequential-atomicity failure-propagation contract); tools/verify/m033-p05-with-github-passthrough-shape.sh (19-check shape + functional + ordering + cross-phase regression verifier)"
requires:
  - "T02"
affects:
  - "T04,T05"
key_files:
  - "scripts/lifecycle/start.sh,tools/verify/m033-p05-with-github-passthrough-shape.sh"
key_decisions:
  - "additive-extension-discipline-mirrors-T02-wiki-passthrough-pattern;github-gate-inserted-immediately-after-wiki-gate-in-main()-so-natural-code-ordering-enforces-FR-16-ordering-rule-without-explicit-conditional;stub-mode-uses-printf-not-echo-for-bash-3.2-portability;real-mode-bash-script-invocation-not-sourced-to-keep-rc-isolation-clean;jsonl-emit-payload-omits-with-giscus/deploy-(github-side-flags-are-M013-internal-not-paired-launch-orchestrator-surface);github_init_invoked-already-in-12-event-closed-enum-(P02/T01-shipped+P03/T04-extended)-no-enum-extension-required"
patterns_established:
  - "paired-launch-passthrough-mirror-pattern (github_init_passthrough is structurally a copy of wiki_init_passthrough with FR-15->FR-16 + WIKI->GH + M033_FR15_STUB->M033_GHINIT_STUB substitutions); post-gate-ordering-via-code-position (no explicit if-wiki-then-github conditional needed -- T02 gate exits on failure and falls through on success, T03 gate inserted immediately below); stub-mode-functional-smoke-with-three-fixture-stages (success path + non-zero exit propagation + ordering rule under combined flags); cross-phase-regression-as-final-verifier-step (re-runs T02 verifier + P01 SC-1 acceptance under [ -f ... ] guard for re-run defensive posture)"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P05/tasks/T03-with-github-passthrough-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-04T16:00:00Z"
---

# T03 -- FR-16 --with-github passthrough additive extension

## What was built

T03 ships the FR-16 paired-launch passthrough as an additive extension to `scripts/lifecycle/start.sh` (T02 inheritor):

1. **`scripts/lifecycle/start.sh` extension** (modify, +~75 lines on top of T02's +80):
   - `WITH_GITHUB=0` global initialized at top-of-script alongside T02's `WITH_WIKI`/`WITH_GISCUS`/`DEPLOY`.
   - `--with-github` case added to the argument parser, setting `WITH_GITHUB=1`.
   - `USAGE` string extended with `[--with-github]`.
   - `github_init_passthrough()` function added immediately after `wiki_init_passthrough()`, mirroring T02's failure-propagation discipline:
     - Stub mode (`M033_GHINIT_STUB=1`) emits `STUB: github-init invoked --project-dir=<path>` and returns `M033_GHINIT_STUB_EXIT_CODE` (default 0).
     - Real mode invokes `bash scripts/lifecycle/github-init.sh --project-dir <path>` if the script exists; otherwise emits `github-init.sh not found -- M013 must be installed before --with-github real-mode can fire` to stderr and returns rc=1 (genuine failure, NOT skip).
     - FR-22 JSONL emit of `github_init_invoked` with `{project_dir, exit_code, stub_mode}` payload (event already in 12-event closed enum -- no extension required).
     - Sequential-atomicity model on non-zero exit: emits `github-init failed; re-run "orchestrator:github-init" independently to complete; all other onboarding outputs preserved` and returns the underlying exit code verbatim.
   - Post-wiki-init invocation gate threaded into `main()` IMMEDIATELY AFTER T02's wiki gate. Code ordering enforces the FR-16 ordering rule: T02's gate `exit "$WIKI_RC"`s on wiki failure (so T03's gate is unreachable), and falls through to T03's gate on wiki success.

2. **`tools/verify/m033-p05-with-github-passthrough-shape.sh`** (create, executable, 81 lines):
   - 12 token-presence assertions (`--with-github`, `WITH_GITHUB`, `M033_GHINIT_STUB`, `M033_GHINIT_STUB_EXIT_CODE`, `github_init_invoked`, `github-init failed`, `github-init.sh`, `STUB: github-init invoked`, `all other onboarding outputs preserved`, `github-init.sh not found`, `github_init_passthrough`).
   - 3 functional smoke tests: stub-mode rc=0 path; stub-mode rc=17 propagation path; combined `--with-wiki --with-github` ordering rule (asserts `STUB: wiki-init invoked` line < `STUB: github-init invoked` line via `grep -n`).
   - 2 cross-phase regression checks (guarded with `[ -f ... ]` for defensive re-run posture): T02 verifier still passes; P01 SC-1 acceptance still passes.

## Verification result

`bash tools/verify/m033-p05-with-github-passthrough-shape.sh`:
```
SUMMARY: m033-p05-with-github-passthrough-shape.sh pass=19 fail=0
```

All 19 checks PASS:
- 1 file-existence check
- 11 token-presence checks
- 3 stub-mode functional smoke checks (STUB token emit, rc=0 propagation, rc=17 exit-code propagation, failure diagnostic emit)
- 1 ordering-rule functional smoke check (wiki line < github line under combined flags)
- 1 T02 verifier cross-phase regression
- 1 P01 SC-1 acceptance cross-phase regression
- (1 additional rc=0 / rc=17 split = 19 total)

## Decisions captured during execution

- **Mirror T02's structure verbatim** -- `github_init_passthrough` is a near-copy of `wiki_init_passthrough` with FR-15->FR-16, WIKI->GH, `M033_FR15_STUB`->`M033_GHINIT_STUB`, and the `--with-giscus`/`--deploy` flag-threading removed (those are wiki-side surface, not github-side). This minimizes review surface and locks the failure-propagation contract identically.
- **JSONL payload shape** -- `{project_dir, exit_code, stub_mode}` only. The wiki passthrough adds `with_giscus` and `deploy` because those are paired-launch-orchestrator-visible surface flags; github has no equivalent operator-visible side flags at the M033 layer (any GitHub-specific config is M013-internal).
- **Code ordering enforces ordering rule** -- T03's gate is inserted IMMEDIATELY AFTER T02's gate in `main()`. No explicit `if WITH_WIKI succeeded then run github` conditional is needed because T02's gate `exit "$WIKI_RC"`s on failure, making T03 unreachable. When wiki succeeds (or wasn't requested), control falls through to T03's gate. This is the natural-code-ordering version of the spec's FR-16 ordering rule.
- **No JSONL closed-enum extension required** -- `github_init_invoked` is already in the 12-event enum (P02/T01 shipped 11, P03/T04 added `imported_context_loaded` for 12). T03 calls `emit github_init_invoked` directly. Verified by grepping the emitter.
- **Real-mode invocation shape** -- `bash scripts/lifecycle/github-init.sh --project-dir <path>`. If M013's existing entry point uses a different flag form, the wrapper translation is M013's responsibility (per spec Assumption A-2). The functional smoke tests run stub-mode only, so this is not load-bearing for T03's verifier.

## Patterns established

- **Paired-launch-passthrough mirror pattern** -- T03's function is structurally a copy of T02's with the substitutions named above. Future paired-launch passthroughs (e.g., a hypothetical `--with-deploy` post-github gate) would follow the same shape.
- **Post-gate-ordering-via-code-position** -- ordering rule between two paired-launch gates is enforced by literal code position in `main()`, not by an explicit conditional. T02 gate exits on failure and falls through on success; T03 gate is inserted immediately below.
- **Three-stage stub-mode functional smoke** -- success path (rc=0 STUB token emit), failure path (rc=17 exit-code propagation + failure diagnostic emit), ordering rule (combined flags, `grep -n` line-number assertion). All three live under `mktemp -d` staging with `--dry-run` so no real-mode invocations fire.
- **Cross-phase regression as final verifier step** -- T03's verifier re-runs the T02 verifier and P01 SC-1 acceptance under `[ -f ... ]` guards. This makes T03's verifier load-bearing for AD-15 cross-phase regression discipline by construction.

## What downstream tasks consume

- **T04 (acceptance battery)** -- `tests/m033-acceptance/p08-with-github-passthrough.sh` will exercise the full paired-launch surface end-to-end via `start.sh` invocations, asserting JSONL records + marker invariants. T03 ships the surface that test will exercise; the SC-10 `STUB: wiki-init invoked` < `STUB: github-init invoked` token-ordering assertion was preflight-validated inside T03's verifier.
- **T05 (phase close)** -- `tools/verify/m033-p05-phase-suite.sh` will aggregate this verifier among the P05 sub-verifier list. `tools/verify/m033-p05-cross-phase-regression.sh` will re-run P01/P02/P03/P04 phase-suites, all of which must remain green against the post-T03 tree (preflight-validated inside T03's verifier via the T02 verifier and P01 SC-1 invocations).

## Constraints respected

- Bash 3.2 compatible (MEM001) -- no `declare -A`, no process substitution, no `$(< ...)`. `printf`-into-`local` for payload assembly. `local rc=0` then `... || rc=$?` for safe exit-code capture.
- AD-19 single-script-file shape -- the Verification block contains a single `bash <path>` invocation.
- AD-15 cross-phase regression -- T02 verifier (19/19 PASS post-T03), P01 SC-1 acceptance (still PASS post-T03), T02 wiki-passthrough behavior preserved verbatim (only additive insertion).
- FR-16 ordering rule -- enforced by code ordering; preflight-validated inside T03's verifier (wiki line 2 < github line 3 in combined-flags fixture).
- Stub-mode discipline -- pass-not-skip; no `EXIT 77`, no `SKIP:` token in any code path.
- CON-3 / Principle XVI -- zero `speckit.*` references in any code path or output (verified via `grep -nE 'speckit\.'`, no matches).
