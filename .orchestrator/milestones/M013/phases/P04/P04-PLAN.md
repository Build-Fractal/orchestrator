---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M013"
goal: "Ship the sync cycle (`orchestrator:github sync`) as the final projection-writer pass over post-init state: `scripts/integrations/github-sync.sh` state walker + per-item upsert engine that acquires the lifecycle lock, searches-before-creates using P02's marker helper, closes sub-issues and updates Project v2 status via the third whitelisted GraphQL mutation `updateProjectV2ItemFieldValue`, honors per-item retry boundaries, and pins a `--dry-run` manifest shape byte-identical to `init --dry-run`. Wire the Claude Code `post-verify` hook descriptor into the packaging bundle + installer so `sync_mode: on-transition` invokes sync after `run_hooks POST_VERIFY` without introducing new approval prompts (SC-7). Invoke the M011/P07 conversus adapter at the UAT-defect-closing PR pre-merge gate via `scripts/integrations/github-conversus-gate.sh` (calls `scripts/dispatch/adapters/tool/conversus.sh --strict` with a 30s timeout per FR-13 + Constitution XII; verdict posted as Issue/PR comment; adapter absence under configured gate exits non-zero per D007). Emit `unit_close` and `conversus_gate_invocation` JSONL records to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape with `source: \"runtime\"` (FR-17). Detect `HTTP 403 + X-RateLimit-Remaining: 0` / GraphQL `RATE_LIMITED` / `HTTP 401 + stale gh auth status` with no auto-retry inside the window and a `retry-after` surfaced in exit diagnostics (FR-16); pre-flight `gh api rate_limit` when projected GraphQL volume > 50 mutations. Add `orchestrator:github status --verify-cache` divergence probe that reports without auto-repairing (FR-18). Close the `references/github-integration.md` lifecycle with sync modes, cron guidance, rate-limit + auth-expiry semantics, observability record schema, `--verify-cache` semantics, and conversus gate invocation contract. No knowledge-tree writes (D014). FR-12 Claude-Code-only v1: Codex CLI and Cursor installers stay untouched. Bash 3.2 compatible throughout (MEM001). All new verification commands use the single-script-file shape (AD-19). Every sync upsert searches-before-creates so FR-4 marker idempotency holds on the sync layer. Integer-minutes duration fields worked around the known `phase-transition.sh` non-numeric-duration bug inherited from P02/P03."
demo_sentence: "On a clean orchestrator project seeded with the `tests/fixtures/m013-p04/sync-cycle/` fixture (post-init sidecar with `repo_slug`/`project_v2_id`/`items.<oid>` entries; gh-stub mocks of remote state matching the cached items), running `bash scripts/integrations/github-sync.sh --dry-run --root tests/fixtures/m013-p04/sync-cycle/orchestrator-state --i-am-operator` prints a manifest whose header line (`DRY-RUN:`) and per-row shape (`UPSERT: <kind> <oid> <target> <reason>`) and footer (`upserts=<N> skipped=<M> errors=<E>`) are byte-identical to `init --dry-run` (verified by diff against `expected-sync-dryrun-manifest.txt` and the P02 `expected-manifest.txt` shape pattern). A live `sync` against the same fixture acquires the lock-manager lock, emits at least one `updateProjectV2ItemFieldValue` mutation for a phase whose orchestrator state flipped to Done, closes the corresponding sub-Issue, and appends one `unit_close` JSONL record and (when the conversus gate fires) one `conversus_gate_invocation` JSONL record to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape. The post-verify hook descriptor at `packaging/bundle/hooks/post-verify.json` is picked up by the Claude Code installer's `--hook-config` output (new entry alongside the five existing events) and the M021 prompt-corpus replay shows zero new prompt triggers after the hook wires in. `bash scripts/integrations/github-conversus-gate.sh --issue-ref <ref> --artifact <path> --timeout 30` invokes `scripts/dispatch/adapters/tool/conversus.sh --strict ...`, posts the verdict as an Issue/PR comment via `gh issue comment`, and exits with the adapter's exit code (0 PASS, 2 BLOCK, 1 adapter-error — including missing binary under `--strict`). `bash scripts/integrations/github-status.sh --verify-cache` against a fixture with an intentional cache/remote divergence emits a `DIVERGENCE:` line for each missing-remote, missing-cache, and status-mismatch case and exits non-zero without touching the sidecar. `bash scripts/verify/graphql-call-shape.sh` still exits 0 (the new `updateProjectV2ItemFieldValue` shape is pre-whitelisted from P03/T03). `bash scripts/verify/m013-p04-phase-suite.sh` exits 0 across every P04 gate and the P01, P02, P03 phase-suites still pass byte-for-byte."
risk: "high"
depends_on: ["P03"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M013/P04 verification logic lives inside the
     scripts/verify/m013-p04-*.sh files; the Check commands here invoke them.

     Fixture-driven (zero live `gh` calls in CI). The live sync + conversus
     gate contract is attested at operator milestone close, not by any gate.

     P01/P02/P03 byte-identity: every prior phase's gate suite must remain
     green byte-for-byte after P04 lands. Every P04 extension to
     github-init.sh, github-common.sh, github-status.sh, and
     references/github-integration.md is additive; existing function bodies,
     section content, and their fixtures stay untouched.

     Knowledge-Layer Boundary (D014): no SPEC-* frontmatter changes, no
     KNOWLEDGE-INDEX.md writes, no rebuild-index.sh modifications.

     FR-12 Claude-Code-only v1: Codex and Cursor installers untouched.

     SC-7 zero approval prompts invariant: the post-verify hook adds zero
     new triggers; auto-mode sync short-circuits to pending-sentinel.

     FR-5 GraphQL whitelist: updateProjectV2ItemFieldValue is the third and
     final mutation shape. No fourth shape introduced in P04. -->

### Truths

- `tests/fixtures/m013-p04/sync-cycle/` exists as a self-contained sync fixture with (a) `orchestrator-state/` seed containing a milestone with at least one Done phase and one Ready phase, two completed tasks and one in-flight task, (b) a populated `.orchestrator/integrations/github.json` sidecar with `repo_slug`, `project_v2_id`, `items.<oid>` entries for every projected id plus stale `status_field_synced: false` on at least one Done-phase entry, (c) `gh-stub-responses/` directory containing canned responses for `gh auth status` green, `gh api rate_limit` (remaining > 50), `gh issue list --search "\"<!-- orchestrator-id: <id> -->\""` returning exactly one marker-bearing Issue per cached id, `gh issue view <num> --json state,body` returning `open` for Ready-phase items and `closed`-eligible bodies for Done-phase items, `gh api graphql` responses for `addProjectV2ItemById` and `updateProjectV2ItemFieldValue` returning success payloads, (d) `expected-sync-dryrun-manifest.txt` snapshot and `expected-unit-close.jsonl` snapshot pinning the JSONL emitter shape (one record per Done-phase closure), (e) `expected-conversus-gate-invocation.jsonl` snapshot (one record per gate fire).
  - Check: `bash scripts/verify/m013-p04-sync-fixture.sh`

- `scripts/integrations/github-sync.sh` is a new executable bash script (min 500 lines) that: (a) parses `--dry-run`, `--i-am-operator`, `--root <path>`, `--conversus-gate`, `--timeout <sec>` flags using the same while-loop parser shape as `github-init.sh`; (b) runs the auto-mode short-circuit from P02 BEFORE any live `gh` call (no TTY + no `--i-am-operator` → emit `STATUS: pending-operator-complete` to stdout, exit 0, zero `gh` invocations); (c) sources `scripts/integrations/github-common.sh` for `gh_marker_search_remote`, `shasum_marker_byte_identity`, `manifest_upsert_line`, `manifest_footer`, `sidecar_upsert_item`; (d) acquires the lifecycle lock via `bash scripts/lifecycle/lock-manager.sh create --owner github-sync --reason "M013 sync"` and releases it on every exit path (EXIT trap) per FR-7; (e) walks the orchestrator state (same walker shape as `github-init.sh`) producing the projected set of `(kind, oid, state-transition)` tuples where `state-transition` is one of `open`, `closed`, `status-field-update`; (f) for each tuple, searches-before-creates via `gh_marker_search_remote` (FR-4 on sync layer), diffs cached vs desired state, emits one `UPSERT: <kind> <oid> <target> <reason>` line per change (reasons: `create`, `close`, `status-sync`, `skip-nochange`, `adopt` same reason vocabulary as init); (g) emits `manifest_footer` in the P02 3-field shape (`upserts=<N> skipped=<M> errors=<E>`) for sync runs — no `adopted=` field; (h) in live mode only, issues the GraphQL `updateProjectV2ItemFieldValue` mutation for Done-phase items with stale `status_field_synced: false`, using the single-line `--field query='mutation($pid:ID!,$iid:ID!,$fid:ID!,$val:String!){updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{singleSelectOptionId:$val}}){projectV2Item{id}}}'` shape (FR-5 compliant; pre-whitelisted in P03/T03); (i) on every sync run, updates the sidecar's per-item cache fields `last_attempt_at`, `last_error`, `status_field_synced`, `project_v2_attached` via a new helper `sidecar_update_item_cache` added to `github-common.sh`.
  - Check: `bash scripts/verify/m013-p04-github-sync.sh`

- `scripts/integrations/github-sync.sh` `--dry-run` produces a manifest whose shape is byte-identical to `init --dry-run`: the per-row regex is `^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ [a-z\-]+$` and the footer regex is `^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$`. The manifest additionally diffs to zero against `tests/fixtures/m013-p04/sync-cycle/expected-sync-dryrun-manifest.txt` when run against the fixture (pinned snapshot, same pattern as P02/T07).
  - Check: `bash scripts/verify/m013-p04-dry-run-manifest.sh`

- `scripts/integrations/github-sync.sh` detects and halts on rate-limit and auth-expiry conditions (FR-16): on `HTTP 403 + X-RateLimit-Remaining: 0` or a GraphQL `RATE_LIMITED` error code, emits `RATE-LIMIT: retry-after=<ISO-ts>` to stderr, surfaces the retry-after header in the exit diagnostic, and exits with rc=3 without issuing any further API calls; on `HTTP 401` or a stale `gh auth status` probe, emits `AUTH-EXPIRED: run gh auth refresh` to stderr and exits with rc=4; when the pre-flight projected GraphQL volume exceeds 50 mutations, runs `gh api rate_limit` first and refuses to proceed if remaining budget is below the projection. No automatic retry inside the rate-limit window. The script uses a single `http_probe` helper in `github-common.sh` added by this task that wraps `gh api --include` and parses rate-limit headers + HTTP status.
  - Check: `bash scripts/verify/m013-p04-rate-limit.sh`

- `scripts/integrations/github-sync.sh` emits `unit_close` JSONL records in M019 Tier 1 shape to `.orchestrator/execution-log.jsonl` for every Done-phase item whose `status_field_synced` flipped from `false` to `true` during the run; record fields are `{"ts":"<ISO>","event":"unit_close","source":"runtime","milestone":"M###","phase":"P##","task":"T##"|null,"oid":"<orchestrator-id>","issue_number":<int>,"outcome":"closed|status-synced"}`. `scripts/integrations/github-conversus-gate.sh` emits `conversus_gate_invocation` JSONL records with fields `{"ts":"<ISO>","event":"conversus_gate_invocation","source":"runtime","issue_ref":"<repo>#<num>","timeout_sec":<int>,"verdict":"PASS|BLOCK|SKIPPED|ERROR","rc":<int>,"duration_ms":<int>}`. Both emitters use a shared `emit_tier1_record` helper added to `github-common.sh`; the helper appends one line per record (append-only JSONL) and never rotates or rewrites the log.
  - Check: `bash scripts/verify/m013-p04-observability.sh`

- `packaging/bundle/hooks/post-verify.json` is a new hook descriptor (min 5 lines) mirroring the shape of the existing `before-implement.json`, wired into the claude-code runtime adapter's `--hook-config` output as a sixth event entry `{ "event": "post_verify", "command": "orchestrator-post-verify" }`. `packaging/install/install-claude-code.sh` gains ONE new line (or a one-line addition to an existing array initializer) referencing `post-verify.json` in the bundle enumeration; Codex CLI and Cursor installers are BYTE-IDENTICAL to their pre-P04 state (FR-12 v1). The `scripts/dispatch/adapters/runtime/claude-code.sh` `--hook-config` JSON emits six hook entries (was five pre-P04), with the new entry stable-ordered after `before_commit`. The M021 prompt-corpus replay (`tests/fixtures/m021-prompt-corpus.txt`) exercised against the post-hook-wire state attests zero new prompt triggers.
  - Check: `bash scripts/verify/m013-p04-post-verify-hook.sh`

- `scripts/integrations/github-conversus-gate.sh` is a new executable bash script (min 100 lines) that: (a) parses `--issue-ref <repo>#<num>` (required), `--artifact <path>` (required), `--timeout <sec>` (default 30 per Constitution XII), `--preset <name>` (default `m013-uat-defect-merge`) flags; (b) resolves the conversus adapter at `scripts/dispatch/adapters/tool/conversus.sh` and invokes `bash scripts/dispatch/adapters/tool/conversus.sh gate --strict <preset> <artifact> <tmp-output>`; (c) parses the gate-result verdict using the adapter's `parse-verdict <gate-result-path>` subcommand; (d) in live mode, posts the verdict as an Issue/PR comment via `gh issue comment <num> --body "<verdict-gloss>"`; (e) appends a `conversus_gate_invocation` JSONL record via the shared emitter; (f) exits with the adapter's exit code verbatim (0 PASS → proceed, 2 BLOCK → gate merge, 1 adapter-error / strict-mode missing binary → fail-stop); (g) honors auto-mode short-circuit: without TTY + without `--i-am-operator`, emits `STATUS: gate-deferred` and exits 0 without any `conversus` or `gh` call; (h) enforces the 30s timeout via the adapter's internal timeout or an external watchdog (`kill -TERM` after 30s + `kill -KILL` after 31s) — the gate never blocks longer than 31 wall seconds.
  - Check: `bash scripts/verify/m013-p04-conversus-gate.sh`

- `scripts/integrations/github-status.sh` gains an FR-18 `--verify-cache` flag that, when set alongside a populated sidecar (`STATUS: configured`), walks each cached `items.<oid>` entry and probes the remote via `gh_marker_search_remote`: (a) for missing-remote (cache claims an Issue that is not marker-searchable), emits `DIVERGENCE: missing-remote oid=<oid> cached-issue-number=<num>`; (b) for missing-cache (marker-bearing remote Issue without a cache entry), emits `DIVERGENCE: missing-cache oid=<oid> issue-number=<num>`; (c) for status-field-mismatch (cached `status_field_synced: true` but remote Project v2 status differs from orchestrator Done-phase expectation), emits `DIVERGENCE: status-mismatch oid=<oid> cached=<bool> remote=<value>`. Each `DIVERGENCE:` line increments a counter; script exits 0 when counter=0 and exits 5 when counter>0. `--verify-cache` NEVER writes to the sidecar, NEVER writes to GitHub, and NEVER auto-repairs — it reports only. `commands/github-status.md` Core Workflow gains a step documenting `--verify-cache` with exit-code semantics.
  - Check: `bash scripts/verify/m013-p04-verify-cache.sh`

- `commands/github-sync.md` is a new command definition (min 70 lines) following the MEM012 command structure (YAML frontmatter with `description:` field → Title → Prerequisites/State Check → Core Workflow → Output → Idempotency → Error Handling → Referenced Scripts/Templates). The Core Workflow documents the `sync` invocation modes (manual / on-transition / cron), the `--dry-run` contract, the conversus gate opt-in via `--conversus-gate`, the rate-limit + auth-expiry exit codes (rc=3, rc=4), and the post-verify hook wiring. Referenced Scripts list `scripts/integrations/github-sync.sh`, `scripts/integrations/github-conversus-gate.sh`, `scripts/integrations/github-common.sh`, `scripts/dispatch/adapters/tool/conversus.sh`, `scripts/lifecycle/lock-manager.sh`.
  - Check: `bash scripts/verify/m013-p04-github-sync-command.sh`

- `references/github-integration.md` P04 extensions are in place: the three `### TODO P04:` stubs (sync Workflow, Conversus Pre-Merge Gate, FR-17 Cost Emission) relabeled by P03/T04 are FILLED in place (each TODO-labeled heading becomes a fully-bodied subsection); new subsections added — `### Sync Modes` (manual / on-transition / cron + cron registration guidance, operator-owned), `### Rate-Limit & Auth-Expiry Semantics` (FR-16 exit codes + pre-flight probe rule), `### Observability Record Schema` (`unit_close` + `conversus_gate_invocation` field-by-field; points at M019 as schema authority), `### --verify-cache Semantics` (the three divergence classes, exit-code contract, non-repair contract), `### Conversus Gate Invocation Contract` (strict mode, 30s timeout, verdict-as-comment, adapter-absence semantics per D007); the Full Mapping Table adds a `sync` row per kind; Scope Boundary table gets a P04 column populated (every deliverable in this phase flagged). P01-, P02-, and P03-authored sections stay byte-identical (section-content `shasum` compared against hashes embedded in the gate script; pattern established by P02/T05 + P03/T04).
  - Check: `bash scripts/verify/m013-p04-reference-extensions.sh`

- Every P04-touched or P04-created `.sh` file is Bash 3.2 compatible (no `declare -A`, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`, no `<(...)`/`>(...)`, no `&>`/`|&`) and passes `scripts/verify/anti-pattern-lint.sh` with the `--fixture <path>` per-file invocation pattern (P02/T07 + P03/T05 precedent — without `--fixture` the lint scans repo and flags PAYLOAD fenced examples). The P04 bash32-compat gate mirrors the P03 gate shape, with a self-exclusion case-branch so the gate file does not match its own pattern scan and with comment-discipline synonyms (`assoc-arrays`, `array-from-stdin builtins`, `case-conversion expansion`, `combined-redirect shorthand`) so the gate stays self-clean per P03/T05 pattern.
  - Check: `bash scripts/verify/m013-p04-bash32-compat.sh`

- `bash scripts/verify/graphql-call-shape.sh` (FR-5 lint from P03/T03) still exits 0 against the post-P04 repo. P04 introduces exactly one new mutation shape — `updateProjectV2ItemFieldValue` — which was PRE-WHITELISTED by P03/T03 specifically to keep this gate green on P04 arrival. No fourth shape is introduced. The P04 phase-suite includes a direct invocation of this lint as an explicit regression guard.
  - Check: `bash scripts/verify/graphql-call-shape.sh`

- `bash scripts/verify/m013-p04-phase-suite.sh` orchestrates all P04 gates in dependency order (sync-fixture, github-sync, dry-run-manifest, rate-limit, observability, post-verify-hook, conversus-gate, verify-cache, github-sync-command, reference-extensions, bash32-compat) + explicit FR-5 lint invocation + regression guards for P01/P02/P03 phase-suites + regression guard on anti-pattern-lint, exits 0 on green, non-zero with per-gate PASS/FAIL breakdown otherwise. The SUMMARY line uses the self-named form `SUMMARY: m013-p04-phase-suite.sh pass=N fail=M` (same shape as P02/P03).
  - Check: `bash scripts/verify/m013-p04-phase-suite.sh`

- P01, P02, and P03 phase suites still exit 0 byte-for-byte. `bash scripts/verify/m013-p01-phase-suite.sh`, `bash scripts/verify/m013-p02-phase-suite.sh`, and `bash scripts/verify/m013-p03-phase-suite.sh` each return exit 0 after P04 lands. No prior-phase gate is modified; P03's P02 regression-guard pattern is inherited by P04's phase-suite orchestrator (all three prior suites are invoked as regression guards).
  - Check: `bash scripts/verify/m013-p03-phase-suite.sh`

### Artifacts

- `scripts/integrations/github-sync.sh` (min 500 lines, contains "updateProjectV2ItemFieldValue") — create
- `scripts/integrations/github-conversus-gate.sh` (min 100 lines, contains "conversus.sh --strict") — create
- `scripts/integrations/github-common.sh` (min 700 lines, contains "emit_tier1_record") — modify-in-place, add `http_probe`, `sidecar_update_item_cache`, `emit_tier1_record` public helpers
- `scripts/integrations/github-status.sh` (contains "verify-cache") — modify-in-place, add `--verify-cache` branch
- `scripts/dispatch/adapters/runtime/claude-code.sh` (contains "post_verify") — modify-in-place, add sixth hook entry in `--hook-config` JSON
- `packaging/bundle/hooks/post-verify.json` (min 5 lines, contains "post-verify") — create
- `packaging/install/install-claude-code.sh` (contains "post-verify") — modify-in-place, one-line addition
- `commands/github-sync.md` (min 70 lines, contains "sync") — create
- `commands/github-status.md` (contains "verify-cache") — modify-in-place, add Core Workflow step for `--verify-cache`
- `references/github-integration.md` (min 400 lines, contains "Conversus Gate Invocation Contract") — modify-in-place, fill 3 TODO P04 stubs + author 5 new subsections + update Scope Boundary + add `sync` rows to Full Mapping Table
- `tests/fixtures/m013-p04/sync-cycle/` (directory tree with `orchestrator-state/` seed, `gh-stub-responses/`, expected-*-snapshot files) — create
- `tests/fixtures/m013-p04/sync-cycle/expected-sync-dryrun-manifest.txt` (min 6 lines, contains "UPSERT:") — create
- `tests/fixtures/m013-p04/sync-cycle/expected-unit-close.jsonl` (min 1 line, contains "unit_close") — create
- `tests/fixtures/m013-p04/sync-cycle/expected-conversus-gate-invocation.jsonl` (min 1 line, contains "conversus_gate_invocation") — create
- `scripts/verify/m013-p04-sync-fixture.sh` (min 30 lines, contains "expected-sync-dryrun-manifest") — create
- `scripts/verify/m013-p04-github-sync.sh` (min 60 lines, contains "github-sync.sh") — create
- `scripts/verify/m013-p04-dry-run-manifest.sh` (min 40 lines, contains "byte-identical") — create
- `scripts/verify/m013-p04-rate-limit.sh` (min 40 lines, contains "RATE-LIMIT") — create
- `scripts/verify/m013-p04-observability.sh` (min 50 lines, contains "unit_close") — create
- `scripts/verify/m013-p04-post-verify-hook.sh` (min 40 lines, contains "post-verify.json") — create
- `scripts/verify/m013-p04-conversus-gate.sh` (min 50 lines, contains "--strict") — create
- `scripts/verify/m013-p04-verify-cache.sh` (min 40 lines, contains "DIVERGENCE") — create
- `scripts/verify/m013-p04-github-sync-command.sh` (min 30 lines, contains "github-sync.md") — create
- `scripts/verify/m013-p04-reference-extensions.sh` (min 50 lines, contains "Conversus Gate Invocation Contract") — create
- `scripts/verify/m013-p04-bash32-compat.sh` (min 30 lines, contains "declare -A") — create
- `scripts/verify/m013-p04-phase-suite.sh` (min 60 lines, contains "m013-p04") — create

### Key Links

- `commands/github-sync.md` → `scripts/integrations/github-sync.sh` (Referenced Scripts)
- `commands/github-sync.md` → `scripts/integrations/github-conversus-gate.sh` (Referenced Scripts)
- `commands/github-sync.md` → `scripts/lifecycle/lock-manager.sh` (Referenced Scripts — FR-7 lock acquisition)
- `commands/github-status.md` → `scripts/integrations/github-status.sh` (existing; P04 extends doc with `--verify-cache` step)
- `scripts/integrations/github-sync.sh` → `scripts/integrations/github-common.sh` (sources helpers: `gh_marker_search_remote`, `http_probe`, `emit_tier1_record`, `sidecar_update_item_cache`)
- `scripts/integrations/github-sync.sh` → `scripts/lifecycle/lock-manager.sh` (lock acquire/release)
- `scripts/integrations/github-conversus-gate.sh` → `scripts/dispatch/adapters/tool/conversus.sh` (invokes `gate --strict`)
- `packaging/install/install-claude-code.sh` → `packaging/bundle/hooks/post-verify.json` (bundle enumeration)
- `scripts/dispatch/adapters/runtime/claude-code.sh` → `packaging/bundle/hooks/post-verify.json` (sixth entry in `--hook-config` JSON references the descriptor)
- `references/github-integration.md` → `scripts/integrations/github-sync.sh` (Sync Modes + --dry-run + rate-limit subsections)
- `references/github-integration.md` → `scripts/integrations/github-conversus-gate.sh` (Conversus Gate Invocation Contract)
- `references/github-integration.md` → `scripts/integrations/github-status.sh` (--verify-cache Semantics)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-sync-fixture.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-github-sync.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-dry-run-manifest.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-rate-limit.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-observability.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-post-verify-hook.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-conversus-gate.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-verify-cache.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-github-sync-command.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-reference-extensions.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p04-bash32-compat.sh` (orchestrated gate)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/graphql-call-shape.sh` (FR-5 regression guard)
- `scripts/verify/m013-p04-phase-suite.sh` → `scripts/verify/m013-p03-phase-suite.sh` (regression guard — P03 byte-identity; P03's suite already carries the P02 regression)

## Tasks

### T01: Sync fixture tree + `github-common.sh` P04 helpers (`http_probe`, `sidecar_update_item_cache`, `emit_tier1_record`)

See `tasks/T01-PLAN.md`.

### T02: `github-sync.sh` state walker + per-item upsert engine + `--dry-run` manifest + lock acquisition + `updateProjectV2ItemFieldValue` mutation + sidecar cache update

See `tasks/T02-PLAN.md`.

### T03: FR-16 rate-limit + auth-expiry detection + FR-17 observability emitters (`unit_close` + `conversus_gate_invocation` JSONL) in `github-sync.sh` + gate

See `tasks/T03-PLAN.md`.

### T04: Post-verify hook descriptor + installer wiring + claude-code runtime adapter sixth-entry

See `tasks/T04-PLAN.md`.

### T05: Conversus UAT PR gate — `github-conversus-gate.sh` (`conversus.sh --strict`, 30s timeout, verdict-as-comment, exit-code-gates-merge)

See `tasks/T05-PLAN.md`.

### T06: `github-status.sh` `--verify-cache` divergence probe + `commands/github-sync.md` + `commands/github-status.md` addendum + `references/github-integration.md` P04 extensions + P04 bash32-compat gate + phase-suite orchestrator

See `tasks/T06-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──┬─► T03 ──┐
              │         │
              │         ├─► T06
              │         │
T01 ──────────┴─► T05 ──┤
                        │
              T04 ──────┘
```

T01 authors the sync fixture tree and the three additive helpers in `github-common.sh` (`http_probe`, `sidecar_update_item_cache`, `emit_tier1_record`). T02 ships the core sync engine in `github-sync.sh` consuming the fixture (gate input) + the helpers (API surface) + P02's lock-manager + P03's pre-whitelisted `updateProjectV2ItemFieldValue` shape. T03 is a focused additive pass on `github-sync.sh` (rate-limit + auth-expiry + observability emitters) consuming the sync engine and the `emit_tier1_record` + `http_probe` helpers. T04 is independent of T01/T02/T03 — it wires the Claude Code post-verify hook descriptor into the packaging bundle + installer + runtime adapter + attests zero new prompt triggers; it can run in parallel with the T02-T03 chain once T01 has settled the helper surface (T04 doesn't call the helpers directly, but the claude-code.sh `--hook-config` JSON shape is fixed in T04). T05 ships `github-conversus-gate.sh` consuming T01's `emit_tier1_record` helper and the pre-existing conversus adapter (`--strict` from M011/P07); independent of T02/T03. T06 closes the suite: `github-status.sh` `--verify-cache` branch, `commands/github-sync.md` + `commands/github-status.md` addendum, `references/github-integration.md` P04 extensions (fill 3 TODO P04 stubs + author 5 new subsections + Full Mapping Table `sync` rows + Scope Boundary P04 column), P04 bash32-compat gate, phase-suite orchestrator with FR-5 + P01/P02/P03 regression guards. T06 depends on all of T02/T03/T04/T05 having settled their surfaces (it documents them).

Dispatch may execute {T02→T03} and {T04} and {T05} as three parallel lanes once T01 completes. T06 waits for all three lanes to land.

## Files Likely Touched

- `scripts/integrations/github-sync.sh` (create)
- `scripts/integrations/github-conversus-gate.sh` (create)
- `scripts/integrations/github-common.sh` (modify — add `http_probe`, `sidecar_update_item_cache`, `emit_tier1_record` helpers)
- `scripts/integrations/github-status.sh` (modify — add `--verify-cache` branch)
- `scripts/dispatch/adapters/runtime/claude-code.sh` (modify — add sixth `post_verify` entry in `--hook-config` JSON)
- `packaging/bundle/hooks/post-verify.json` (create)
- `packaging/install/install-claude-code.sh` (modify — one-line addition referencing `post-verify.json`)
- `commands/github-sync.md` (create)
- `commands/github-status.md` (modify — add Core Workflow step for `--verify-cache`)
- `references/github-integration.md` (modify — fill 3 TODO P04 stubs + author 5 new subsections + Full Mapping Table `sync` rows + Scope Boundary P04 column)
- `tests/fixtures/m013-p04/sync-cycle/` (create — directory tree)
- `tests/fixtures/m013-p04/sync-cycle/orchestrator-state/` (create — seed milestone/phase/task layout for sync walker)
- `tests/fixtures/m013-p04/sync-cycle/expected-sync-dryrun-manifest.txt` (create — pinned manifest snapshot)
- `tests/fixtures/m013-p04/sync-cycle/expected-unit-close.jsonl` (create — pinned JSONL snapshot)
- `tests/fixtures/m013-p04/sync-cycle/expected-conversus-gate-invocation.jsonl` (create — pinned JSONL snapshot)
- `tests/fixtures/m013-p04/sync-cycle/gh-stub-responses/` (create — canned gh responses)
- `scripts/verify/m013-p04-sync-fixture.sh` (create)
- `scripts/verify/m013-p04-github-sync.sh` (create)
- `scripts/verify/m013-p04-dry-run-manifest.sh` (create)
- `scripts/verify/m013-p04-rate-limit.sh` (create)
- `scripts/verify/m013-p04-observability.sh` (create)
- `scripts/verify/m013-p04-post-verify-hook.sh` (create)
- `scripts/verify/m013-p04-conversus-gate.sh` (create)
- `scripts/verify/m013-p04-verify-cache.sh` (create)
- `scripts/verify/m013-p04-github-sync-command.sh` (create)
- `scripts/verify/m013-p04-reference-extensions.sh` (create)
- `scripts/verify/m013-p04-bash32-compat.sh` (create)
- `scripts/verify/m013-p04-phase-suite.sh` (create)
