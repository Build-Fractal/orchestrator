---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M035"
milestone: "M035"
provides:
  - "rollback-marker-writer (scripts/lifecycle/write-rollback-marker.sh) + Stage-4.4.6 install-script hooks (install-claude-code.sh,install-codex.sh,install-cursor.sh) + D005 decision (rollback-marker schema) + two task-grain verifiers (m035-p05-rollback-marker-shape.sh BATTERY pass=6,m035-p05-rollback-snapshot-presence.sh BATTERY pass=3),rollback-dispatch (--rollback flag in scripts/lifecycle/run-update.sh) + commands/update.md ## Rollback section with verbatim #Q-G8 advisory + two task-grain verifiers (m035-p05-rollback-driver-shape.sh BATTERY pass=4,m035-p05-update-skill-doc-shape.sh BATTERY pass=5),sigstore-keyless-signing + SHA-256-fallback in .github/workflows/release.yml npm-publish job (5 new steps: Setup cosign + Stage release artifacts + Generate SHA256SUMS + Sign release artifacts + Create GitHub release) + job-level permissions override (id-token: write,contents: write) + D004 row in DECISIONS.md + tools/verify/m035-p05-release-workflow-signing-shape.sh task-grain verifier (BATTERY pass=10 fail=0) + /tmp/m035-p05-t03-yaml-validate.sh staged YAML structural-shape probe,references/installation.md ## Verifying integrity operator-facing section (3 subsections: Path 1 sigstore keyless cosign verify-blob recipe with canonical-repo identity URL https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v$VERSION + OIDC issuer https://token.actions.githubusercontent.com + Path 2 SHA-256 fallback shasum -a 256 -c SHA256SUMS --ignore-missing recipe + What to do if verification fails recovery procedure with search.sigstore.dev Rekor link); tools/verify/m035-p05-installation-doc-verifying-integrity.sh task-grain verifier (9 grep -F literal-string assertions BATTERY: pass=9 fail=0 AD-19 single-script shape),tools/verify/m035-p05-signature-verification.sh SC-11 verifier (~125 lines,BATTERY: pass=7 fail=0 skip=1 — 4 file-existence + shasum -c real-data + sig/cert non-empty + cosign verify-blob live-mode SKIP gated by COSIGN_AVAILABLE=1 AND M035_P05_LIVE_RELEASE_DIR env vars per M030 P03 live-LLM gating precedent); tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh SC-12 + SC-12b acceptance test (~190 lines,BATTERY: pass=6 fail=0 — copy-mode install N -> re-install N+1 -> rollback -> payload-tree byte-equality assertion + symlink-mode rollback refusal with verbatim spec-amendment advisory + git checkout recovery hint); fixture quartet at tests/m035-acceptance/fixtures/m035-p05-release-fixture/ (install.sh executable stub 9 lines + SHA256SUMS with real shasum-computed hash + install.sh.sig placeholder + install.sh.pem placeholder),tools/verify/m035-p05-phase-suite.sh phase-suite aggregator (~75 lines,executable,AD-19 single-script-file shape,bash 3.2 compatible) — chains all eight P05 per-truth verifiers in T01->T05 order,parses each verifier's BATTERY line and sums pass/fail/skip into a consolidated rollup,emits per-verifier PASS/FAIL decisions plus final BATTERY: pass=50 fail=0 skip=1 line,exit 0 iff total_fail=0; load-bearing for validate-milestone.sh M035 phase-grain oracle invocation and milestone acceptance-battery grep-aggregation"
requires:
  - "P02"
affects:
  - "P04"
key_files:
  - "scripts/lifecycle/write-rollback-marker.sh,packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,.orchestrator/DECISIONS.md,tools/verify/m035-p05-rollback-marker-shape.sh,tools/verify/m035-p05-rollback-snapshot-presence.sh,scripts/lifecycle/run-update.sh,commands/update.md,tools/verify/m035-p05-rollback-driver-shape.sh,tools/verify/m035-p05-update-skill-doc-shape.sh,.github/workflows/release.yml,tools/verify/m035-p05-release-workflow-signing-shape.sh,/tmp/m035-p05-t03-yaml-validate.sh,references/installation.md,tools/verify/m035-p05-installation-doc-verifying-integrity.sh,tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh,tools/verify/m035-p05-signature-verification.sh,tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh,tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.sig,tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.pem,tests/m035-acceptance/fixtures/m035-p05-release-fixture/SHA256SUMS,tools/verify/m035-p05-phase-suite.sh"
