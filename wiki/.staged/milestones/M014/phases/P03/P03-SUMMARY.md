---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M014"
milestone: "M014"
provides:
  - "scripts/comments/fetch.sh (FR-8 fetcher: Giscus + GitHub Issue/PR via gh stubs,JSONL line-by-line parser,--dry-run FR-19 manifest,--yes inheritance,unit_close JSONL emission); tests/fixtures/m014-p03/sample-inbox.jsonl (4 mixed-surface comments — one per FR-9 class — reusable by T02+); scripts/verify/m014-p03-fetch.sh (8-check verifier covering hermetic stub fetch,idempotency skip,dry-run no-write); CON-8 idempotency contract via grep -F on actioned.jsonl URLs; ORCHESTRATOR_PROJECT_ROOT + GH_API_STUB + GH_GRAPHQL_STUB env-var hermetic-test convention,scripts/comments/classify.sh (FR-9 v1 regex/heuristic classifier per D023); templates/conversus-presets/classify-comment.yml (CON-4 ambiguous-routing preset,single-agent cooperative); specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md (SC-16 dogfood-data capture + D023 retune triggers); scripts/verify/m014-p03-classify.sh (8-case verifier covering four FR-9 classes + verdict shape + pin docstring + preset existence + dogfood D023 citation),commands/comments.md (six-subcommand surface: classify/status/apply/reject/triage/reclassify),scripts/comments/apply.sh (FR-1+US-5 human-gated spec-amendment apply,stale-diff + in-flight conversus refusal,rebuild-index hook,actioned.jsonl row,comment_actioned event),scripts/comments/reject.sh (FR-1 queue rejection with --reason; appends applied:false row),scripts/comments/triage.sh (FR-1 human-triage bucket lister; tab-separated rows + SUMMARY count),tests/fixtures/m014-p03/queued-amendment.md (Q001 hermetic fixture for apply.sh end-to-end),scripts/comments/comments.sh (master pipeline — classify/status/apply/reject/triage/reclassify subcommands,threshold-gated auto-apply for uat-bug+decision-append,human-queue for spec-amendment,conversus-strict ambiguous routing with adapter-missing→triage fallback)|scripts/verify/m014-p03-pipeline.sh (13 assertions — hermetic 4-comment fixture exercising every routing class + idempotency + deterministic shasum filenames + FR-16 unit_close + FR-10 comment_actioned)|scripts/verify/m014-p03-auto-apply.sh (4 cases — high-conf uat-bug auto-apply via stubbed M013 ingest,high-conf decision-append DECISIONS.md row,low-conf uat-bug below-threshold queue,high-conf spec-amendment SC-5 always-queue invariant)|scripts/verify/m014-p03-observability.sh (8 assertions — every FR-16 unit_close field present + integer-shaped + counter sanity,every FR-10 comment_actioned field present),comments: section in .orchestrator/config.yml (auto_apply_threshold per-class scalars,reply_on_apply: false,fetch_schedule: manual)|references/spec-management.md ## Comment Classification & Workflow Routing section (FR-9 v1 ruleset,threshold table,CON-5/SC-5 spec-amendment human-gate language,D023 retune trigger,FR-19 dry-run manifest)|six new verifiers (config-keys,references-section,bash32-and-lint omnibus,zero-prompts,dogfood-capture,phase-suite orchestrator)|CLAUDE.md + AGENTS.md Recent Changes M014/P03 entry via dual-write helper|14-gate phase suite emits 'SUMMARY: m014-p03-phase-suite.sh pass=14 fail=0'"
requires:
  - "P01"
affects:
  - "none"
