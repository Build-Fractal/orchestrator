---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M013"
goal: "Extend P02's `orchestrator:github init` with the FR-14 re-init adoption branch (sidecar-absent + marker-bearing remote Issues → rebuild sidecar from remote state without creating duplicates; P02 create path stays byte-identical), ship the FR-5 GraphQL three-shape CI lint at `scripts/verify/graphql-call-shape.sh` that asserts exactly {`createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`} are used across `scripts/integrations/` and fails on any fourth shape, and complete the `references/github-integration.md` mapping table in place (fill 3 `_deferred to P03_` rows + author a Re-init Adoption Contract subsection + relabel 3 `### TODO P03:` stubs to `### TODO P04:` per D015 rename). No knowledge-tree writes (D014), no SPEC-* frontmatter changes, no modifications to `scripts/knowledge/rebuild-index.sh` or `KNOWLEDGE-INDEX.md`. Claude-Code-only v1 per FR-12. Auto-mode SC-7 zero-gh-writes invariant preserved on every new code path."
demo_sentence: "On a clean orchestrator project seeded with the `tests/fixtures/m013-p03/re-init-adoption/` fixture (sidecar absent; gh-stub mocks a remote with marker-bearing Issues for each projected orchestrator-id and a pre-existing Project v2), running `bash scripts/integrations/github-init.sh --dry-run --root tests/fixtures/m013-p03/re-init-adoption/orchestrator-state --repo-slug test/test --i-am-operator` prints a manifest in which every projected resource carries `reason=adopt` (zero `create` rows), exits 0, and — when re-run in live mode via the same fixture with the `--re-init` flag — writes a rebuilt sidecar containing `repo_slug`, `project_v2_id`, and one `items.<orchestrator-id>` entry per adopted Issue with zero duplicate GitHub resources created; `bash scripts/verify/graphql-call-shape.sh` exits 0 against the repo today (exactly the three whitelisted shapes found across `scripts/integrations/`) and exits non-zero with `FAIL: graphql-call-shape.sh unexpected shape: <name>` when a fourth shape is injected into a fixture copy; `bash scripts/verify/m013-p03-phase-suite.sh` exits 0 across all P03 gates and the P02 phase-suite still passes byte-for-byte (P02 create path untouched)."
risk: "medium"
depends_on: ["P02"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M013/P03 verification logic lives inside the
     scripts/verify/m013-p03-*.sh files; the Check commands here invoke them.

     Fixture-driven (zero live `gh` calls in CI). The re-init live contract
     is attested by the P03 dogfood run at operator milestone close, not by
     any gate.

     P02 byte-identity: P02's create-path gates (scripts/verify/m013-p02-*.sh)
     must remain green byte-for-byte after P03 lands. Any P03 extension to
     github-init.sh / github-common.sh is additive; existing function bodies
     and their fixtures stay untouched. -->

### Truths

- `tests/fixtures/m013-p03/re-init-adoption/` exists as a self-contained re-init fixture with (a) `orchestrator-state/` seed containing an in-flight milestone with at least one Ready/Executing phase and two tasks, (b) NO `.orchestrator/integrations/github.json` sidecar (absent, not pending-sentinel), (c) `gh-stub-responses/` directory containing canned responses for `gh auth status` green, `gh api /repos/.../issues?state=all` returning marker-bearing Issues for each projected orchestrator-id, `gh issue list --search "\"<!-- orchestrator-id: <id> -->\""` returning exactly one hit per id, and `gh api graphql` responses for `node` queries resolving the pre-existing Project v2 id, (d) `expected-readopt-manifest.txt` snapshot in which every resource row carries `reason=adopt` and the footer reads `upserts=0 skipped=<N> errors=0 adopted=<N>`.
  - Check: `bash scripts/verify/m013-p03-re-init-fixture.sh`

- `scripts/integrations/github-common.sh` gains exactly one new public helper `gh_marker_search_remote <repo-slug> <orchestrator-id>` that returns the Issue number of a marker-bearing remote Issue via `gh issue list --search "\"<!-- orchestrator-id: <id> -->\""` and `--json number --jq '.[0].number // empty'` (exit 0 + number on stdout when exactly one match; exit 1 + empty stdout on zero matches; exit 2 on duplicate; fixture-driven via `M013_GH_STUB_DIR` env var same pattern as P02's preflights). All P02-authored helpers are byte-identical. The bash-3.2 compat + anti-pattern-lint gates stay green.
  - Check: `bash scripts/verify/m013-p03-github-common-readopt.sh`

- `scripts/integrations/github-init.sh` gains an FR-14 re-init adoption branch reached when the sidecar is absent (or the new `--re-init` flag is passed) AND the live preflight finds marker-bearing Issues on the remote. In that branch, for each projected orchestrator-id, the script (a) invokes `gh_marker_search_remote`, (b) on hit emits `UPSERT: <kind> <oid> <issue-number> adopt`, (c) writes the sidecar `items.<oid>` entry with the adopted `issue_number`, `project_v2_attached: true` (if the Project v2 item check resolves), `status_field_synced: false`, `last_attempt_at: <iso>`, `last_error: null`, (d) performs `shasum_marker_byte_identity` on the remote body to verify FR-4 marker invariant, (e) never calls `gh issue create` / `gh milestone create` / `gh label create` for already-adopted ids. The existing P02 create path (no-sidecar + no-marker-remote case) is byte-identical — the re-init branch is additive. Manifest footer gains an `adopted=N` field.
  - Check: `bash scripts/verify/m013-p03-re-init-adoption.sh`

- `scripts/integrations/github-init.sh` re-init branch honors SC-7: without TTY + without `--i-am-operator`, zero `gh` write calls fire (the existing auto-mode short-circuit from P02 still guards the entire script entry). A PATH-shimmed fake `gh` + fixture-driven dispatch logs zero `create`/`edit`/`delete` invocations when re-init runs in auto-mode. Dry-run of re-init under auto-mode still writes the pending-sentinel sidecar (re-init is an operator-initiated action; auto-mode never re-adopts live resources).
  - Check: `bash scripts/verify/m013-p03-re-init-auto-mode.sh`

- `scripts/verify/graphql-call-shape.sh` is a standalone CI lint that scans `scripts/integrations/github-*.sh` for `gh api graphql` invocations, parses out the GraphQL mutation top-level name via `awk` pattern matching on `mutation(...){<NAME>(...)` (handles both the single-line `--field query='mutation(...){<name>(...)}'` shape used in P02/P04 and the heredoc-assigned variable shape used in P04 sync), emits one `SHAPE: <name>` line per match, asserts the deduplicated set is a subset of the whitelist `{createProjectV2, addProjectV2ItemById, updateProjectV2ItemFieldValue}`, and fails non-zero with `FAIL: graphql-call-shape.sh unexpected shape: <name>` on any member outside the whitelist. Scope is `scripts/integrations/` only — unrelated GraphQL elsewhere in the repo (e.g., `scripts/diagnostics/wiki-giscus-remap.sh` `updateDiscussion`) is out of scope.
  - Check: `bash scripts/verify/m013-p03-graphql-call-shape-selftest.sh`

- `references/github-integration.md` has the three bold `_deferred to P03_` rows in the Partial Mapping Table filled in place (spec chunk / acceptance criterion / verification status rows now carry real content; table heading is no longer "Partial Mapping Table (P02)" but "Full Mapping Table" — that single heading word is the only touch to the table frame), AND the three `### TODO P03:` stub headings (`sync` Workflow, Conversus Pre-Merge Gate, FR-17 Cost Emission) are relabeled to `### TODO P04:` (D015 rename; content bodies unchanged), AND a new `### Re-init Adoption Contract (FR-14)` subsection is inserted documenting sidecar-absent + marker-bearing remote semantics, marker-search order, duplicate-marker diagnostic, and `--re-init` flag. P01-authored sections stay byte-identical (Overview, Sidecar Config Schema, Pending-Sentinel Semantics, `sync_mode` Enum, Marker Format, UAT Ingestion Contract, Knowledge-Layer Boundary, Referenced Artifacts P01, Further Reading). P02-authored sections stay byte-identical (Auth Modes, Sub-Issue Representation Modes, `init` Workflow, Dry-Run Manifest Format, Referenced Artifacts P02). The Scope Boundary table P03 column is populated (row entries reflect the P03 deliverables). Byte-identity is verified via section-content `shasum` compare against hashes embedded in the gate script (same pattern P02/T05 established).
  - Check: `bash scripts/verify/m013-p03-reference-extensions.sh`

- Every P03-touched or P03-created `.sh` file is Bash 3.2 compatible (no `declare -A`, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`, no `<(...)`/`>(...)`, no `&>`/`|&`) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution IX, Constitution XV, SC-6, MEM001). The P03 bash32-compat gate mirrors the P02 gate shape, with a self-exclusion case-branch so the gate file does not match its own pattern scan.
  - Check: `bash scripts/verify/m013-p03-bash32-compat.sh`

- `bash scripts/verify/m013-p03-phase-suite.sh` orchestrates all P03 gates in dependency order (re-init-fixture, github-common-readopt, re-init-adoption, re-init-auto-mode, graphql-call-shape-selftest, reference-extensions, bash32-compat) and exits 0 on green, non-zero with per-gate PASS/FAIL breakdown otherwise. The SUMMARY line uses the self-named form `SUMMARY: m013-p03-phase-suite.sh pass=N fail=M` (same shape as P02).
  - Check: `bash scripts/verify/m013-p03-phase-suite.sh`

- P02 create path is preserved byte-identical. `bash scripts/verify/m013-p02-phase-suite.sh` still exits 0 across all 8 P02 gates after P03 lands. No P02-authored section of `references/github-integration.md` is modified — byte-identity verified by running the P02 reference-extensions gate unchanged.
  - Check: `bash scripts/verify/m013-p02-phase-suite.sh`

### Artifacts

- `scripts/integrations/github-common.sh` (min 640 lines, contains "gh_marker_search_remote") — modify-in-place, add ONE public helper
- `scripts/integrations/github-init.sh` (min 700 lines, contains "re-init") — modify-in-place, add re-init branch + `--re-init` flag + `adopted=` footer field
- `commands/github-init.md` (min 60 lines, contains "re-init") — modify-in-place, document `--re-init` flag
- `references/github-integration.md` (min 310 lines, contains "Re-init Adoption Contract") — modify-in-place, fill deferred rows + relabel stubs + author new section
- `tests/fixtures/m013-p03/re-init-adoption/` (directory tree with `orchestrator-state/` seed, `expected-readopt-manifest.txt`, `gh-stub-responses/`)
- `tests/fixtures/m013-p03/re-init-adoption/expected-readopt-manifest.txt` (min 10 lines, contains "adopt")
- `tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issues-list-marker-bearing.json` (min 5 lines, contains "orchestrator-id")
- `scripts/verify/graphql-call-shape.sh` (min 40 lines, contains "createProjectV2")
- `scripts/verify/m013-p03-re-init-fixture.sh` (min 30 lines, contains "expected-readopt-manifest")
- `scripts/verify/m013-p03-github-common-readopt.sh` (min 30 lines, contains "gh_marker_search_remote")
- `scripts/verify/m013-p03-re-init-adoption.sh` (min 50 lines, contains "adopt")
- `scripts/verify/m013-p03-re-init-auto-mode.sh` (min 30 lines, contains "pending-operator-complete")
- `scripts/verify/m013-p03-graphql-call-shape-selftest.sh` (min 30 lines, contains "unexpected shape")
- `scripts/verify/m013-p03-reference-extensions.sh` (min 40 lines, contains "Re-init Adoption Contract")
- `scripts/verify/m013-p03-bash32-compat.sh` (min 30 lines, contains "declare -A")
- `scripts/verify/m013-p03-phase-suite.sh` (min 50 lines, contains "m013-p03")

### Key Links

- `commands/github-init.md` → `scripts/integrations/github-init.sh` (Referenced Scripts names the script; P03 extends doc with `--re-init` flag)
- `scripts/integrations/github-init.sh` → `scripts/integrations/github-common.sh` (sources the helpers; P03 re-init branch calls `gh_marker_search_remote`)
- `scripts/verify/graphql-call-shape.sh` → `scripts/integrations/github-init.sh` (scan target)
- `references/github-integration.md` → `scripts/verify/graphql-call-shape.sh` (Re-init Adoption Contract subsection cross-references the lint as the FR-5 enforcement surface)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-re-init-fixture.sh` (orchestrated gate)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-github-common-readopt.sh` (orchestrated gate)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-re-init-adoption.sh` (orchestrated gate)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-re-init-auto-mode.sh` (orchestrated gate)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-graphql-call-shape-selftest.sh` (orchestrated gate)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-reference-extensions.sh` (orchestrated gate)
- `scripts/verify/m013-p03-phase-suite.sh` → `scripts/verify/m013-p03-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: Re-init fixture tree + `gh_marker_search_remote` helper (`github-common.sh` additive extension)

See `tasks/T01-PLAN.md`.

### T02: `github-init.sh` FR-14 re-init adoption branch + `--re-init` flag

See `tasks/T02-PLAN.md`.

### T03: `scripts/verify/graphql-call-shape.sh` FR-5 three-shape CI lint

See `tasks/T03-PLAN.md`.

### T04: `references/github-integration.md` P03 extensions + `commands/github-init.md` `--re-init` addendum

See `tasks/T04-PLAN.md`.

### T05: Phase verification suite + bash32-compat gate + phase-suite orchestrator

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──┐
              │
T03 ──────────┤
              │
T04 ──────────┴──► T05
```

T01 authors the re-init fixture tree and the additive `gh_marker_search_remote` helper in `github-common.sh`. T02 ships the re-init adoption branch in `github-init.sh` consuming both (fixture for gate input, helper for marker search). T03 is independent of T01/T02 — it only scans the result of P02's mutation authorship plus whatever P04 will add later; the selftest fixture is self-contained. T04 documents the re-init contract in `references/github-integration.md` and extends `commands/github-init.md` with the `--re-init` flag; it depends on T02 having settled the flag name and on T03 having settled the lint file path. T05 closes the suite with bash32-compat + phase-suite orchestrator; it depends on all predecessors. Dispatch may execute T03 and T04 in parallel once T02 completes; T01 must land before T02.

## Files Likely Touched

- `scripts/integrations/github-common.sh` (modify — add `gh_marker_search_remote` helper)
- `scripts/integrations/github-init.sh` (modify — add re-init adoption branch + `--re-init` flag + `adopted=` footer)
- `commands/github-init.md` (modify — document `--re-init` flag)
- `references/github-integration.md` (modify — fill 3 `_deferred to P03_` rows + relabel 3 `### TODO P03:` stubs to `### TODO P04:` + author Re-init Adoption Contract subsection + update Scope Boundary P03 column)
- `tests/fixtures/m013-p03/re-init-adoption/` (create — directory tree)
- `tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/` (create — seed milestone/phase/task layout for re-init walker)
- `tests/fixtures/m013-p03/re-init-adoption/expected-readopt-manifest.txt` (create — pinned manifest snapshot)
- `tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/` (create — canned `gh` responses for marker-bearing remote)
- `scripts/verify/graphql-call-shape.sh` (create — repo-wide CI lint)
- `scripts/verify/m013-p03-re-init-fixture.sh` (create)
- `scripts/verify/m013-p03-github-common-readopt.sh` (create)
- `scripts/verify/m013-p03-re-init-adoption.sh` (create)
- `scripts/verify/m013-p03-re-init-auto-mode.sh` (create)
- `scripts/verify/m013-p03-graphql-call-shape-selftest.sh` (create)
- `scripts/verify/m013-p03-reference-extensions.sh` (create)
- `scripts/verify/m013-p03-bash32-compat.sh` (create)
- `scripts/verify/m013-p03-phase-suite.sh` (create)
