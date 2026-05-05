---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M032"
goal: "Close M032 by landing the additive scanner extensions (FR-17 proposals enumeration with `stage:` badge derivation; FR-18 `wiki.extra_dirs:` consumer-config honor; FR-19 `.orchestrator/knowledge/*.md` flat-file enumeration under `Knowledge — Flat`) on `scripts/wiki/wiki-scan-sources.sh` + `scripts/wiki/wiki-generate-nav.sh`; the FR-20 build-time code-shorthand decorator stub (US-8 P3 — surface exists, polish deferred to post-launch wiki-UX-deep proposal); the SC-8 / SC-9 / SC-11 acceptance scripts (scanner extensions; code decorator; `run-doctor.sh` no-warnings + `wiki-serve.sh` HTTP 200 self-application + `wiki-deploy-mutation` audit-trail presence); the SC-12 three-category acceptance battery aggregator (`tests/m032-acceptance/run-acceptance-battery.sh` modeled on M030/M031 with the MIT-001 `pass=N skip=M fail=K` exit-77 SKIP_REASON discipline); the SC-13 NNN derivation list captured in this plan body (per-script assertion-group counts summing to NNN ≥ 10 floor per MIT-004); the milestone-close ceremony (M032-VALIDATED marker, M032-SUMMARY.md referencing SC-1..SC-13 verdicts with signed-attestation block when SC-12 closed at skip=1, M032-ACCEPTANCE-EVIDENCE.md evidence ledger mirroring M030/M031 precedent, milestone-grain `unit_close` JSONL record); the P04 phase-suite aggregator + scope-guard mirroring P01/P02/P03 convention. Sibling-phase ship-shape gap (carried forward from P03 follow-ups): `wiki-init.sh` rejects `--with-wiki` as an unknown argument — P04 lands an in-flight repair that accepts the flag as a documented no-op (the flag is consumed by `init-project.sh`'s passthrough; wiki-init itself IS the wiki-init step, so `--with-wiki` is structurally redundant on the wiki-init.sh surface but operators chain it through unmodified per the FR-11 / MIT-011 surface contract; rejecting it surfaces a confusing fail in the dogfood `--with-wiki --with-giscus --deploy` chain). Preserve every prior phase's contracts: P01 byte-identical install at `mode: copy`, P02 wiki-init default scope + glossary + paired-launch seams + FR-6 self-application loop, P03 `--with-giscus` + `--deploy` four-step ordered sequence + FR-14 custom-nav region + AD-7 throwaway-fixture protocol + SC-5 live-deploy three-category exit semantics."
demo_sentence: "An operator on the orchestrator's own repo runs `bash scripts/wiki/wiki-scan-sources.sh --root .` and observes (a) all 25 entries under `.orchestrator/proposals/*.md` enumerated as `proposals:<basename>|.orchestrator/proposals/<file>|<title> [stage]` records emitted under a top-level `proposals:*` category, with the `stage:` badge derived from frontmatter `stage:` field (`stub | brief | specified | active | closed`) or `stage: unknown` for entries lacking the field — no exclusion (FR-17); (b) when `<consumer>/.orchestrator/config.yml` declares `wiki.extra_dirs: [specs/, decisions/]`, the scanner enumerates `<consumer>/specs/**/*.md` and `<consumer>/decisions/*.md` under `extra:specs` / `extra:decisions` categories, and when the config key is absent or empty the scanner emits zero `extra:*` records (no false-positive section per FR-18); (c) `.orchestrator/knowledge/*.md` flat files enumerated under a `knowledge-flat` category separate from the existing `knowledge:patterns|conventions|lessons` categorized records (FR-19 — current orchestrator repo has zero flat entries so the additive surface is a no-op against today's tree, exercised against a fixture). The operator runs the build-time code-shorthand decorator script `bash scripts/wiki/wiki-decorate-codes.sh --in <fixture-page>.md --glossary <fixture-glossary>.md --out <decorated>.md` against a fixture page containing `M032 + AP-009 + DR-STACK-001 + XYZ-999` and a glossary mapping the first three codes to titles, and observes the three known codes rewritten as `M032 (Wiki Distribution and Init Integration)`, `AP-009 (Compound chain)`, `DR-STACK-001 (Stack Decision)` linked to their definitions on first occurrence with subsequent occurrences as `[M032](...)` link-only and `XYZ-999` left byte-identical (FR-20 / SC-9). The operator runs `bash scripts/diagnostics/run-doctor.sh` against an `init --with-wiki --with-giscus --deploy`-bootstrapped fixture project and observes exit 0 with no `dead-infrastructure` or `unreferenced-asset` warnings (Constitution VIII); separately, `bash scripts/wiki/wiki-serve.sh --probe` against the orchestrator repo's own `wiki/` source tree exits 0 (closes the FR-6 self-application loop per MIT-002 — the `wiki-serve.sh --probe` mode is the port-free `mkdocs build --strict` health check inherited from P02's `m032-p02-wiki-serve-probe.sh` helper); and `jq '.[] | select(.event_type == \"wiki-deploy-mutation\")' .orchestrator/execution-log.jsonl` against the fixture project returns ≥ 1 record per MIT-008 (Constitution VI). The operator runs `bash tests/m032-acceptance/run-acceptance-battery.sh` and observes `BATTERY: pass=10 skip=1 fail=0` (three-category format per MIT-001 — pass counter NOT incremented on SC-5's exit-77 SKIP_REASON in unauthenticated CI; skip=1 acceptable only with the M032-SUMMARY.md signed-attestation block declaring SC-5 was executed in an authenticated environment and produced pass) OR `BATTERY: pass=11 skip=0 fail=0` when `gh auth status` is green at battery time. The operator runs `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/` and observes final line `VALIDATE: PASS — NNN/NNN checks passed` (NNN derived from this plan's per-script assertion-group sum). The `M032-VALIDATED` marker file is present at `.orchestrator/milestones/M032/M032-VALIDATED`; `M032-SUMMARY.md` is present and references SC-1..SC-13 verdicts (with the signed-attestation block if SC-12 closed at skip=1); `M032-ACCEPTANCE-EVIDENCE.md` is present and transcribes the green BATTERY line + per-SC roll-up + ISO-8601 timestamp + back-link to `tests/m032-acceptance/run-acceptance-battery.sh` per the M030/M031 evidence-ledger convention; one `unit_close` record at milestone-grain `{event_type: 'unit_close', unit: 'M032', timestamp: '<ISO8601Z>', verification_result: 'pass'}` is appended to `.orchestrator/milestones/M032/execution-log.jsonl`. `bash tools/verify/m032-p04-phase-suite.sh` emits `SUMMARY: m032-p04-phase-suite.sh pass=N fail=0` chaining all P04 sub-gates; `bash tools/verify/m032-p04-scope-guard.sh` emits the standard two-line `PASS: m032-p04 scope-guard ... / SUMMARY: m032-p04-scope-guard.sh pass=N fail=0` per the P01/P02/P03 baseline-ref convention with the captured baseline-ref at `tools/verify/fixtures/m032-p04-baseline-ref.txt`."
risk: "medium"
depends_on: ["P02", "P03"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ with
     m032-p04-* prefix to avoid collision with M030/M031/M032 P00–P03
     existing verifiers. Verifier scripts are co-authored alongside their
     corresponding artifact within the SAME task per plan-time discipline
     rule 2. -->

### Truths

- `scripts/wiki/wiki-scan-sources.sh` is amended additively to enumerate
  three new source families per FR-17 + FR-18 + FR-19. (a) FR-17 — every
  `.orchestrator/proposals/*.md` entry is emitted as a record with category
  prefix `proposals:<basename-without-extension>` (e.g. `proposals:M032-wiki-distribution-and-init-integration`),
  rel-path `proposals/<file>` (under `.orchestrator/`), and a `stage:` badge
  appended to the title field. The badge is derived from a YAML frontmatter
  `stage:` field (`stub | brief | specified | active | closed`); entries
  lacking the field render with `stage: unknown` (no exclusion per US-7
  AS-1). The badge appears as `<title> [stage]` in the title slot — e.g.
  `proposals:M032-wiki-distribution-and-init-integration|proposals/M032-wiki-distribution-and-init-integration.md|Wiki Distribution and Init Integration [active]`.
  Default-on; opt out via `--no-include-proposals` or
  `--include-proposals=false`. (b) FR-18 — when the consumer config at
  `<PROJECT_ROOT>/.orchestrator/config.yml` declares `wiki.extra_dirs:`
  as a YAML list (e.g. `wiki.extra_dirs: [specs/, decisions/]`), the
  scanner walks each declared dir relative to the project root and
  emits records with category prefix `extra:<dirname-without-trailing-slash>`
  (e.g. `extra:specs` / `extra:decisions`). Empty-or-absent
  `wiki.extra_dirs:` config produces zero `extra:*` records (no
  false-positive section). The walker uses `find <dir> -type f -name '*.md'`
  with `LC_ALL=C sort` for deterministic ordering. (c) FR-19 —
  `.orchestrator/knowledge/*.md` flat files (no category subdir, MEM-prefix
  not required) emit as `knowledge-flat|knowledge/<file>|<title>` records.
  This is additive to the existing `knowledge:patterns|conventions|lessons`
  categorized emission (M012/P02/T01 baseline). Today the orchestrator's
  own `.orchestrator/knowledge/` tree contains only a `reference/` subdir
  (no flat `*.md` files), so the additive surface is a no-op against the
  current orchestrator tree but exercises against a fixture. All three
  enumerations participate in the existing `should_exclude()` check (no
  `*PLANNING-PAYLOAD*`, no `*VERIFICATION*`, no `AGENTS.md`/`README.md`).
  - Check: `bash tools/verify/m032-p04-scanner-extensions.sh`

- `scripts/wiki/wiki-generate-nav.sh` is amended additively to render the
  three new category families as nav sections within the `# >>> auto-nav`
  region established by P03/T03's FR-14 region split. (a) `proposals:*`
  records render under a top-level `Proposals` nav section per #Q-5
  resolution at clarify (`Proposals` label, with a one-line introduction
  paragraph emitted as the section index page describing what the section
  is and how cross-company contributors comment on stage 1–3 entries).
  The section sorts entries by `proposals:<basename>` ascending. (b)
  `extra:<dirname>` records render under operator-configurable nav
  sections — one section per declared `extra_dirs:` entry, labeled
  by `Title-Case(<dirname>)` (e.g. `extra:specs` → `Specs`,
  `extra:decisions` → `Decisions` — note the latter would collide with
  the existing top:decisions surface; if the consumer's `wiki.extra_dirs:`
  declares `decisions/` and the collision matters in practice the
  consumer can rename their dir; v1 documents this as a known
  collision-edge-case in the section header comment). (c) `knowledge-flat`
  records render under a `Knowledge — Flat` section sibling to the
  existing categorized `Knowledge — Patterns` / `Knowledge — Conventions` /
  `Knowledge — Lessons` sections (the existing categorized sections are
  not modified — the new section is appended after them). All three new
  sections respect the auto-nav / custom-nav region split — they emit
  inside `# >>> auto-nav` and the custom-nav region is byte-preserved
  per FR-14 (US-5 AS-1).
  - Check: `bash tools/verify/m032-p04-nav-extensions.sh`

- `scripts/wiki/wiki-decorate-codes.sh` exists as a new build-time decorator
  per FR-20 (US-8 P3 stub-shaped per the spec — "shape it as a stub in
  M032 so the surface exists, defer the polish to post-launch
  wiki-UX-deep proposal"). The script's interface: `bash scripts/wiki/wiki-decorate-codes.sh
  --in <input-page>.md --glossary <glossary-page>.md --out <output-page>.md`.
  The script regex-scans the input page for the four documented patterns
  (`[A-Z]{2,4}-\d+`, `M\d{3}`, `DR-[A-Z]+-\d+`, `AP-\d+`), resolves each
  match against the glossary (parses `### TERM` headings + adjacent
  one-line definitions per US-6 format), and rewrites the first occurrence
  per page as `CODE (Title)` linked to the glossary anchor with subsequent
  occurrences rendered link-only `[CODE](#anchor)` (no title repeat per
  US-8 AS-2). Patterns matching the regex but unresolved against the
  glossary are left byte-identical (no broken-link noise per US-8 AS-1 +
  Finding G). When the `--glossary` argument is omitted or the file does
  not exist, the script falls back to scanning the codebase for `### CODE`
  definition patterns (best-effort) or skips decoration entirely with a
  debug-level diagnostic to stderr (US-8 AS-3). Single-script-file shape
  per AD-19; bash 3.2 compatible (per MEM001 — no `declare -A`, no
  process substitution; sed for the rewrite). Stub-shaped framing: the
  script implements the three US-8 acceptance scenarios correctly but
  ships with a deliberately narrow surface — no in-place rewrite of the
  full wiki tree (the operator runs the decorator manually against
  individual pages); no integration into `wiki-generate-nav.sh` or
  `mkdocs build` hooks (post-launch wiki-UX-deep work). The README/inline
  comments at the script head document the post-launch polish surface
  explicitly per Principle XIV (No Speculative Complexity).
  - Check: `bash tools/verify/m032-p04-decorator-shape.sh`

- `scripts/lifecycle/wiki-init.sh` is amended in-flight per the P03
  follow-up surfaced in T04 SC-5 dry-run: the case statement at line 50–79
  recognizes `--with-wiki` as a documented no-op (rather than rejecting it
  as `unknown argument` and exiting 2). The flag is structurally redundant
  on the `wiki-init.sh` surface — wiki-init IS the wiki-init step — but
  operators (and `init-project.sh`'s FR-11 passthrough) chain
  `--with-wiki --with-giscus --deploy` through to the script unchanged.
  Rejecting `--with-wiki` surfaces a confusing fail in the canonical
  `init --with-wiki --with-giscus --deploy` dogfood chain even though
  every other token in the chain is honored. The repair is two lines:
  add `--with-wiki) shift ;;` to the case statement (silently consuming
  the flag) and document it as "no-op on wiki-init.sh surface — accepted
  for FR-11 passthrough symmetry". This is the verifier-contract-over-
  verifier-skeleton in-flight repair convention extended from P03 (where
  P03/T01 + T02 + T03 + T05 each repaired sibling-phase verifier drift).
  - Check: `bash tools/verify/m032-p04-with-wiki-noop.sh`

- `tests/m032-acceptance/p0X-scanner-extensions.sh` (SC-8) exists, is
  executable, and exits 0 against the orchestrator's own repo and a
  fixture. Asserts: (a) FR-17 — running the scanner against `--root .`
  emits ≥ 1 `proposals:*` record AND every record's title field
  matches the regex `\[stage: (stub|brief|specified|active|closed|unknown)\]$`
  (or the equivalent `[<stage>]` shape per FR-17's title-slot definition);
  (b) FR-18 — given a temp-dir fixture with `<fixture>/.orchestrator/config.yml`
  containing `wiki.extra_dirs: [specs/, decisions/]` and at least one
  `*.md` file under `<fixture>/specs/` and `<fixture>/decisions/`,
  running the scanner against `--root <fixture>` emits ≥ 1 `extra:specs`
  AND ≥ 1 `extra:decisions` record; (c) FR-18 absence — given a fixture
  with no `wiki.extra_dirs:` config, the scanner emits ZERO `extra:*`
  records; (d) FR-19 — given a fixture with `<fixture>/.orchestrator/knowledge/foo.md`
  flat file present, the scanner emits ≥ 1 `knowledge-flat` record AND
  the existing `knowledge:patterns|conventions|lessons` categorized
  records continue to emit (no regression). The fixture is created
  under `/tmp/m032-p04-sc8-fixture-$$/` with trap-EXIT cleanup per the
  P03 / AD-7 throwaway-fixture pattern.
  - Check: `bash tools/verify/m032-p04-acceptance-shape-sc8.sh`

- `tests/m032-acceptance/p0X-code-decorator.sh` (SC-9) exists, is
  executable, and exits 0 against a fixture page + fixture glossary.
  Asserts: (a) US-8 AS-1 — write a temp page containing exactly
  `M032 + AP-009 + DR-STACK-001 + XYZ-999`; write a temp glossary
  with `### M032\n\nWiki Distribution and Init Integration\n\n###
  AP-009\n\nCompound chain\n\n### DR-STACK-001\n\nStack Decision`;
  run the decorator; assert the three known codes are rewritten as
  `M032 (Wiki Distribution and Init Integration)` /
  `AP-009 (Compound chain)` / `DR-STACK-001 (Stack Decision)` linked,
  AND `XYZ-999` is left byte-identical; (b) US-8 AS-2 — write a temp
  page containing `M032 mention M032 again`; run the decorator; assert
  the first occurrence is `M032 (Wiki Distribution and Init Integration)`
  linked AND the second occurrence is `M032` (link-only, no title
  repeat); (c) US-8 AS-3 — run the decorator with `--glossary` pointing
  at a non-existent file; assert exit 0 (no error, decorator falls back
  to debug-stderr and skips decoration); (d) cleanup — temp pages and
  glossaries are created under `/tmp/m032-p04-sc9-fixture-$$/` with
  trap-EXIT cleanup per the P03 / AD-7 throwaway-fixture pattern.
  - Check: `bash tools/verify/m032-p04-acceptance-shape-sc9.sh`

- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` (SC-11) exists, is
  executable, and exits 0. Asserts (per MIT-002 + MIT-008 amendments):
  (a) Constitution VIII — running `bash scripts/diagnostics/run-doctor.sh`
  against an `init --with-wiki --with-giscus --deploy`-bootstrapped
  fixture project exits 0 AND the stdout output contains zero lines
  matching the regex `(dead-infrastructure|unreferenced-asset)`. The
  fixture is the P01 shared `tests/fixtures/m032-fresh-project-fixture/`
  pre-bootstrapped via the `--with-giscus` stub envelope
  `M032_GISCUS_IDS_FROM_GH_STUB=1` and the `--deploy` stub envelope
  `M032_DEPLOY_GH_API_STUB=1` to avoid live-network dependence. (b)
  FR-6 self-application loop closure per MIT-002 — running
  `bash scripts/wiki/wiki-serve.sh --probe` against the orchestrator
  repo's own `wiki/` source tree exits 0. The `--probe` mode is the
  port-free `mkdocs build --strict` health check inherited from P02's
  `m032-p02-wiki-serve-probe.sh` helper. (c) MIT-008 audit-trail
  presence — after the stubbed `--deploy` step completes, the fixture's
  `<fixture>/.orchestrator/execution-log.jsonl` contains ≥ 1 NDJSON
  record matching `"event_type":"wiki-deploy-mutation"` AND the record
  carries `"result":"success"`. The check uses a `grep -c` count under
  `set -uo pipefail` with `|| true` fallback per the P02 patterns-
  established gotcha. The script does NOT depend on `jq` (uses
  pure `grep -F` substring checks) — `jq` availability is a soft
  dependency for operator-side inspection, not for automated SC-11
  verification.
  - Check: `bash tools/verify/m032-p04-acceptance-shape-sc11.sh`

- `tests/m032-acceptance/run-acceptance-battery.sh` (SC-12) exists, is
  executable, implements the three-category exit-code semantics per
  MIT-001 (pass=0 / skip=77 / fail=other-non-zero), and emits the final
  line `BATTERY: pass=N skip=M fail=K` (the three-counter shape, not
  the M030/M031 two-counter `pass=N fail=M` shape). The runner chains
  the eleven SC verifiers in literal sequence (SC-1, SC-2, SC-3, SC-4,
  SC-5, SC-6, SC-7, SC-8, SC-9, SC-10, SC-11), each invoked as
  `bash <path>` per AD-19 single-script-file shape with `rc` captured
  per-call. A `run_sc()` helper maps `rc` to the three counters: rc==0
  → pass++; rc==77 → skip++ AND emit `BATTERY-SKIP: <label> (<path>)
  SKIP_REASON: <reason>`; other-non-zero → fail++ AND emit
  `BATTERY-FAIL: <label> (<path>) exited <rc>`. The aggregator inherits
  the M030/M031 shape (`set -uo pipefail` + `bash <path>` literal-
  sequence + final `BATTERY:` envelope) and extends with the three-
  category mapping per MIT-001. Exit code: 0 if `fail=0` (skip>=0
  acceptable); non-zero if `fail>0`. The acceptance scripts referenced
  are the spec-mandated paths from SC-1..SC-11 — the `p0X-` prefixes
  on three of them (`p0X-glossary-surface.sh`, `p0X-scanner-extensions.sh`,
  `p0X-code-decorator.sh`, `p0X-staged-dirs-collision.sh` — actually
  shipped under various p01-/p02-/etc. concrete prefixes per the
  per-phase plan-phase phase-placement decisions; the runner uses the
  concrete on-disk paths).
  - Check: `bash tools/verify/m032-p04-acceptance-battery-shape.sh`

- The SC-13 NNN derivation list is captured in this plan body (below,
  in the `## SC-13 NNN Derivation` section) per MIT-004 — the list
  enumerates per-script assertion-group counts summing to NNN ≥ 10
  floor (MIT-004 non-negotiable). Each acceptance script's count is
  the number of distinct `assert_*` / `check_*` calls in the script
  body (or equivalent `[ ... ] || fail` / `if ! ... fail` test
  expressions). The list is the audit-trace `validate-milestone.sh M032`
  reports against. NNN = 10 is the floor; the actual NNN is computed
  per the per-script counts below (current shipped value: see the
  derivation table). `bash scripts/verify/validate-milestone.sh
  .orchestrator/milestones/M032/` reports `VALIDATE: PASS — NNN/NNN
  checks passed` with NNN matching the derivation-table sum.
  - Check: `bash tools/verify/m032-p04-validate-milestone.sh`

- `M032-VALIDATED` marker file present at `.orchestrator/milestones/M032/M032-VALIDATED`
  AND `M032-SUMMARY.md` present at `.orchestrator/milestones/M032/M032-SUMMARY.md`
  referencing SC-1..SC-13 verdicts (with the signed-attestation block
  if SC-12 closed at `skip=1` — the block declares "SC-5 was executed
  in an authenticated environment and produced pass" with operator
  signature line, ISO-8601 timestamp, and gh `<owner>/<ts>-m032-fixture`
  fixture name) per MIT-001 + SC-14. The `M032-VALIDATED` marker creation
  is conditioned on SC-12's `skip=0` outcome OR the attestation block.
  AND `.orchestrator/milestones/M032/execution-log.jsonl` contains one
  `unit_close` record at milestone-grain with shape `{event_type: 'unit_close',
  unit: 'M032', timestamp: '<ISO8601Z>', verification_result: 'pass'}`
  appended at the milestone-close moment.
  - Check: `bash tools/verify/m032-p04-milestone-close-ceremony.sh`

- `M032-ACCEPTANCE-EVIDENCE.md` present at `.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`
  per the M030/M031 evidence-ledger convention. The ledger is the
  operator-facing transcription of the green BATTERY line + per-SC
  roll-up (SC-1 verdict + verifier path + last-run timestamp; repeated
  for SC-2..SC-13) + ISO-8601 timestamp + back-link to
  `tests/m032-acceptance/run-acceptance-battery.sh`. The format mirrors
  `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md` and
  `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` byte-for-
  byte where structurally possible.
  - Check: `bash tools/verify/m032-p04-acceptance-evidence-ledger.sh`

- `tools/verify/m032-p04-phase-suite.sh` exists, is executable, invokes
  every P04 sub-gate in dependency order, exits 0 iff every sub-gate
  passes, and emits a single line `SUMMARY: m032-p04-phase-suite.sh
  pass=N fail=M` before exit. The suite chains, in order:
  `m032-p04-scanner-extensions.sh`, `m032-p04-nav-extensions.sh`,
  `m032-p04-decorator-shape.sh`, `m032-p04-with-wiki-noop.sh`,
  `m032-p04-acceptance-shape-sc8.sh`, `m032-p04-acceptance-shape-sc9.sh`,
  `m032-p04-acceptance-shape-sc11.sh`,
  `m032-p04-acceptance-battery-shape.sh`,
  `m032-p04-validate-milestone.sh`,
  `m032-p04-milestone-close-ceremony.sh`,
  `m032-p04-acceptance-evidence-ledger.sh`. Eleven sub-gates plus the
  suite line. Single-script-file shape per AD-19. Mirrors the M032
  P02/P03 phase-suite-aggregator pattern.
  - Check: `bash tools/verify/m032-p04-phase-suite.sh`

- The SC-13 / scope-guard invariant holds for the P04 diff: P04 modifies
  only files declared in this phase's "Files Likely Touched" list. None
  of `packaging/install/install-{claude-code,codex,cursor}.sh` (P01),
  `packaging/bundle/manifest.yml` (P01 / P02), `commands/init.md` (P02),
  `scripts/lifecycle/init-project.sh` (P02), the P02 paired-launch seam
  scripts at `tests/paired-m032-m033/seam-{A,B,C}.sh` (P02),
  `wiki/glossary.md` (P02), `scripts/knowledge/lookup-mems.sh` (P02),
  `scripts/wiki/wiki-deploy.sh` (P03 — note: P04 does NOT amend
  wiki-deploy.sh; the FR-10 cwd-vs-`repo_url:` gate is P03's surface),
  `wiki/overrides/partials/comments.html` (P03), or `references/installation.md`
  (P03) is touched by P04. The single sibling-phase exception is
  `scripts/lifecycle/wiki-init.sh` — P02 created it, P03 amended it
  for `--with-giscus` + `--deploy` scopes, and P04 amends it again
  in-flight for the `--with-wiki` no-op acceptance (the case statement
  receives one new arm). This is the in-flight repair convention
  established in P03 and is allowlisted in P04's scope-guard.
  - Check: `bash tools/verify/m032-p04-scope-guard.sh`

### Artifacts

- `scripts/wiki/wiki-scan-sources.sh` (existing-baseline modify, contains "FR-17", contains "FR-18", contains "FR-19", contains "proposals:", contains "extra:", contains "knowledge-flat", contains "wiki.extra_dirs", contains "stage:", contains "include-proposals") — modify
- `scripts/wiki/wiki-generate-nav.sh` (existing-baseline modify, contains "FR-17", contains "FR-18", contains "FR-19", contains "Proposals", contains "Knowledge — Flat", contains "extra:") — modify
- `scripts/wiki/wiki-decorate-codes.sh` (min 80 lines, contains "FR-20", contains "US-8", contains "--in", contains "--glossary", contains "--out", contains "[A-Z]{2,4}", contains "M\\\\d{3}", contains "DR-", contains "AP-", contains "stub-shaped") — create
- `scripts/lifecycle/wiki-init.sh` (existing-baseline modify, contains "--with-wiki", contains "no-op on wiki-init.sh surface", contains "FR-11 passthrough symmetry") — modify
- `tests/m032-acceptance/p0X-scanner-extensions.sh` (min 80 lines, contains "SC-8", contains "FR-17", contains "FR-18", contains "FR-19", contains "wiki.extra_dirs", contains "proposals:", contains "extra:specs", contains "knowledge-flat", contains "stage:", contains "trap") — create
- `tests/m032-acceptance/p0X-code-decorator.sh` (min 60 lines, contains "SC-9", contains "FR-20", contains "US-8", contains "wiki-decorate-codes.sh", contains "M032", contains "AP-009", contains "DR-STACK-001", contains "XYZ-999", contains "trap") — create
- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` (min 80 lines, contains "SC-11", contains "MIT-002", contains "MIT-008", contains "run-doctor.sh", contains "wiki-serve.sh", contains "--probe", contains "wiki-deploy-mutation", contains "dead-infrastructure", contains "unreferenced-asset", contains "M032_GISCUS_IDS_FROM_GH_STUB", contains "M032_DEPLOY_GH_API_STUB", contains "trap") — create
- `tests/m032-acceptance/run-acceptance-battery.sh` (min 80 lines, contains "BATTERY:", contains "MIT-001", contains "SKIP_REASON", contains "exit 77", contains "pass=", contains "skip=", contains "fail=", contains "SC-1", contains "SC-11", contains "set -uo pipefail") — create
- `.orchestrator/milestones/M032/M032-VALIDATED` (min 1 lines, contains "M032") — create
- `.orchestrator/milestones/M032/M032-SUMMARY.md` (min 50 lines, contains "schema_version", contains "type: milestone-summary", contains "id: \"M032\"", contains "SC-1", contains "SC-13", contains "verification_result: \"pass\"") — create
- `.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md` (min 30 lines, contains "BATTERY:", contains "SC-1", contains "SC-11", contains "run-acceptance-battery.sh") — create
- `tools/verify/m032-p04-scanner-extensions.sh` (min 40 lines, contains "wiki-scan-sources.sh", contains "FR-17", contains "FR-18", contains "FR-19", contains "proposals:", contains "extra:", contains "knowledge-flat") — create
- `tools/verify/m032-p04-nav-extensions.sh` (min 30 lines, contains "wiki-generate-nav.sh", contains "Proposals", contains "Knowledge — Flat", contains "FR-17", contains "FR-18", contains "FR-19") — create
- `tools/verify/m032-p04-decorator-shape.sh` (min 30 lines, contains "wiki-decorate-codes.sh", contains "FR-20", contains "US-8", contains "--in", contains "--glossary", contains "--out") — create
- `tools/verify/m032-p04-with-wiki-noop.sh` (min 20 lines, contains "wiki-init.sh", contains "--with-wiki", contains "no-op", contains "FR-11") — create
- `tools/verify/m032-p04-acceptance-shape-sc8.sh` (min 25 lines, contains "p0X-scanner-extensions.sh", contains "SC-8", contains "FR-17", contains "FR-18", contains "FR-19") — create
- `tools/verify/m032-p04-acceptance-shape-sc9.sh` (min 25 lines, contains "p0X-code-decorator.sh", contains "SC-9", contains "FR-20", contains "US-8") — create
- `tools/verify/m032-p04-acceptance-shape-sc11.sh` (min 30 lines, contains "sc11-doctor-no-warnings.sh", contains "SC-11", contains "run-doctor.sh", contains "wiki-serve.sh", contains "wiki-deploy-mutation") — create
- `tools/verify/m032-p04-acceptance-battery-shape.sh` (min 30 lines, contains "run-acceptance-battery.sh", contains "BATTERY:", contains "MIT-001", contains "SKIP_REASON", contains "exit 77", contains "skip=") — create
- `tools/verify/m032-p04-validate-milestone.sh` (min 25 lines, contains "validate-milestone.sh", contains "M032", contains "VALIDATE:", contains "MIT-004") — create
- `tools/verify/m032-p04-milestone-close-ceremony.sh` (min 40 lines, contains "M032-VALIDATED", contains "M032-SUMMARY.md", contains "unit_close", contains "execution-log.jsonl", contains "SC-14") — create
- `tools/verify/m032-p04-acceptance-evidence-ledger.sh` (min 25 lines, contains "M032-ACCEPTANCE-EVIDENCE.md", contains "BATTERY:", contains "SC-1", contains "SC-13") — create
- `tools/verify/m032-p04-phase-suite.sh` (min 60 lines, contains "SUMMARY:", contains "m032-p04-scanner-extensions", contains "m032-p04-acceptance-evidence-ledger", contains "m032-p04-phase-suite") — create
- `tools/verify/m032-p04-scope-guard.sh` (min 60 lines, contains "packaging/install/install-claude-code.sh", contains "packaging/bundle/manifest.yml", contains "wiki/glossary.md", contains "scripts/knowledge/lookup-mems.sh", contains "scripts/wiki/wiki-deploy.sh", contains "wiki/overrides/partials/comments.html", contains "references/installation.md", contains "SC-13") — create
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` (min 1 lines) — create (captured by T05 per the M032 P01/P02/P03 baseline-ref convention)

### Key Links

- `scripts/wiki/wiki-scan-sources.sh` → `.orchestrator/proposals/` (FR-17 — scanner enumerates the proposals tree)
- `scripts/wiki/wiki-scan-sources.sh` → `.orchestrator/knowledge/` (FR-19 — scanner enumerates flat-knowledge files)
- `scripts/wiki/wiki-generate-nav.sh` → `scripts/wiki/wiki-scan-sources.sh` (FR-17 / FR-18 / FR-19 — generator consumes the new category families from the scanner output)
- `scripts/wiki/wiki-decorate-codes.sh` → `wiki/glossary.md` (FR-20 — decorator's primary lookup source per US-6)
- `tests/m032-acceptance/p0X-scanner-extensions.sh` → `scripts/wiki/wiki-scan-sources.sh` (SC-8 invokes the scanner against orchestrator + fixture)
- `tests/m032-acceptance/p0X-code-decorator.sh` → `scripts/wiki/wiki-decorate-codes.sh` (SC-9 invokes the decorator against fixture pages)
- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` → `scripts/diagnostics/run-doctor.sh` (SC-11 invokes doctor against bootstrapped fixture)
- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` → `scripts/wiki/wiki-serve.sh` (SC-11 invokes wiki-serve --probe against orchestrator's own wiki/)
- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` → `scripts/lifecycle/wiki-init.sh` (SC-11 stub-bootstraps the fixture via wiki-init --with-wiki --with-giscus --deploy)
- `tests/m032-acceptance/run-acceptance-battery.sh` → `tests/m032-acceptance/p01-managed-bundle-shape.sh` (battery chains SC-1)
- `tests/m032-acceptance/run-acceptance-battery.sh` → `tests/m032-acceptance/sc11-doctor-no-warnings.sh` (battery chains SC-11)
- `.orchestrator/milestones/M032/M032-SUMMARY.md` → `tests/m032-acceptance/run-acceptance-battery.sh` (SC-14 milestone summary references the battery as the verification surface)
- `.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md` → `tests/m032-acceptance/run-acceptance-battery.sh` (evidence ledger back-links to the runner per M030/M031 convention)
- `tools/verify/m032-p04-phase-suite.sh` → `tools/verify/m032-p04-scanner-extensions.sh` (suite invokes the FR-17/18/19 gate first)
- `tools/verify/m032-p04-phase-suite.sh` → `tools/verify/m032-p04-acceptance-evidence-ledger.sh` (suite invokes the evidence-ledger gate last)

## SC-13 NNN Derivation

Per MIT-004, the planner-task-breakdown MUST include a numbered list of
per-script assertion-group counts summing to NNN ≥ 10 floor. NNN is the
audit-trace `validate-milestone.sh M032` reports against. The list below
enumerates the eleven SC-mapped acceptance scripts (SC-1..SC-11) by
on-disk path and the assertion-group count derived from each script's
shipped acceptance scenarios. SC-12 (the battery aggregator), SC-13
(this derivation table), and SC-14 (milestone-close ceremony) are
verification surfaces themselves and do not contribute to the NNN sum.

| # | SC | On-disk path                                                     | Assertion-group count |
|---|----|------------------------------------------------------------------|----------------------:|
| 1 | SC-1  | `tests/m032-acceptance/p01-managed-bundle-shape.sh`              | 4 (US-1 AS-1..AS-4) |
| 2 | SC-2  | `tests/m032-acceptance/p01-symlink-mode.sh`                      | 2 (US-1 AS-3 + AS-4) |
| 3 | SC-3  | `tests/m032-acceptance/p02-wiki-init-default-scope.sh`           | 5 (US-2 AS-1..AS-5) |
| 4 | SC-4  | `tests/m032-acceptance/p02-wiki-init-with-giscus.sh`             | 6 (FR-7 + FR-8 happy + FR-8 verifier + FR-8 failure + FR-8 idempotency + FR-8 overwrite) |
| 5 | SC-5  | `tests/m032-acceptance/p03-wiki-init-deploy-live.sh`             | 8 (gh auth precond + fixture create + invoke + URL 200 + data-repo + audit + teardown + post-teardown invariants) |
| 6 | SC-6  | `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh`   | 4 (FR-14 AS-1..AS-3 + MIT-005 non-empty migration) |
| 7 | SC-7  | `tests/m032-acceptance/p02-glossary-surface.sh`                  | 4 (US-6 AS-1..AS-4) |
| 8 | SC-8  | `tests/m032-acceptance/p0X-scanner-extensions.sh`                | 4 (FR-17 + FR-18 present + FR-18 absence + FR-19) |
| 9 | SC-9  | `tests/m032-acceptance/p0X-code-decorator.sh`                    | 3 (US-8 AS-1 + AS-2 + AS-3) |
| 10 | SC-10 | `tests/m032-acceptance/p01-staged-dirs-collision.sh`            | 2 (no-collision + collision branches) |
| 11 | SC-11 | `tests/m032-acceptance/sc11-doctor-no-warnings.sh`              | 3 (Constitution VIII doctor + MIT-002 wiki-serve self + MIT-008 audit-trail) |

**NNN = 4 + 2 + 5 + 6 + 8 + 4 + 4 + 4 + 3 + 2 + 3 = 45**

NNN = 45 satisfies the MIT-004 floor (NNN ≥ 10). The actual count
`validate-milestone.sh M032` reports against is the framework-owned
checks (phase-summary existence + boundary-map produces presence +
cross-phase consumes-met-by-produces) per the existing
`scripts/verify/validate-milestone.sh` shape — 45 here is the planning-
declared assertion-group sum that becomes audit-traceable in the
M032-SUMMARY.md SC-13 verdict block. The two counts are independent
verification surfaces; both must pass at milestone close.

(Note on FR-22 / SC-10 nomenclature: SC-10 in the spec verifies FR-22
via `tests/m032-acceptance/p01-staged-dirs-collision.sh`. The on-disk
path uses `p01-` prefix because P01 owns the artifact creation; SC-10
verifies a P01-shipped surface and contributes 2 to NNN.)

## Tasks

### T01: FR-17 + FR-18 + FR-19 scanner extensions on `wiki-scan-sources.sh` + `wiki-generate-nav.sh` + SC-8 acceptance script

See `tasks/T01-scanner-extensions-PLAN.md`.

T01 lands the additive scanner enumerations and their nav-generator
counterparts that surface the proposals tree, the consumer-configurable
`extra_dirs` paths, and the flat-knowledge files in the rendered wiki.
It (a) amends `scripts/wiki/wiki-scan-sources.sh` to emit `proposals:*`
records (one per `.orchestrator/proposals/*.md` with `stage:` badge
derived from frontmatter or `unknown` fallback), `extra:<dirname>`
records (when `<PROJECT_ROOT>/.orchestrator/config.yml` declares
`wiki.extra_dirs:`), and `knowledge-flat` records (when
`.orchestrator/knowledge/*.md` flat files are present); each enumeration
participates in the existing `should_exclude()` check; new flags
`--include-proposals` (default-on, with `--no-include-proposals` opt-out)
follow the FR-15 `--include-glossary` convention; (b) amends
`scripts/wiki/wiki-generate-nav.sh` to render the three new category
families as nav sections inside the `# >>> auto-nav` region established
by P03/T03 — `Proposals` section with introduction-paragraph index page
per #Q-5; per-`extra_dirs` operator-configurable sections; `Knowledge —
Flat` section sibling to the existing categorized knowledge sections;
(c) authors `tests/m032-acceptance/p0X-scanner-extensions.sh` (SC-8)
exercising the four FR-17/18/19 branches against the orchestrator's
own repo (FR-17 — 25 proposals enumerated) and a temp-dir fixture
(FR-18 + FR-19); (d) ships verifier scripts
`tools/verify/m032-p04-scanner-extensions.sh`,
`tools/verify/m032-p04-nav-extensions.sh`, and
`tools/verify/m032-p04-acceptance-shape-sc8.sh`.

### T02: FR-20 code-shorthand decorator stub + SC-9 acceptance script + `--with-wiki` no-op in-flight repair

See `tasks/T02-decorator-and-with-wiki-noop-PLAN.md`.

T02 lands the FR-20 build-time code-shorthand decorator (US-8 P3 stub
per the spec — surface exists, polish deferred to post-launch
wiki-UX-deep proposal) and the in-flight repair to `wiki-init.sh`
accepting `--with-wiki` as a documented no-op (carried forward from
the P03 follow-up). It (a) creates `scripts/wiki/wiki-decorate-codes.sh`
implementing the `--in <input> --glossary <glossary> --out <output>`
interface, regex-scanning for `[A-Z]{2,4}-\d+` / `M\d{3}` /
`DR-[A-Z]+-\d+` / `AP-\d+`, resolving against the glossary's
`### TERM` headings + adjacent one-line definitions per US-6 format,
rewriting first-occurrence-per-page as `CODE (Title)` linked and
subsequent occurrences as link-only, leaving unresolved patterns
byte-identical (single-script-file shape per AD-19; bash 3.2
compatible per MEM001); (b) authors `tests/m032-acceptance/p0X-code-decorator.sh`
(SC-9) exercising US-8 AS-1 (three known + one unknown), AS-2 (first
occurrence titled, subsequent link-only), AS-3 (missing-glossary
fallback) against `/tmp/m032-p04-sc9-fixture-$$/` with trap-EXIT
cleanup; (c) amends `scripts/lifecycle/wiki-init.sh`'s case statement
with `--with-wiki) shift ;;` consuming the flag silently with a
documenting inline comment naming the FR-11 passthrough symmetry
rationale; (d) ships verifier scripts
`tools/verify/m032-p04-decorator-shape.sh`,
`tools/verify/m032-p04-acceptance-shape-sc9.sh`, and
`tools/verify/m032-p04-with-wiki-noop.sh`.

### T03: SC-11 doctor-no-warnings + wiki-serve self-application + audit-trail acceptance script

See `tasks/T03-sc11-doctor-and-self-application-PLAN.md`.

T03 lands the SC-11 acceptance script that closes the FR-6
self-application loop per MIT-002 and verifies the MIT-008 audit-trail
presence after a stubbed `--deploy` run. It authors
`tests/m032-acceptance/sc11-doctor-no-warnings.sh` with three assertion
groups: (a) Constitution VIII — running `bash scripts/diagnostics/run-doctor.sh`
against an `init --with-wiki --with-giscus --deploy`-bootstrapped
fixture exits 0 AND stdout has zero `dead-infrastructure` /
`unreferenced-asset` warnings; (b) MIT-002 — running `bash
scripts/wiki/wiki-serve.sh --probe` against the orchestrator repo's
own `wiki/` source tree exits 0 (port-free `mkdocs build --strict`
health check inherited from P02's helper); (c) MIT-008 — after the
stubbed `--deploy` step completes, the fixture's
`<fixture>/.orchestrator/execution-log.jsonl` contains ≥ 1 NDJSON
record matching `"event_type":"wiki-deploy-mutation"` AND
`"result":"success"`. The fixture is the P01 shared
`tests/fixtures/m032-fresh-project-fixture/` pre-bootstrapped via the
`M032_GISCUS_IDS_FROM_GH_STUB=1` and `M032_DEPLOY_GH_API_STUB=1`
envelopes to avoid live-network dependence. T03 ships verifier
`tools/verify/m032-p04-acceptance-shape-sc11.sh`.

### T04: SC-12 three-category acceptance battery aggregator

See `tasks/T04-acceptance-battery-PLAN.md`.

T04 lands the SC-12 acceptance battery aggregator at
`tests/m032-acceptance/run-acceptance-battery.sh` — the milestone-grain
verifier modeled on `tests/m030-acceptance/run-acceptance-battery.sh`
and `tests/m031-acceptance/run-acceptance-battery.sh`, extended with
the MIT-001 three-category exit-code semantics (pass=0 / skip=77 /
fail=other-non-zero). It (a) authors the runner script with
`set -uo pipefail`, the `run_sc()` helper mapping `rc` to the three
counters, and the eleven SC verifier invocations in literal sequence
(SC-1..SC-11) per AD-19 single-script-file shape; (b) emits the final
line `BATTERY: pass=N skip=M fail=K` and exits 0 iff `fail=0`; (c)
ships verifier `tools/verify/m032-p04-acceptance-battery-shape.sh`
asserting the aggregator's shape (file present, executable, contains
the SKIP_REASON branch, contains the three counters, contains all
eleven SC labels, exits 0 when invoked under M032_ACCEPTANCE_BATTERY_DRY=1
test-only env-var that bypasses the actual SC invocations and just
emits a stub `BATTERY: pass=0 skip=11 fail=0` for shape verification).

### T05: Milestone close ceremony + P04 phase-suite + scope-guard

See `tasks/T05-milestone-close-and-phase-suite-PLAN.md`.

T05 lands the M032 milestone-close ceremony and the P04
verification-aggregation surface that ties P04 closed. It (a) authors
`.orchestrator/milestones/M032/M032-SUMMARY.md` per the `templates/`
phase/milestone-summary shape with the 16-field `observability_surfaces`-
extended frontmatter, references SC-1..SC-13 verdicts in the body
(with the signed-attestation block if SC-12 closed at `skip=1`), and
captures the milestone narrative mirroring M030/M031's format (5
phases, what shipped, key decisions, patterns established, deviations
handled, verification at close, forward-pointing notes); (b) creates
the marker file `.orchestrator/milestones/M032/M032-VALIDATED`
conditioned on the SC-12 outcome (skip=0 OR signed-attestation block);
(c) appends the milestone-grain `unit_close` JSONL record
`{event_type: 'unit_close', unit: 'M032', timestamp: '<ISO8601Z>',
verification_result: 'pass'}` to
`.orchestrator/milestones/M032/execution-log.jsonl`; (d) authors
`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md` per the
M030/M031 evidence-ledger convention transcribing the green BATTERY
line + per-SC roll-up + ISO-8601 timestamp + back-link to the runner;
(e) authors `tools/verify/m032-p04-validate-milestone.sh` invoking
`bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/`
and asserting the final `VALIDATE: PASS` line; (f) authors
`tools/verify/m032-p04-milestone-close-ceremony.sh` asserting the
marker file + summary file + `unit_close` JSONL record presence; (g)
authors `tools/verify/m032-p04-acceptance-evidence-ledger.sh` asserting
the evidence ledger's shape; (h) authors
`tools/verify/m032-p04-phase-suite.sh` chaining all eleven P04 sub-gates
in dependency order per AD-19 single-script-file shape; (i) authors
`tools/verify/m032-p04-scope-guard.sh` asserting P04's diff is confined
to the declared "Files Likely Touched" list with the M032 P01/P02/P03
baseline-ref convention (allowlist of P04-owned paths + denylist of
P00/P01/P02/P03-owned paths + first-run baseline-ref capture at
`tools/verify/fixtures/m032-p04-baseline-ref.txt`).

## Task Dependencies

```
T01 ──→ T05
T02 ──→ T05
T03 ──→ T04 ──→ T05
```

Rationale: T01 (scanner extensions + SC-8), T02 (decorator + SC-9 + 
`--with-wiki` no-op), and T03 (SC-11) are independent on the production-
side surface — none reads files created by another. T04 (acceptance
battery) consumes the SC-1..SC-11 scripts as references in the runner
body but does NOT read their file contents at authoring time (the
runner shells out to `bash <path>` at run time, and the script paths
are spec-mandated literals); T04 must follow T03 only because SC-11's
script must exist on disk before the battery's allowlist references it
(plan-time discipline rule 2). T05 must run after T01–T04 land because
the phase-suite aggregator references all eleven verifier paths, the
scope-guard's allowlist must reflect the final touched-files set, the
M032-SUMMARY.md narrative reports what shipped across all four prior
tasks, and the M032-ACCEPTANCE-EVIDENCE.md transcribes the BATTERY
line that T04 produces.

In-flight repair note: T02's `--with-wiki` no-op amendment to
`scripts/lifecycle/wiki-init.sh` is the only sibling-phase-deliverable
modification in P04 (P02 created the file; P03 amended for `--with-giscus`
+ `--deploy`). The amendment is two lines (one case arm + one comment)
and does NOT regress any P02/P03 verifier — the case statement rejects
unknown args with exit 2; adding a recognized arm strictly widens the
accepted-flag set. T02's verifier
`tools/verify/m032-p04-with-wiki-noop.sh` confirms the no-op behavior
without exercising any P02/P03 contract. This in-flight repair pattern
is canonical per the P03 patterns-established lesson (P03/T01 +
T02 + T03 + T05 each repaired sibling-phase verifier drift).

## Files Likely Touched

- `scripts/wiki/wiki-scan-sources.sh` (modify — additive FR-17/18/19 enumerations)
- `scripts/wiki/wiki-generate-nav.sh` (modify — additive Proposals + extra-dirs + Knowledge-Flat nav sections inside auto-nav region)
- `scripts/wiki/wiki-decorate-codes.sh` (create — FR-20 build-time decorator stub)
- `scripts/lifecycle/wiki-init.sh` (modify — in-flight repair: accept `--with-wiki` as no-op for FR-11 passthrough symmetry)
- `tests/m032-acceptance/p0X-scanner-extensions.sh` (create — SC-8)
- `tests/m032-acceptance/p0X-code-decorator.sh` (create — SC-9)
- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` (create — SC-11)
- `tests/m032-acceptance/run-acceptance-battery.sh` (create — SC-12 three-category aggregator)
- `.orchestrator/milestones/M032/M032-VALIDATED` (create — SC-14 marker file)
- `.orchestrator/milestones/M032/M032-SUMMARY.md` (create — SC-14 milestone summary)
- `.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md` (create — M030/M031 evidence-ledger convention)
- `.orchestrator/milestones/M032/execution-log.jsonl` (modify — append milestone-grain `unit_close` record)
- `tools/verify/m032-p04-scanner-extensions.sh` (create)
- `tools/verify/m032-p04-nav-extensions.sh` (create)
- `tools/verify/m032-p04-decorator-shape.sh` (create)
- `tools/verify/m032-p04-with-wiki-noop.sh` (create)
- `tools/verify/m032-p04-acceptance-shape-sc8.sh` (create)
- `tools/verify/m032-p04-acceptance-shape-sc9.sh` (create)
- `tools/verify/m032-p04-acceptance-shape-sc11.sh` (create)
- `tools/verify/m032-p04-acceptance-battery-shape.sh` (create)
- `tools/verify/m032-p04-validate-milestone.sh` (create)
- `tools/verify/m032-p04-milestone-close-ceremony.sh` (create)
- `tools/verify/m032-p04-acceptance-evidence-ledger.sh` (create)
- `tools/verify/m032-p04-phase-suite.sh` (create)
- `tools/verify/m032-p04-scope-guard.sh` (create)
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` (create — captured by T05 per the P01/P02/P03 baseline-ref convention)