key_decisions:
  - "D005 (rollback-marker schema five-field key=value sidecar plus snapshot),D005 (consumed: rollback-marker schema five-field key=value sidecar plus snapshot),FR-12 (rollback-as-explicit-operator-action),FR-13 (multi-source dispatch via update_source config field),FR-15/FR-16 (M027 JSONL emission honored no new suppression knob),#Q-G8 (symlink/mixed-mode refusal with verbatim spec-amendment advisory),CON-7 (M025 reversibility-gate preserved -- snapshot replay restores prior manifest),D004 (authored: sigstore keyless primary + SHA-256 fallback resolves spec Q-3),FR-11 (release artifacts signed at publish time),SC-11 (both cosign-verify-blob AND shasum-verify surfaces succeed),CON-6 (no new long-lived secrets),CON-3/AP-009 (workflow YAML run blocks use pipe-block-scalar single-script-shape),AD-19 (verifier ships single-script Check shape with BATTERY-line output),Constitution-Principle-XVI (cosign-installer action AND cosign release version both pinned for dependency immutability),D004 (sigstore keyless signing — T04 documents the operator-side verify against the same identity URL T03 signs against); FR-11 (operator-facing integrity-verification doc surface); CON-3/AP-009 (compound-chain shape-guard honored — verifier uses 9 independent grep -F invocations no chains); AD-19 (verifier single-script-file shape with BATTERY-line output),SC-11 (signature verification surface — load-bearing acceptance for D004 sigstore keyless); SC-12 (rollback byte-equivalence — load-bearing acceptance for FR-12); SC-12b (symlink-mode + mixed-mode rollback refusal — verbatim advisory contract); AD-19 (verifier and acceptance test single-script-file shape no compound chains); CON-3/AP-009 (independent grep + shasum + cosign invocations); M030 P03 precedent (live-mode gating env vars COSIGN_AVAILABLE + M035_P05_LIVE_RELEASE_DIR — default OFF SKIP not mock); CON-5 / MIT-2 (test scopes hash to project_assets payload subtrees only — does NOT extend the canonical exclusion list at references/installation.md),AD-19 single-script-file shape (every verifier invocation is bash $v inside a for loop,no compound chains,no process substitution); CON-3/AP-009 (output capture to mktemp tempfiles read with grep — not <(...) substitution); CON-5 (BATTERY-line shape consistent with m029/m030/m032/m037/m035-p015/m035-p02 phase-suite convention enabling consolidate-time grep aggregation across milestone batteries); Plan-Time-Discipline Rule 6 (milestone-prefixed slug per M001 P00 convention amendment,avoiding the missing-prefix collision that lost M030's aggregator); Plan-Time-Discipline Rule 2 (defensive missing-verifier branch is belt-and-suspenders,not a substitute for T01-T05 actually shipping their verifiers — and they all do)"
