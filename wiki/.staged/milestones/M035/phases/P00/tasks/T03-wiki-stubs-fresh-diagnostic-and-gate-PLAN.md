---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M035"
name: "wiki-stubs-fresh-diagnostic-and-gate"
depends_on: ["T02"]
---

## Prerequisites

- `scripts/wiki/wiki-generate-stubs.sh` exists at the repo root (verified).
- `scripts/wiki/wiki-generate-nav.sh` exists at the repo root (verified).
- `scripts/lifecycle/wiki-init.sh` exists and contains `emit_pages_workflow()` at approximately line 481 (verified — the function HEREDOC ends at line 531).
- `wiki/docs/` and `wiki/mkdocs.yml` exist in the repo ([M032](../../../../../milestones/M032/index.md) / [M037](../../../../../milestones/M037/index.md) deliverables).

## Description

Layer 1 of `papercut-wiki-stub-drift.md`: ship `scripts/diagnostics/wiki-stubs-fresh.sh` + wire a pre-build gate into `wiki-init.sh emit_pages_workflow()`'s HEREDOC so that newly-generated `.github/workflows/pages.yml` files invoke the diagnostic before `mkdocs build`. Existing-workflow paths (the `[ -f "$PAGES_WF_TARGET" ] && return 0` branch at wiki-init.sh:483-486) stay untouched per CON-3 — operators with an authored workflow keep ownership.

The diagnostic compares committed wiki state against freshly-regenerated stubs/nav. If they diverge, the wiki was built against a stale plan-set and `mkdocs build` will fail with the cryptic include-markdown error. The diagnostic catches this loudly *before* mkdocs runs, with a clear regen-instruction message.

## Steps