key_files:
  - "scripts/comments/fetch.sh,scripts/verify/m014-p03-fetch.sh,tests/fixtures/m014-p03/sample-inbox.jsonl,scripts/comments/classify.sh,templates/conversus-presets/classify-comment.yml,specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md,scripts/verify/m014-p03-classify.sh,commands/comments.md,scripts/comments/apply.sh,scripts/comments/reject.sh,scripts/comments/triage.sh,tests/fixtures/m014-p03/queued-amendment.md,scripts/comments/comments.sh,scripts/verify/m014-p03-pipeline.sh,scripts/verify/m014-p03-auto-apply.sh,scripts/verify/m014-p03-observability.sh,.orchestrator/config.yml,references/spec-management.md,scripts/verify/m014-p03-config-keys.sh,scripts/verify/m014-p03-references-section.sh,scripts/verify/m014-p03-bash32-and-lint.sh,scripts/verify/m014-p03-zero-prompts.sh,scripts/verify/m014-p03-dogfood-capture.sh,scripts/verify/m014-p03-phase-suite.sh,CLAUDE.md,AGENTS.md"
key_decisions:
  - "JSONL stub fixtures filtered per-surface inside _process_record so a single shared fixture pointed at by both GH_API_STUB and GH_GRAPHQL_STUB yields each record exactly once (plan implicit); plan step 7 expected pass=8 but plan step 6 enumerates only 7 checks — closed the gap by adding inbox-record-shape check (body_shasum field presence) which also locks down the FR-8 record contract for T02; sed-based json field extractor (no jq dependency) per MEM001; surface filter is only applied when source_surface is present so production gh JSON without that field still flows through,D023 (regex/heuristic v1 pin + retune triggers); D007 reuse (NEW preset,no adapter modification); CON-5/SC-5 (classify.sh pure verdict producer — spec-amendment always queues regardless of confidence); single-source-of-truth for retune triggers = dogfood-data file,patch -N (forward-only) is the stale-diff probe,not vanilla --dry-run; vanilla --dry-run silently auto-reverses on a previously-applied diff (rc=0) and would mask staleness,review-queue diff extraction targets the FIRST ```diff fenced block in the queue file body (deterministic against fixture shape),in-flight conversus = conversus/ directory exists AND conversus/summary/final.md absent (US-5 AS-4),triage.sh treats absent .orchestrator/comments/triage/ as entries=0 and exits 0 (no-op-on-empty pattern),human-gate verifier scans scripts/comments/*.sh excluding apply.sh itself (apply.sh IS the manual gate,so its class=spec-amendment string is legitimate not a violation),env-overridable sub-script paths (COMMENTS_FETCH/COMMENTS_CLASSIFY/COMMENTS_ADAPTER/COMMENTS_UAT_INGEST/COMMENTS_APPLY/COMMENTS_REJECT/COMMENTS_TRIAGE) extends the T01-T03 ORCHESTRATOR_PROJECT_ROOT hermetic-test pattern to every fan-out point — lets verifiers stub the conversus adapter and the M013 UAT-ingest entry-point without modifying the real binaries (D007 reuse preservation)|adapter-missing as a routing verdict (not a failure) — non-executable COMMENTS_ADAPTER path lands ambiguous comments in human triage with conversus_verdict=adapter-missing diagnostic,mirroring the M013/FR-13 graceful-degradation contract at the comments seam|deterministic queue/triage filenames keyed on shasum-256(url)[:8] — lets idempotent re-runs overwrite-in-place rather than accumulate duplicates,asserted at the verifier seam by capturing pre/post filename sets across two runs|threshold default 0.8 read from comments.auto_apply_threshold.<class> in config.yml via awk YAML scalar walker (Bash 3.2 — no yq dependency); falls back to 0.8 default when key absent|spec-amendment auto-apply event scan added at the pipeline seam (belt-and-suspenders to the source-level scan in spec-amendment-human-gate.sh) — pipeline verifier asserts no comment_actioned row with class=spec-amendment AND action_taken=auto-apply-* ever lands in execution-log.jsonl,catching the runtime symptom even if the source scan ever drifts,config.yml comments: section appended after specify: section,additive — existing keys byte-preserved (verified via Edit-tool surgical insert)|references/spec-management.md new section appended after final P04 section (--amend Three-Case Semantics SC-14 invariant block) — every prior P04 heading and cross-reference still grep-asserted by m014-p03-references-section.sh as a byte-preservation proxy|bash32+lint omnibus enumerates target scripts dynamically (scripts/comments/*.sh + scripts/verify/m014-p03-*.sh excluding self) rather than via static list — picks up future verifiers automatically without omnibus edit|zero-prompts gate runs the four-class T04 fixture under hermetic ORCHESTRATOR_PROJECT_ROOT + GH_API_STUB to exercise the full classify --yes path including auto-apply + queue + triage routes (not just the entry point) — catches prompt leaks from any sub-script|phase-suite uses IFS-newline gate iteration with explicit IFS reset (precedent: m026-p03-phase-suite.sh) — Bash 3.2 portable replacement for arrays|dual-write --append-entry path leaves outside-marker bytes byte-identical (shasum confirmed pre=post for both CLAUDE.md and AGENTS.md) — uncommitted M026-close entry already in RC region is preserved untouched,only the new M014/P03 line prepends"