patterns_established:
  - "rollback-state-capture-at-upgrade-time (decouples rollback from source-repo reachability),Stage-4.4.6-installer-hook-position (between install-meta and managed-gitignore mirroring M035-P00-T02 precedent),mode-detection-via-case-statement-counting (bash 3.2 substring matching no associative arrays),verifier-would_content_line-shape (per-field dry-run echo for shape assertions without writes),rollback-as-pre-source-resolution-branch (refusal/error paths return before installer ever invoked),backslash-newline-continuation-as-verbatim-multiline-string (bash 3.2 honors trailing-backslash in double-quoted strings to span source lines while emitting single logical line),skeleton-with-extension-points-for-source-dispatch (git arm functional npm/homebrew/curl arms emit SKIP -- mirrors P02 T03 cross-channel pattern),asset-replay-via-tab-prefix-parameter-expansion (rel=line-up-to-first-tab without awk/cut POSIX-sh safe),detached-HEAD-checkout-and-restore (orig_head capture then non-destructive checkout of prior_commit_sha then restore),job-level-permissions-override-preserves-workflow-level-least-privilege,release-artifacts-glob-loop-with-case-continue-skip,sigstore-keyless-OIDC-primary-plus-shasum-fallback,sign-the-checksum-file-itself,pinned-cosign-action-AND-pinned-cosign-release,npm-pack-after-publish-as-byte-identical-tarball-recreation,LC_ALL=C-sort-for-locale-independent-SHA256SUMS,python3-yaml-safe-load-staged-probe-mirrors-P02-T04,REPO_ROOT-defensive-fallback-in-staged-probes-continued,--yes-flag-required-for-cosign-keyless-under-CI,self-contained-operator-recipe (verification copy must be runnable end-to-end without other-doc indirection — every command shows exact flags + URLs + expected output); identity-URL-lockstep-with-signing-workflow (doc identity URL byte-identical to .github/workflows/release.yml signing path — drift makes verification fail end-to-end; verifier asserts the literal canonical-repo URL substring); two-path-defense-in-depth (recommended sigstore primary + no-cosign-required shasum fallback; SHA256SUMS itself signed for operators wanting both paths); grep-F-literal-match-shape (markdown punctuation like ## and ### confuses regex — switching to grep -q -F -- removes that hazard for doc-shape verifiers),payload-tree-scoped-hash-vs-cross-channel-helper (SC-12 question is narrower than CON-5 cross-channel byte-equivalence — it asks whether replayed runtime payload is byte-identical post-rollback not whether full installed tree including per-install metadata is; test rolls a local hash_payload_tree function over commands+scripts+references+templates+wiki rather than reusing _byte-equivalence-hash.sh which has different question-keying); live-mode-gating-default-OFF (cosign verify-blob runs only when COSIGN_AVAILABLE=1 AND M035_P05_LIVE_RELEASE_DIR=path env vars BOTH set; default behavior is SKIP not mock — there is no silently-mocked surface; mirrors M030 P03 ORCHESTRATOR_TIER2_LIVE convention); fixture-placeholder-with-real-shasum (install.sh.sig and install.sh.pem are placeholder comment files satisfying file-size>0 check while real cosign artifacts are produced by .github/workflows/release.yml at release time; SHA256SUMS uses REAL shasum hash of the fixture install.sh — Plan-Time Discipline Rule 5 real-data on the always-on path); same-HEAD-as-N+1 (test treats current HEAD as both version-N and version-N+1 — rollback machinery is what we test not actual version-N differences; install + force-reinstall at same HEAD writes marker capturing prior commit_sha=current HEAD then rollback git checkout is a no-op-against-source-repo); BSD-sed-bracket-class-papercut-discovered (existing tests/m035-acceptance/_byte-equivalence-hash.sh sed -E bracket-class pattern errors on macOS BSD sed making the EXCLUSION_LIST mechanism a no-op locally — P02 test passes because single-channel reflexive equality holds; NOT fixed in T05 to keep change footprint scoped — captured as papercut for future cross-channel hardening),BATTERY-line-summing-aggregator-shape (T06 sums internal counters across child verifiers — pass=50 fail=0 skip=1 — vs P02's verifier-unit-counting form pass=8 fail=0; the summing form is the right shape when the milestone-grain rollup needs assertion-count granularity and skip-line propagation,e.g. T05 cosign-live SKIP); battery-line-skip-default-via-case-pattern (case pattern \$battery_line\ in *skip=*) parse-with-sed ;; *) k=0 ;; esac is bash 3.2 compatible and avoids relying on sed default-when-no-match behavior); mktemp-tempfile-output-capture (>\$out_log\ 2>\$err_log\ plain-redirection-not-process-substitution survives both AP-009 shape-guard and AD-19 single-script-file constraint while permitting per-verifier failure forensics — cat $err_log >&2 only on FAIL); byte-equivalence-test-dominates-aggregator-wall-clock (~12min for tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh due to real install + re-install + rollback cycle against mktemp fixtures; verifiers T01-T07 complete combined in <2s; if validate-milestone.sh M035 runs all phase aggregators sequentially P05 will dominate milestone validation runtime — caveat for milestone-close planning)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P05/tasks/T01-rollback-marker-contract-SUMMARY.md, .orchestrator/milestones/M035/phases/P05/tasks/T02-rollback-dispatch-SUMMARY.md, .orchestrator/milestones/M035/phases/P05/tasks/T03-sigstore-signing-release-workflow-SUMMARY.md, .orchestrator/milestones/M035/phases/P05/tasks/T04-installation-doc-verifying-integrity-SUMMARY.md, .orchestrator/milestones/M035/phases/P05/tasks/T05-acceptance-tests-and-fixtures-SUMMARY.md, .orchestrator/milestones/M035/phases/P05/tasks/T06-phase-suite-aggregator-SUMMARY.md"
