---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M013"
name: "FR-15 --dry-run manifest emission + format contract"
depends_on: ["T02"]
---

## Prerequisites

- T02 has landed `scripts/integrations/github-init.sh` with the create-path implementation and emits UPSERT lines during walker iteration.
- FR-15 (from spec): "Both `init` and `sync` support a `--dry-run` that prints the upsert manifest... The manifest format is identical across `init --dry-run` and `sync --dry-run`." P02 pins the format now so P04 `sync --dry-run` (and P03 re-init's dry-run) consume it as a contract.
- Fixture tree at `tests/fixtures/m013-p02/` (T01) with `expected-manifest.txt` scaffold.
- `scripts/integrations/github-common.sh` + `scripts/integrations/github-init.sh` both already Bash 3.2 clean.

## Description

Pin the FR-15 `--dry-run` manifest format as a load-bearing contract. Author:

1. **Manifest emission helper** inside `github-common.sh` (not a new file) — `manifest_header <upserts> <skipped> <errors>` and `manifest_upsert_line <kind> <orchestrator-id> <target> <reason>` functions. These guarantee the format never drifts across `init` / `sync`.
2. **Format specification in doc-as-code**: extend `references/github-integration.md` with a pinned subsection "Dry-Run Manifest Format" (part of T05's Auth Modes block will reference this). Wording is pinned by T05, but the format string literals are authored here so T05 can cite them.
3. **Expected-manifest snapshot** at `tests/fixtures/m013-p02/expected-manifest.txt` — populated from a deterministic dry-run against the T01 fixture orchestrator-state tree. This snapshot is the SSOT the T07 gate diff's against.
4. **Format gate** — `scripts/verify/m013-p02-dry-run-manifest.sh` that runs `github-init.sh --dry-run --root tests/fixtures/m013-p02/orchestrator-state/ --repo-slug test/test` and diffs the output against `expected-manifest.txt`.

## Steps

### Step 1: Add manifest emission helpers to `github-common.sh`

Append to the library:

```bash
# --- FR-15 dry-run manifest format --------------------------------------------
#
# Format contract (pinned in P02; reused by P03 re-init and P04 sync):
#   Line 1 (header):
#     MANIFEST: <upserts> <skipped> <errors>
#   Line 2..N (one per resource):
#     UPSERT: <resource-kind> <orchestrator-id> <target> <reason>
#   Line N+1 (footer, also printed on live runs):
#     upserts=<N> skipped=<M> errors=<E>
#
# resource-kind: one of {milestone, project-v2, label, phase-issue,
#                        task-subissue, project-v2-item}
# orchestrator-id: M###-P##[-T##] or '-' for repo-level resources (labels, project-v2 root)
# target: GitHub URL, Issue number, Project v2 node id, or '-' for labels
# reason: one of {create, adopt, skip-existing-marker}

manifest_header() {
  # $1=upserts $2=skipped $3=errors
  printf 'MANIFEST: %s %s %s\n' "$1" "$2" "$3"
}

manifest_upsert_line() {
  # $1=kind $2=orchestrator-id $3=target $4=reason
  printf 'UPSERT: %s %s %s %s\n' "$1" "$2" "$3" "$4"
}

manifest_footer() {
  # $1=upserts $2=skipped $3=errors (printed on both dry-run and live)
  printf 'upserts=%s skipped=%s errors=%s\n' "$1" "$2" "$3"
}
```

### Step 2: Refactor `github-init.sh` to use the helpers

Replace any inline `echo "UPSERT: ..."` or `printf` statements in T02's walker with calls to `manifest_header` / `manifest_upsert_line` / `manifest_footer`. This is a refactor — no new behavior, just the contract surface.

Critical: under `--dry-run`, buffer the upsert lines and count `upserts` / `skipped` / `errors` before emitting the header. One clean approach:

```bash
manifest_body_file=$(mktemp)
upserts=0; skipped=0; errors=0
# ... walker iteration, appending to $manifest_body_file ...
for phase in $phases_to_project; do
  id=$(orchestrator_id_for "$milestone_dir" "$phase")
  reason="create"  # or compute per search-before-create
  manifest_upsert_line phase-issue "$id" "-" "$reason" >> "$manifest_body_file"
  upserts=$((upserts + 1))
done
# Emit header first, then the buffered body.
if [ "$DRY_RUN" -eq 1 ]; then
  manifest_header "$upserts" "$skipped" "$errors"
  cat "$manifest_body_file"
fi
manifest_footer "$upserts" "$skipped" "$errors"
rm -f "$manifest_body_file"
```

### Step 3: Generate `tests/fixtures/m013-p02/expected-manifest.txt`

Run the dry-run against the T01 fixture tree with stub responses enabled, capture stdout, and write verbatim to `tests/fixtures/m013-p02/expected-manifest.txt`. The fixture is the SSOT.

Example contents (format pinned; actual ids depend on T01 seed):

```
MANIFEST: 12 0 0
UPSERT: milestone M013 - create
UPSERT: project-v2 - - create
UPSERT: label - phase create
UPSERT: label - task create
UPSERT: label - uat-bug create
UPSERT: label - spec-gap create
UPSERT: phase-issue M013-P02 - create
UPSERT: task-subissue M013-P02-T01 - create
UPSERT: task-subissue M013-P02-T02 - create
UPSERT: project-v2-item M013-P02 - create
UPSERT: project-v2-item M013-P02-T01 - create
UPSERT: project-v2-item M013-P02-T02 - create
upserts=12 skipped=0 errors=0
```

(Planning-state phase P03 seeded by T01 MUST NOT appear in the manifest.)

### Step 4: Second-invocation idempotency contract

The expected-manifest snapshot is the FIRST dry-run. For T07's idempotency gate, T03 must also author a second expected manifest `tests/fixtures/m013-p02/expected-manifest-noop.txt` representing a second invocation with sidecar pre-populated (all items already cached). That manifest should be:

```
MANIFEST: 0 12 0
UPSERT: milestone M013 - skip-existing-marker
UPSERT: project-v2 - - skip-existing-marker
UPSERT: label - phase skip-existing-marker
UPSERT: label - task skip-existing-marker
UPSERT: label - uat-bug skip-existing-marker
UPSERT: label - spec-gap skip-existing-marker
UPSERT: phase-issue M013-P02 - skip-existing-marker
UPSERT: task-subissue M013-P02-T01 - skip-existing-marker
UPSERT: task-subissue M013-P02-T02 - skip-existing-marker
UPSERT: project-v2-item M013-P02 - skip-existing-marker
UPSERT: project-v2-item M013-P02-T01 - skip-existing-marker
UPSERT: project-v2-item M013-P02-T02 - skip-existing-marker
upserts=0 skipped=12 errors=0
```

### Step 5: Verify the format is Bash-3.2-clean and stable across P03/P04

Add a comment block at the top of the new `github-common.sh` section:

```
# FORMAT STABILITY CONTRACT (FR-15):
#   - Header line shape fixed: "MANIFEST: <u> <s> <e>" with single spaces.
#   - Body line shape fixed: "UPSERT: <k> <id> <t> <r>" with single spaces.
#   - Footer line shape fixed: "upserts=<N> skipped=<M> errors=<E>" without spaces around '='.
#   - Emit order: header first, then body lines in walker order (milestones,
#     project-v2, labels, phase-issues, task-subissues, project-v2-items),
#     then footer.
#   - P03 re-init adoption and P04 sync MUST reuse these helpers verbatim.
#     Changing this format is a breaking change requiring a spec amendment
#     and a version bump in the sidecar schema.
```

## Must-Haves

- `scripts/integrations/github-common.sh` contains `manifest_header`, `manifest_upsert_line`, `manifest_footer` functions with the exact printf format strings above.
- `scripts/integrations/github-init.sh` uses these helpers (no inline `printf "UPSERT: ..."` or `echo "MANIFEST: ..."`).
- `tests/fixtures/m013-p02/expected-manifest.txt` exists with the create-path manifest snapshot.
- `tests/fixtures/m013-p02/expected-manifest-noop.txt` exists with the second-invocation `skipped=N` snapshot.
- Bash 3.2 clean; anti-pattern-lint green.

## Verification

```bash
bash scripts/verify/m013-p02-dry-run-manifest.sh
```

Expected output:
```
PASS: manifest_header / manifest_upsert_line / manifest_footer defined in github-common.sh
PASS: github-init.sh uses the manifest helpers (no inline MANIFEST: / UPSERT: printfs)
PASS: --dry-run output matches expected-manifest.txt byte-identical
PASS: second --dry-run with sidecar populated matches expected-manifest-noop.txt
PASS: Planning-state phase P03 absent from manifest (AS-4a lazy projection honored)
```

Exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from T01; T03 extends with manifest helpers)
  - Key API to extend: add `manifest_header`, `manifest_upsert_line`, `manifest_footer`.
- `scripts/integrations/github-init.sh` (from T02; T03 refactors to use helpers)
  - Key API to change: replace inline `echo "UPSERT: ..."` with `manifest_upsert_line` calls in the walker.
  - Key types: the buffered `$manifest_body_file` tempfile pattern.
- `tests/fixtures/m013-p02/orchestrator-state/` (from T01)
  - Seed layout used to generate `expected-manifest.txt`.
- `tests/fixtures/m013-p02/gh-stub-responses/` (from T01)
  - Via `M013_GH_STUB_DIR` — preflight stubs used during snapshot generation.

### From Disk (Pre-existing)

- None beyond P01 deliverables already listed in T01/T02.

## Constraints

- **Format stability is LOAD-BEARING**: P03 re-init adoption + P04 sync `--dry-run` MUST consume this exact format. Any change here propagates across three downstream consumers.
- **Bash 3.2**: `printf` with `%s` placeholders only (no `%b` / `%q` which differ across shells). No `mapfile`, no `<(...)`.
- **Zero `gh` calls in the format gate**: the `m013-p02-dry-run-manifest.sh` gate runs `github-init.sh --dry-run` with `M013_GH_STUB_DIR` set.
- **Knowledge-Layer Boundary**: no SPEC-* frontmatter changes. No `KNOWLEDGE-INDEX.md` emissions.
- **AD-19 `Check:` shape**: the format gate itself is a single-script-file invocation.
- **No compound-chain commands in the plan's `Check:` line** — the gate does all the diff-ing internally.

## Expected Output

T07 phase-suite reports the dry-run-manifest gate PASS on green. Operator dogfood against a real GitHub repo confirms the live-run footer line matches the dry-run footer line (`upserts=N skipped=M errors=E`) — completing the FR-15 "identical across dry-run and live" contract.