patterns_established:
  - "hermetic-test stub via env-var pointing at JSONL fixture (GH_API_STUB / GH_GRAPHQL_STUB) — operator gh path untouched,verifier never invokes real gh; per-surface source_surface filter on shared stub fixture preventing double-count when one fixture feeds both surfaces; FR-19 dry-run JSONL action records as the no-disk-write counterpart to actual cache writes,same iteration loop,single conditional branch — pattern reusable by T03 apply/reject; grep -F literal-string match on URL inside actioned.jsonl for safe dedup against URLs containing regex metacharacters,stdout-verdict + stderr-INFO split (machine-parseable verdict + human-readable rule trace); single-agent cooperative preset for refinement-only LLM calls (no red-blue deliberation when prior is already encoded); pre-existing fixture corpus reused as canonical four-class corpus with per-class mktemp split in verifier,patch -N forward-only stale-diff probe (replaces naive --dry-run that auto-reverses),ORCHESTRATOR_PROJECT_ROOT hermetic test hook reused across apply/reject/triage (T01/T02 precedent extended to T03),verifier self-exemption via path-scope (this verifier under scripts/verify/,scans scripts/comments/) — alternative to in-line literal-rewriting,queue-file frontmatter extraction via awk with gsub strip of surrounding double-quotes (matches T01/T02 awk patterns),env-overridable sub-script-path hermetic-test pattern (COMMENTS_* env vars) extends ORCHESTRATOR_PROJECT_ROOT to fan-out targets — reusable for any future master-pipeline script that delegates to multiple sub-scripts|non-executable adapter as a triage routing verdict — pattern for testing graceful-degradation paths without stubbing the real adapter binary (D007 reuse)|deterministic content-addressed filenames (shasum-256[:8] of canonical input) for idempotent queue/triage entries — pattern for any append-mostly workflow that needs to be replayable|two-tier SC-5 invariant verification (source-level grep in spec-amendment-human-gate.sh + runtime-event-shape assertion in pipeline+auto-apply verifiers) — defense-in-depth pattern for must-not-happen invariants,bash32+lint omnibus dynamic enumeration with self-exemption (scans scripts/comments/*.sh + scripts/verify/m014-p03-*.sh dynamically,strips full-line comments before regex scan,skips self by basename match) — reusable verifier shape for any future phase-close|zero-prompts hermetic scratch + fixture replay under --yes (mktemp scratch root + GH_API_STUB pointing at four-class fixture + COMMENTS_ADAPTER pointing at non-existent path → exercises auto-apply,queue,triage paths in one classify invocation,captures stdout+stderr,greps against M021 INPUT corpus + interactive-prompt regex) — pattern for SC-7 retest at any pipeline seam|outside-marker shasum invariant pre/post dual-write (awk-strip marker region → shasum stdin both before and after the helper write → assert equality) — formal verification of the SC-6a outside-bytes guarantee from M014/P01 FR-12|phase-suite orchestrator with IFS-newline iteration + per-gate rc capture + FAILED_GATES diagnostic accumulator (precedent: m014-p04-phase-suite.sh,m026-p03-phase-suite.sh) — Bash 3.2-portable replacement for arrays,emits both per-gate PASS/FAIL line and SUMMARY: ... pass=N fail=M tally"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P03/tasks/T01-fetch-SUMMARY.md, .orchestrator/milestones/M014/phases/P03/tasks/T02-classify-SUMMARY.md, .orchestrator/milestones/M014/phases/P03/tasks/T03-action-surfaces-SUMMARY.md, .orchestrator/milestones/M014/phases/P03/tasks/T04-pipeline-SUMMARY.md, .orchestrator/milestones/M014/phases/P03/tasks/T05-phase-close-SUMMARY.md"