1. **Author `scripts/diagnostics/wiki-stubs-fresh.sh`**. Contract:
   - Usage: `bash scripts/diagnostics/wiki-stubs-fresh.sh [--root <project-dir>]` (default root: `$PWD`).
   - Resolves `<root>` (must contain `wiki/docs/` and `wiki/mkdocs.yml` — exit 0 with informational `INFO: no wiki present, skipping freshness check` if absent, since not every project will have a wiki).
   - Creates a tmp dir under `$(mktemp -d -t wiki-stubs-fresh.XXXXXX)`.
   - Copies the existing `<root>/wiki/` tree into the tmp dir (or, more efficiently, runs the generators with output redirected to the tmp dir if they support an output-prefix flag — check `wiki-generate-stubs.sh --root` semantics; otherwise stage the wiki tree and regen in place inside the tmp).
   - Runs `bash scripts/wiki/wiki-generate-stubs.sh --root <tmp-dir>` and `bash scripts/wiki/wiki-generate-nav.sh --root <tmp-dir>`.
   - Diffs `<tmp-dir>/wiki/docs/` against `<root>/wiki/docs/` (filter to the auto-generated stub set — `wiki-generate-stubs.sh` knows which files it owns; check its CLEAN phase to identify the stub-set selector).
   - Diffs `<tmp-dir>/wiki/mkdocs.yml` against `<root>/wiki/mkdocs.yml` (the nav block is auto-generated; the rest is hand-authored — only diff the nav block, OR diff the whole file and document that any operator-authored mkdocs.yml change must go through the regen path).
   - Cleans up the tmp dir.
   - **On drift**: prints to stderr the list of drifted files, the regen command (`bash scripts/wiki/wiki-generate-stubs.sh && bash scripts/wiki/wiki-generate-nav.sh && git add wiki/`), and exits 2.
   - **On no drift**: prints `PASS: wiki-stubs-fresh (no drift; N stubs + nav verified against committed state)` and exits 0.
   - **On environment problem** (generators missing, can't write tmp): prints `FAIL: …` and exits 1.
   - Bash 3.2 compatible. No `<(...)`, no `mapfile`.

2. **Wire the pre-build gate into `wiki-init.sh emit_pages_workflow()`**. Modify the HEREDOC at `scripts/lifecycle/wiki-init.sh:488-531` to insert a gate step before `mkdocs build -f wiki/mkdocs.yml`. The new step:

   ```yaml
         - name: Verify wiki stubs are fresh
           run: bash scripts/diagnostics/wiki-stubs-fresh.sh --root .
   ```

   Insertion point: between the `pip install -r wiki/requirements.txt` line and the `mkdocs build -f wiki/mkdocs.yml` line. The CON-3 existing-workflow preservation branch at `wiki-init.sh:483-486` is unchanged — operators with an authored `pages.yml` keep ownership and must add the gate manually if they want it (document in the diagnostic's `INFO:` output).

3. **Surface a one-time advisory for existing-workflow projects**. In the existing-workflow branch (`wiki-init.sh:484`), extend the existing diagnostic message to mention the new gate: append ` Consider adding 'bash scripts/diagnostics/wiki-stubs-fresh.sh --root .' as a pre-build step (see papercut-wiki-stub-drift.md Layer 1)`. This is a stderr message only; no behavior change.

4. **Author the project-owned shape verifier** at `tools/verify/m035-p00-wiki-stubs-fresh.sh`. The verifier:
   - Asserts `scripts/diagnostics/wiki-stubs-fresh.sh` exists, is executable bit-set or sourced via `bash`, contains the substrings `wiki-generate-stubs.sh` and `wiki-generate-nav.sh`.
   - Runs `bash scripts/diagnostics/wiki-stubs-fresh.sh --root .` against the orchestrator repo (which has fresh stubs by construction). Asserts exit 0 and stdout contains `PASS: wiki-stubs-fresh`.
   - Stages a tmp project fixture: copies a minimal `<repo>/wiki/` skeleton under `$(mktemp -d)`, removes one stub file. Runs the diagnostic; asserts exit 2 and stderr contains `regen` (the regen-command hint).
   - Asserts the `wiki-init.sh emit_pages_workflow()` HEREDOC contains the `wiki-stubs-fresh.sh` invocation by grepping `scripts/lifecycle/wiki-init.sh` for the substring `bash scripts/diagnostics/wiki-stubs-fresh.sh` AND that the HEREDOC ordering is correct (the `wiki-stubs-fresh.sh` line precedes the `mkdocs build` line in the HEREDOC body — use `awk` to extract the HEREDOC range and check ordering).
   - Prints `PASS: m035-p00-wiki-stubs-fresh (diagnostic operates green-on-clean and red-on-drift; pages.yml HEREDOC includes pre-build gate)` or `FAIL: …`.
   - Bash 3.2 compatible.

5. **Run the verifier locally** to confirm green.

## Must-Haves

This task addresses two phase must-haves:

- "`scripts/diagnostics/wiki-stubs-fresh.sh` exists, is bash 3.2 compatible, accepts `--root <project-dir>` …"
- "`scripts/lifecycle/wiki-init.sh emit_pages_workflow()` HEREDOC includes a `bash scripts/diagnostics/wiki-stubs-fresh.sh` step before `mkdocs build` …"

## Verification

```bash
bash tools/verify/m035-p00-wiki-stubs-fresh.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install-claude-code.sh` (from T01, T02) — read-only consumed; the diagnostic does not interact with installers, but T03 lands in the same phase.

### From Disk (Pre-existing)

- `scripts/wiki/wiki-generate-stubs.sh` — pre-existing M012/P01 stub generator. Contract: `--root <project-root>` (default `$PWD`), `--dry-run`. Reads `wiki-scan-sources.sh` output, writes stubs to `<root>/wiki/docs/`. Exit 0 success, 1 scanner failure, 2 write error.
- `scripts/wiki/wiki-generate-nav.sh` — pre-existing M012/P01 nav generator. Same `--root` semantics. Modifies `<root>/wiki/mkdocs.yml`'s nav section.
- `scripts/lifecycle/wiki-init.sh` — modification target. `emit_pages_workflow()` is the function being extended. CON-3 preservation branch is untouched.
- `wiki/docs/`, `wiki/mkdocs.yml` — committed wiki state used as the diff baseline.

## Constraints

- Bash 3.2 compatible — no `<(...)`, no `mapfile`, no `${var^^}`.
- AP-009 shape-guard discipline — invocations are plain `bash <script> --flag …` shapes.
- CON-3 (M032): existing operator-authored `pages.yml` is preserved — gate insertion only happens in newly-emitted workflows.
- The diagnostic must NOT modify `<root>/wiki/` — it operates entirely against a tmp copy or generator-output redirected to a tmp dir.
- The diagnostic's exit codes are part of its contract: 0=fresh, 1=environment failure, 2=drift detected. Downstream callers (CI gate, optional `verify` integration) branch on these.

## Expected Output

`bash tools/verify/m035-p00-wiki-stubs-fresh.sh` exits 0 with stdout: `PASS: m035-p00-wiki-stubs-fresh (diagnostic operates green-on-clean and red-on-drift; pages.yml HEREDOC includes pre-build gate)`.

## Notes

- **`wiki-generate-stubs.sh --root` precise semantics**: the script's usage string says `--root PROJECT_ROOT` but the implementation may resolve relative paths against the source repo, not the `--root` arg. Verify by reading the script's `RESOLVED_ROOT` logic before authoring T03's diagnostic. If the generators only emit to the source-repo `wiki/`, the diagnostic must stage the entire wiki tree under `<tmp-dir>` and run the generators with `--root <tmp-dir>` to redirect output.
- **`commands/verify.md` integration is deferred**. Per the discuss-step resolution ("CI-gate-only initially"), the diagnostic is invokable from `orchestrator:verify` but not auto-wired. T03 does not modify `commands/verify.md`.
- **Layer 2 (Pages-deploy notification visibility) is out of scope**. Per the discuss-step resolution ("peel out as standalone install-template paper-cut"), Layer 2 ships independently of M035 closure. T03 does not author notification annotations.
- **Expected verifier output** (informational, not in `## Verification`): `PASS: m035-p00-wiki-stubs-fresh (diagnostic operates green-on-clean and red-on-drift; pages.yml HEREDOC includes pre-build gate)`.
