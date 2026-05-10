---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01.5"
milestone: "M035"
name: "C1 — Lowercase hyphenated path/repo basename sweep across *.md / *.yml / *.yaml"
depends_on: ["T03"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- T03 output on disk: zero residual `~/Sites/spec-kit-orchestrator`
  matches in non-historical files (the operator-path sweep is complete).
- The pre-T04 inventory is captured at task execution time:
  ```bash
  git grep -nE 'spec-kit-orchestrator' \
    | grep -vE '~?/Sites/' \
    > /tmp/m035-p015-c1-inventory.txt
  ```
  Expected hit zone: README.md (3 hits per the planning-time count),
  CLAUDE.md (1 hit), `.planning/speckit-orchestrator-playbook.md`
  (basename + content), various `*.md` / `*.yml` files outside the
  historical allowlist.

Pre-existing decisions consumed:

- [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") = `@build-fractal/orchestrator` (T01 D0XX block).
- RENAME-PLAN.md § 5 Commit 3 — the canonical sed pattern for this
  surface (`s/spec-kit-orchestrator/orchestrator/g` across `*.md`
  / `*.yml` / `*.yaml`).
- T01's legacy-namespace allowlist file
  (`tests/m035-acceptance/legacy-namespace-allowlist.txt`) — but note
  that file scopes SC-7 (the `speckit.orchestrator.*` cohort), NOT C1.
  The C1 historical allowlist is a separate (broader) set documented
  in step 1.

## Description

Sweep every `spec-kit-orchestrator` lowercase-hyphenated reference in
`*.md` / `*.yml` / `*.yaml` files (excluding the C1 historical
allowlist) and rewrite to `orchestrator`. T03 already removed the
`~/Sites/spec-kit-orchestrator` operator-path subset; T04 is the broad
remainder — README.md, CLAUDE.md, manifest files, doc cross-references.

The C1 historical allowlist (broader than the SC-7 allowlist because
C1 catches archived M0XX summaries, CHANGELOG entries, RENAME-PLAN.md,
papercut proposals, [M008](../../../../../milestones/M008/index.md) archives, etc.):

```text
references/RENAME-PLAN.md
docs/migrating-from-speckit.md
.orchestrator/proposals/papercut-sweep-pre-M030.md
.orchestrator/milestones/M008/archive/
.orchestrator/milestones/M0??/M0??-SUMMARY.md  # archived milestone summaries
.orchestrator/milestones/M0??/M0??-BODY.txt    # archived milestone bodies
CHANGELOG.md  # archived version-history entries (top section may need
              # T05 prose rewrite; archived entries stay)
.orchestrator/DECISIONS.md  # historical decision-records reference old name
.orchestrator/milestones/M035/phases/P01.5/  # phase planning artifacts
.orchestrator/KNOWLEDGE.md  # historical knowledge entries
specs/001-orchestrator/conversus-spec/  # archived conversus deliberation
specs/001-orchestrator/conversus-plan/  # archived conversus deliberation
```

## Steps

1. **Inventory the C1 surface at task execution time**:

   ```bash
   git grep -nE 'spec-kit-orchestrator' '*.md' '*.yml' '*.yaml' \
     > /tmp/m035-p015-c1-inventory.txt
   ```

   Read `/tmp/m035-p015-c1-inventory.txt`. Classify each line into:
   - `[C1-rewrite]` — non-historical operational/doc reference; rewrite
     to `orchestrator`.
   - `[HIST]` — historical/archived file per the allowlist above; do
     NOT edit.
   - `[REVIEW]` — context unclear (typically: a markdown link with
     hostname `github.com/Build-Fractal/spec-kit-orchestrator/...`,
     which becomes `github.com/Build-Fractal/orchestrator/...` via the
     auto-redirect — these are rewrites in C1 even though they mention
     the GitHub URL, because the URL surface is in-tree-rewritten;
     C8 covers the actual remote rename which is off-tree).

   GitHub URL clarification: in-tree references to
   `https://github.com/Build-Fractal/spec-kit-orchestrator/...` SHOULD
   be rewritten to `https://github.com/Build-Fractal/orchestrator/...`
   in T04 (C1 scope). The auto-redirect makes either form work, but
   the in-tree references should use the new canonical URL. The actual
   GitHub remote-rename operation is C8 (off-tree, T08 runbook).

2. **Spot-check expected hits (planning-time count)**:
   - `README.md` — 3 hits per the planning-time `grep -c`
   - `CLAUDE.md` — 1 hit (the `specs/001-speckit-orchestrator/spec.md`
     reference is T02's territory; remaining hit is the project name)
   - `.planning/speckit-orchestrator-playbook.md` — basename rename
     plus content. The basename rewrite is `git mv .planning/speckit-orchestrator-playbook.md
     .planning/orchestrator-playbook.md` (or similar — the operator-personal
     `.planning/` directory is convention-tracked, not strict; verify
     it is in `git ls-files` first; if not, skip — `.planning/` is
     `.gitignore`'d). Content rewrites apply if file is tracked.
   - YAML manifests under `packaging/` and elsewhere referencing the
     old project name in `name:` fields — rewrite each.

3. **Rewrite each `[C1-rewrite]` match via individual Edit calls**.
   Per AD-19 / CON-3, surface-by-surface; no compound `xargs sed` chain.
   Plain-text replace: `spec-kit-orchestrator` → `orchestrator`.
   Edge cases:
   - Sentence-prose where the rename is part of a longer description
     ("the spec-kit-orchestrator project is now called orchestrator")
     should be reread for sentence flow after the sed; don't leave
     "the orchestrator project is now called orchestrator" if it
     doesn't make sense.
   - Heading anchors derived from the old slug (e.g.
     `#spec-kit-orchestrator-section`) require updating both the
     heading itself AND any inbound link references; cross-check via
     `git grep '#spec-kit-orchestrator'` after the heading edits.

4. **Verify zero residual non-allowlisted matches**:

   ```bash
   git grep -nE 'spec-kit-orchestrator' '*.md' '*.yml' '*.yaml' \
     | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-[M030](../../../../../milestones/M030/index.md)\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-):'
   ```

   Expected output: empty.

5. **Author `tools/verify/m035-p015-c1-sweep.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-c1-sweep.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   residue=$(git grep -nE 'spec-kit-orchestrator' '*.md' '*.yml' '*.yaml' 2>/dev/null \
     | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-):' || true)
   if [ -n "$residue" ]; then
     echo "FAIL: residual spec-kit-orchestrator matches in non-historical *.md/*.yml/*.yaml files:" >&2
     echo "$residue" >&2
     exit 1
   fi
   echo "PASS: m035-p015-c1-sweep"
   exit 0
   ```

## Must-Haves

- Zero residual `spec-kit-orchestrator` matches in `*.md` / `*.yml` /
  `*.yaml` files outside the C1 historical allowlist
  - Check: `bash tools/verify/m035-p015-c1-sweep.sh`

## Verification

```bash
bash tools/verify/m035-p015-c1-sweep.sh
```

## Inputs

### From Previous Tasks

- T03: operator-environment paths swept; the `~/Sites/` subset is
  already removed before T04 runs.

### From Disk (Pre-existing)

- All `*.md` / `*.yml` / `*.yaml` files in the repo (T04 scope).
- `references/RENAME-PLAN.md` § 5 Commit 3 — runbook source.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: no compound chains.
- **AD-19 (single-script-file Check shape)**: one verifier script.
- **Sentence-flow preservation**: after `sed`-ish edits, reread
  surrounding prose. Per the RENAME-PLAN's "eyeball-not-sed" guidance
  for the broader rename, mechanical replacement can produce awkward
  prose like "the orchestrator project is now called orchestrator"
  where the original was "the spec-kit-orchestrator project is now
  called orchestrator". Hand-rewrite such cases for readability.

## Notes

- **Plan-phase verifier-availability cross-check (rule 2)**: T04
  authors `m035-p015-c1-sweep.sh` in step 5.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep;
  no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **`.planning/` may not be git-tracked**: `.planning/speckit-orchestrator-playbook.md`
  per the planning-time inventory is in `.planning/` which is typically
  `.gitignore`'d. Check `git ls-files .planning/` first; if untracked,
  the rename is operator-personal (T08 runbook); if tracked, it falls
  under T04 scope.
- **GitHub URL handling**: rewrite in-tree URL references to the new
  basename (`Build-Fractal/orchestrator`) regardless of the
  auto-redirect; the auto-redirect is the off-tree (C8) safety net.

## Expected Output

After T04 completes:

- Zero residual `spec-kit-orchestrator` matches in `*.md`/`*.yml`/`*.yaml`
  files outside the C1 historical allowlist.
- One verifier script exists under `tools/verify/`.
- README.md, CLAUDE.md, and any tracked YAML manifests carry the new
  `orchestrator` name throughout.