duration: "170m"
verification_result: "pass"
completed_at: "2026-04-25T03:09:42Z"
observability_surfaces:
  - "execution-log.jsonl"
---

## What Was Built

P03 closes M014's original mission — wiki Giscus + GitHub Issue/PR comments now classify into one of four workflow actions (`uat-bug`, `decision-append`, `spec-amendment`, `ambiguous`) with the two trivial classes auto-applying above threshold, spec-amendments queued for human sign-off (CON-5/SC-5), and ambiguous comments routed through the M011/P07 conversus adapter with adapter-missing graceful-degradation to human triage. Five tasks, 14-gate phase suite all green.

**Core surface (FR-1, FR-8, FR-9, FR-10, FR-11)**:

- `commands/comments.md` — user-facing command with six subcommands (`classify`, `status`, `apply`, `reject`, `triage`, `reclassify`).
- `scripts/comments/fetch.sh` — Giscus + GitHub Issue/PR fetcher; JSONL inbox cache at `.orchestrator/comments/inbox/<id>.json`; idempotency via `actioned.jsonl` URL log; FR-19 dry-run manifest; hermetic via `GH_API_STUB` / `GH_GRAPHQL_STUB` env vars.
- `scripts/comments/classify.sh` — per-comment pure classifier with 10 regex/heuristic v1 rules (per D023); emits `class=<c> confidence=<f> reason=<r>` on stdout.
- `scripts/comments/apply.sh` — US-5 human-gated spec-amendment apply path; stale-diff refusal via `patch -N`; in-flight-conversus refusal; `rebuild-index.sh` hook; atomic actioned.jsonl row + comment_actioned event.
- `scripts/comments/reject.sh` + `scripts/comments/triage.sh` — rejection + human-triage bucket readers.
- `scripts/comments/comments.sh` — master pipeline; routes per class; threshold-gated auto-apply for `uat-bug` (via M013/FR-10 ingest when available) and `decision-append` (DECISIONS.md templated row); always-queue for `spec-amendment`; conversus-strict for `ambiguous` with `adapter-missing` triage fallback.
- `templates/conversus-presets/classify-comment.yml` — new preset for ambiguous-comment triage (D007 reuse; conversus adapter byte-identical pre/post P03).

**D023 regex/heuristic v1 pin**:
- Classifier shape pinned to regex/heuristic v1 baseline per D023 (2026-04-24) — SC-16 ≥1-week-inbox-dogfood preflight relaxed because wiki was deployed 2026-04-23 (one day before plan-phase). Retune trigger: ≥30 actioned comments OR ≥20% calibration divergence → follow-up D-row re-pins FR-9 shape. Rule set R1–R10 captured inline in `classify.sh` with coarse confidence steps (0.7–0.95 in 0.05–0.10 increments).
- Dogfood capture at `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` documents snapshot state, per-class baseline counts, and retune trigger — single source of truth cited from `commands/comments.md` + `references/spec-management.md`.