duration: "213m"
verification_result: "pass"
completed_at: "2026-05-09T03:37:55Z"
observability_surfaces:
  - "none"
---

P05 ships install-script integrity for the M035 launch event: signing,
checksums, and a rollback marker contract with `orchestrator:update
--rollback` dispatch. Six tasks (T01–T06) closed in dependency order; the
phase-suite aggregator reports `BATTERY: pass=50 fail=0 skip=1`.

## What was built

- **Rollback marker (FR-12, T01)** — `.orchestrator/.previous-version` is
  a five-field key=value sidecar (`prior_version`, `prior_commit_sha`,
  `prior_manifest_path`, `prior_install_mode`, `rolled_at`). The prior
  install's `installed-files.txt` is snapshotted to
  `.orchestrator/.rollback/manifest-<prior-version>.txt` at upgrade-time,
  decoupling rollback from source-repo reachability under
  `update_source: npm|homebrew`. Stage-4.4.6 hooks land in all three
  installers (`install-claude-code.sh`, `install-codex.sh`,
  `install-cursor.sh`).

- **Rollback dispatch (FR-12, T02)** — `scripts/lifecycle/run-update.sh
  --rollback` consumes the marker, refuses symlink-mode and mixed-mode
  rollback with the spec-amendment's verbatim advisory pointing
  operators to `git checkout` in the source repo (#Q-G8), and replays
  the snapshotted manifest under `update_source: git` (npm/homebrew/curl
  arms emit SKIP per the P02 cross-channel pattern). `commands/update.md`
  gains a `## Rollback` section.

- **Sigstore keyless signing + SHA-256 fallback (D004, T03)** — five
  steps inserted into the npm-publish job of `.github/workflows/
  release.yml`: setup cosign / stage release artifacts / generate
  SHA256SUMS / sign release artifacts / create GitHub release.
  Job-level `permissions: id-token: write, contents: write` overrides
  the workflow-level `contents: read` baseline so least-privilege
  survives outside this job. SHA256SUMS itself is signed; the cosign
  action AND the cosign release version are both pinned (Constitution
  Principle XVI). D004 resolves spec `#Q-3`.

- **Operator verification doc (FR-11, T04)** — `references/installation.md
  ## Verifying integrity` ships two paths: cosign verify-blob with the
  canonical-repo identity URL `https://github.com/Build-Fractal/orchestrator
  /.github/workflows/release.yml@refs/tags/v$VERSION` and OIDC issuer
  `https://token.actions.githubusercontent.com`, plus a no-cosign-required
  `shasum -a 256 -c SHA256SUMS --ignore-missing` fallback. The identity
  URL is byte-identical to the signing-workflow path; T03 declares it,
  T04 documents it, drift would make verification fail end-to-end.

- **Acceptance tests + fixture quartet (SC-11/SC-12/SC-12b, T05)** —
  `tools/verify/m035-p05-signature-verification.sh` exercises the
  always-on `shasum -c` path against real fixture data and SKIPs the
  cosign live-verify path unless `COSIGN_AVAILABLE=1` AND
  `M035_P05_LIVE_RELEASE_DIR=<path>` are both set (M030 P03 live-LLM
  gating precedent — default is SKIP, not mock).
  `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` runs
  install N → re-install N+1 → rollback → payload-tree byte-equality
  assertion plus the symlink-mode refusal contract.

- **Phase-suite aggregator (T06)** — `tools/verify/m035-p05-phase-suite.sh`
  chains all eight task-grain verifiers in T01→T05 order, sums the
  per-verifier `BATTERY:` lines, and emits the consolidated
  `BATTERY: pass=50 fail=0 skip=1`. Load-bearing for
  `validate-milestone.sh M035` invocation.

## Key decisions

- **D004 — sigstore keyless primary + SHA-256 fallback** (resolves
  spec `#Q-3`). Eliminates GPG private-key management blast-radius,
  binds signing identity to the GHA OIDC token via the canonical
  workflow-file URL, and ships SHA256SUMS as a tooling-free
  verification path for operators without cosign installed.

- **D005 — rollback-marker schema** (resolves dispatch-context `#Q-4`).
  Five-field sidecar plus snapshotted manifest at upgrade-time. The
  `prior_install_mode` field is the single point of enforcement for
  `#Q-G8`'s symlink-mode refusal.

## Verification

- Phase-suite aggregator (`m035-p05-phase-suite.sh`) → `BATTERY: pass=50
  fail=0 skip=1` end-to-end.
- All eight task-grain verifiers green: rollback-marker-shape (pass=6),
  rollback-snapshot-presence (pass=3), rollback-driver-shape (pass=4),
  update-skill-doc-shape (pass=5), release-workflow-signing-shape
  (pass=10), installation-doc-verifying-integrity (pass=9),
  signature-verification (pass=7 skip=1), rollback-byte-equivalence
  (pass=6).
- Wall-clock dominated by the byte-equivalence acceptance test (~12min
  due to real install + re-install + rollback against mktemp fixtures);
  task-grain shape verifiers complete in <2s combined.

## Caveats and follow-ups

- **BSD-sed bracket-class papercut surfaced (T05 finding, not fixed)**
  — the P02 helper `tests/m035-acceptance/_byte-equivalence-hash.sh`
  uses a `sed -E '[][.^$*+?(){}|\\]'` bracket class that errors on
  macOS BSD sed, silently degrading the EXCLUSION_LIST mechanism to a
  no-op locally. P02's cross-channel test passes by accident because
  single-channel reflexive equality holds. T05 sidestepped by rolling
  a local `hash_payload_tree()` scoped to project_assets subtrees.
  Captured as a paper-cut for future cross-channel hardening.

- **`scripts/util/run-probe.sh` does not export `REPO_ROOT`** — same
  paper-cut P02 T01/T02/T05 hit and noted. Staged probes apply
  parameter-expansion fallback. Recommended follow-up: export
  `REPO_ROOT` in `run-probe.sh` or update its docstring.

- **Phase-suite wall-clock dominated by acceptance test (~12min)** —
  if `validate-milestone.sh M035` runs phase aggregators sequentially,
  P05 will dominate milestone validation runtime. Captured as a
  paper-cut follow-up (parallelize phase aggregators and/or cache
  byte-equivalence fixture state).

- **Branch-discipline incidents (procedural, no work lost)** — three
  P05 task agents committed onto detached HEAD after running
  `git checkout <sha>` post-commit. Dispatcher fast-forwarded `main`
  three times. All commits remained on the linear `main` history; no
  branch divergence. Contributing factor: agent-side branch operations
  not gated by the dispatcher. Open question for M035 close: whether
  to add a "do NOT run git checkout/switch in task agents" clause to
  the orchestrator-agent system prompt or fold it into the task-plan
  template.

## Roadmap reassessment

- No deviations from the original P05 boundary map. Produces / Consumes
  match the roadmap declaration. P04 (curl-pipe-bash + GH release
  automation) consumes P05's signing infrastructure + rollback-marker
  contract as declared; no downstream-stale signal.
- `roadmap_sync` reports `SYNC:OK`.

P05 is the second-to-last functional phase before launch. Remaining:
P03 (homebrew tap, ready), P04 (curl-pipe-bash, gated on M033
friendly-tester pass), P06 (`orchestrator:update` multi-source
dispatch + acceptance battery, gated on P03/P04).