**Configuration (FR-17)**:
- `.orchestrator/config.yml` `comments:` section added: `auto_apply_threshold` per-class (uat-bug 0.8, decision-append 0.8, spec-amendment 1.0 per SC-5, ambiguous 1.0), `reply_on_apply: false` (OQ #C-8 v1), `fetch_schedule: manual` (OQ #C-2 v1).

**Documentation (SC-11 extension)**:
- `references/spec-management.md` gains `## Comment Classification & Workflow Routing` section; all P04 sections byte-preserved (verified by `m014-p03-references-section.sh`).

**Observability (FR-16)**:
- `comment_actioned` JSONL events emitted on every auto-apply with `{comment_url, class, confidence, action_taken, source_surface, timestamp}`.
- `unit_close` records carry `{comments_classified, comments_auto_applied, comments_queued, conversus_invocations, elapsed_ms, source: "runtime"}`.

## Key Decisions

- **Regex/heuristic v1 baseline (D023)** — FR-9 classifier shape pinned on the conservative end of OQ #C-1 (no LLM on primary path; ambiguous-only delegation to conversus). Retune-via-follow-up-D-row is the explicit escalation contract.
- **Conversus adapter zero modifications (D007)** — new `classify-comment` preset drops in without adapter changes; adapter file byte-identical pre/post P03.
- **Two-tier SC-5 invariant verification** — source-level grep in `m014-p03-spec-amendment-human-gate.sh` + runtime-event assertion in pipeline/auto-apply verifiers; defense-in-depth against future drift.
- **`patch -N` for stale-diff probe** — vanilla `patch --dry-run` silently auto-reverses previously-applied diffs (rc=0), masking staleness; `-N` forward-only refuses reverse-apply and is the operative US-5 AS-2 signal.
- **Adapter-missing as routing verdict** — non-executable conversus adapter lands ambiguous comments in human triage with `conversus_verdict=adapter-missing` rather than failing loudly; matches M013/FR-13 graceful-degradation at the comments seam.
- **Deterministic content-addressed queue/triage filenames** — `shasum-256(comment-url)[:8]`-keyed; re-runs overwrite-in-place rather than accumulate duplicates (CON-8).
- **Env-overridable sub-script paths** — `COMMENTS_FETCH`/`COMMENTS_CLASSIFY`/`COMMENTS_ADAPTER`/`COMMENTS_UAT_INGEST`/`COMMENTS_APPLY`/`COMMENTS_REJECT`/`COMMENTS_TRIAGE` extend the T01 `ORCHESTRATOR_PROJECT_ROOT` hermetic pattern to every fan-out point; lets verifiers stub the adapter + [M013](../../../../milestones/M013/index.md) UAT ingest without modifying real binaries (D007 reuse preservation).

## Cross-Cutting Patterns Established

- **Hermetic fetch via JSONL stub env-vars** (`GH_API_STUB` / `GH_GRAPHQL_STUB`) — verifiers never invoke real `gh`; same pattern reusable for any future GitHub API consumer.
- **Per-surface `source_surface` filter on shared fixture** — prevents double-count when one fixture feeds both surfaces in a verifier.
- **Pure-verdict classifier + imperative pipeline** — classify.sh is read-only/deterministic; the auto-apply / queue / triage decision lives in comments.sh. Keeps the invariant checkable at two seams.
- **Single-agent cooperative conversus preset** for refinement-only LLM calls (no red-blue when prior is already encoded by regex/heuristic).
- **`patch -N` forward-only stale probe** — canonical US-5-style idempotency check.
- **Deterministic content-addressed operational artifacts** — review-queue + triage files keyed on `shasum-256(url)[:8]`; trivially replayable.
- **Defense-in-depth must-not-happen invariant** — source-level grep + runtime-event-shape assertion; reusable for any SC-N that forbids a pattern.
- **Env-overridable sub-script paths for fan-out pipelines** — extends `ORCHESTRATOR_PROJECT_ROOT` to delegated scripts.
- **Dynamic-enumeration bash32+lint omnibus** — scans `scripts/comments/*.sh` + `scripts/verify/m014-p03-*.sh` at runtime rather than via static list; picks up future additions automatically; self-exempts via basename match.
- **Zero-prompts gate on hermetic scratch + fixture replay** — full classify pipeline exercised under `--yes` with adapter-missing stub to cover auto-apply + queue + triage routes in one invocation.
- **Outside-marker shasum invariant pre/post dual-write** — mechanical SC-6a verification during phase close; verifiable proxy for the FR-12 byte-preservation promise.

## Verification Results

**P03 phase suite**: 14/14 gates PASS, exit 0.

1. `m014-p03-fetch.sh` (T01)
2. `m014-p03-classify.sh` (T02)
3. `m014-p03-commands-md.sh` (T03)
4. `m014-p03-apply.sh` (T03)
5. `m014-p03-reject-triage.sh` (T03)
6. `m014-p03-spec-amendment-human-gate.sh` (T03 SC-5 invariant)
7. `m014-p03-pipeline.sh` (T04)
8. `m014-p03-auto-apply.sh` (T04)
9. `m014-p03-observability.sh` (T04)
10. `m014-p03-config-keys.sh` (T05)
11. `m014-p03-references-section.sh` (T05)
12. `m014-p03-dogfood-capture.sh` (T05)
13. `m014-p03-bash32-and-lint.sh` (T05 omnibus; 20 scripts scanned)
14. `m014-p03-zero-prompts.sh` (T05 SC-7)

**Cross-cutting invariants**:

- **SC-5 / CON-5 spec-amendment human-gate**: two-tier verification — source-level grep (no `auto-apply.*spec-amendment` pattern in any `scripts/comments/*.sh` except `apply.sh`) + runtime-event assertion (no `comment_actioned` event with `class=spec-amendment AND action_taken=auto-apply-*`).
- **SC-6a outside-marker byte-preservation**: CLAUDE.md + AGENTS.md outside-marker shasums byte-identical pre/post dual-write.
- **SC-7 zero-approval-prompt**: `comments classify --yes` under hermetic scratch produces zero approval-prompt-shaped strings ([M021](../../../../milestones/M021/index.md) corpus cross-check).
- **SC-9 Bash 3.2 + anti-pattern lint**: all new shell scripts pass both gates (20 scripts scanned).
- **SC-11 references/spec-management.md**: new Comment Classification section added; P04 sections byte-preserved.
- **SC-16 dogfood-data sizing**: captured at best-available signal per D023; retune trigger documented.
- **CON-4 conversus adapter reuse**: byte-identical pre/post P03 (D007).
- **CON-8 idempotency**: re-running classify on a clean slate produces deterministic queue + triage filenames keyed by URL shasum.
- **FR-16 observability**: `comment_actioned` + `unit_close` JSONL emitted to `.orchestrator/execution-log.jsonl`.

## Deviations Worth Surfacing

Each documented in its task summary; none affected cross-task contracts:

- **T01**: JSONL stubs filter by `source_surface` on shared fixture; plan step 7 `pass=8` reconciled by adding inbox-record-shape check.
- **T03**: `patch -N` replaces vanilla `patch --dry-run` for stale-diff probe (plan would have silently passed on re-applied diffs); additive `action_taken` field on actioned.jsonl rows.
- **T04**: env-overridable sub-script paths (`COMMENTS_*`) added for hermetic testability without D007 violation; additive `confidence` + `timestamp` fields on `comment_actioned` events; DECISIONS.md append guarded on file existence.
- **T01–T04 collectively**: side-fix at commit 4465b42 (auto-loop.sh accepts slug-bearing `T##-<slug>-PLAN.md` in `--step=V`) — caught during T01 dispatch when the literal-concat path constructor failed on `T01-fetch-PLAN.md`; every other consumer already globbed `T*-PLAN.md`.

No deviations affected the phase demo sentence or downstream phases' dependencies.

## State After P03

- `orchestrator:comments classify` runs end-to-end: fetch (hermetic-testable) → classify (regex/heuristic v1) → route per class (auto-apply | queue | triage) with FR-16 observability.
- Spec-amendment human-gate invariant (CON-5/SC-5) verified at two seams; mechanically impossible to auto-apply a spec-amendment via any script under `scripts/comments/` except the explicit `apply <queue-id>` manual path.
- `references/spec-management.md` + `commands/comments.md` cite `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` as the SSOT for the D023 retune trigger.
- Conversus adapter remains byte-identical (D007 reuse discipline preserved).
- M014 milestone is ready for validation + close. All four phases now shipped: P01 (create-path + minimal dual-write), P02 (full dual-write + drift detector), P04 (conversus auto-propose + probe + preset), P03 (classifier + apply-path). The bootstrapping loop closes: the next milestone's spec will be authored via `orchestrator:specify` + reviewed via `orchestrator:comments`.
