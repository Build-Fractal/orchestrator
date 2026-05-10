---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M035"
provides:
  - "rollback-dispatch (--rollback flag in scripts/lifecycle/run-update.sh) + commands/update.md ## Rollback section with verbatim #Q-G8 advisory + two task-grain verifiers (m035-p05-rollback-driver-shape.sh BATTERY pass=4, m035-p05-update-skill-doc-shape.sh BATTERY pass=5)"
requires:
  - "from:P05/T01 what:.orchestrator/.previous-version five-field marker + .orchestrator/.rollback/manifest-<X>.txt snapshot,from:M025 what:installed-files.txt mode-aware schema,from:M027 what:.orchestrator/observability/<date>.jsonl convention"
affects:
  - "P05/T05 (consumes the dispatch surface for byte-equivalence acceptance test),P05/T06 (phase-suite aggregator chains both T02 verifiers),P03/P04/P06 (extend source-dispatch case arm: npm/homebrew/curl SKIPs become functional when channels close)"
key_files:
  - "scripts/lifecycle/run-update.sh,commands/update.md,tools/verify/m035-p05-rollback-driver-shape.sh,tools/verify/m035-p05-update-skill-doc-shape.sh"
key_decisions:
  - "D005 (consumed: rollback-marker schema five-field key=value sidecar plus snapshot),FR-12 (rollback-as-explicit-operator-action),FR-13 (multi-source dispatch via update_source config field),FR-15/FR-16 (M027 JSONL emission honored no new suppression knob),#Q-G8 (symlink/mixed-mode refusal with verbatim spec-amendment advisory),CON-7 (M025 reversibility-gate preserved -- snapshot replay restores prior manifest)"
patterns_established:
  - "rollback-as-pre-source-resolution-branch (refusal/error paths return before installer ever invoked),backslash-newline-continuation-as-verbatim-multiline-string (bash 3.2 honors trailing-backslash in double-quoted strings to span source lines while emitting single logical line),skeleton-with-extension-points-for-source-dispatch (git arm functional npm/homebrew/curl arms emit SKIP -- mirrors P02 T03 cross-channel pattern),asset-replay-via-tab-prefix-parameter-expansion (rel=line-up-to-first-tab without awk/cut POSIX-sh safe),detached-HEAD-checkout-and-restore (orig_head capture then non-destructive checkout of prior_commit_sha then restore)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P05/tasks/T02-rollback-dispatch-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-09T00:58:47Z"
---

## What was built

T02 — Rollback dispatch — extends `scripts/lifecycle/run-update.sh` with the FR-12 `--rollback` flag and `commands/update.md` with the operator-facing skill documentation. Three artifacts touched/created:

1. **`scripts/lifecycle/run-update.sh` extension** — adds `--rollback` to the arg-parse loop (sets `ROLLBACK=1`) and inserts the rollback dispatch block AFTER arg parsing and BEFORE the existing source-resolution + install-invocation flow. Branch behavior:
   - **Missing marker** → emit `FAIL: no prior version recorded — rollback unavailable` to stderr, exit 1.
   - **#Q-G8 symlink/mixed-mode refusal** → emit verbatim spec-amendment advisory (`rollback not available for symlink-mode installs — symlink-mode consumers are always at HEAD; to revert, run \`git checkout <prior-sha>\` in the orchestrator source repo.`) with `<prior-sha>` substituted by the marker's `prior_commit_sha` (literal `<prior-sha>` if empty), exit 1. Bash 3.2 backslash-newline-continuation inside double-quoted string preserves the verbatim wording across source lines.
   - **Missing snapshot** → emit `FAIL: prior manifest snapshot missing at <path> — rollback unavailable` to stderr, exit 1.
   - **`update_source` dispatch** — read from `.orchestrator/config.yml` `update_source:` field (defaults to `git` when absent or unset, per FR-13 / #Q-6). `git` arm is functional; `npm|homebrew|curl` arms emit `SKIP: rollback not yet implemented for source=<value>` and exit 1 (skeleton-with-extension-points pattern from P02 T03).
   - **`git` arm** — validates source repo is a git tree, validates `prior_commit_sha` is reachable via `git cat-file -e`, captures original HEAD, checks out the prior SHA (detached, non-destructive), replays each asset from the snapshot via `cp` for files / `cp -R` for directories, restores original HEAD.
   - **Common post-replay** — swaps `installed-files.txt` for the snapshot byte-for-byte, updates `rolled_at=` field with current ISO 8601 timestamp (sed in-place via tmp file), appends one `update_run` JSONL event to `.orchestrator/observability/<date>.jsonl` (FR-13 / FR-15 / [M027](../../../../../milestones/M027/index.md) convention), prints OK line, exits 0.

2. **`commands/update.md` extension** — new `## Rollback` section inserted before `## Output`. Documents behavior, the verbatim symlink-mode refusal advisory, missing-marker behavior, and the `npm`/`homebrew` `SKIP` stub.

3. **Two task-grain verifiers**:
   - `tools/verify/m035-p05-rollback-driver-shape.sh` (~140 lines, AD-19 single-script-file). Stages four fixtures under `/tmp/m035-p05-t02-driver-fixture-$$/`: missing-marker, symlink-mode marker, mixed-mode marker, copy-mode marker pointing at a non-existent snapshot. Asserts each branch exits non-zero with the documented stderr text. Symlink-mode and mixed-mode scenarios additionally assert `git checkout <prior_commit_sha>` substitution echoes the marker value verbatim (`abcd1234` for symlink fixture, `deadbeef` for mixed fixture). Emits `BATTERY: pass=4 fail=0`.
   - `tools/verify/m035-p05-update-skill-doc-shape.sh` (~75 lines, AD-19 single-script-file). Asserts `commands/update.md` carries: `## Rollback` heading, verbatim `rollback not available for symlink-mode installs` advisory, `.orchestrator/.previous-version` reference, `.orchestrator/.rollback/` reference, `SKIP: rollback not yet implemented for source=` stub statement. Emits `BATTERY: pass=5 fail=0`.

## Patterns established

- **Rollback-as-pre-source-resolution-branch** — the `--rollback` block hooks BEFORE the existing source-resolution + install logic in `run-update.sh`, so refusal/error paths return without ever touching the installer. Preserves existing non-rollback flow byte-equivalent for the install path.
- **Backslash-newline-continuation-as-verbatim-multiline-string** — bash 3.2 honors `\` at end-of-line inside double-quoted strings as line continuation, joining the next line's leading whitespace into the resolved value. Used to write the spec-amendment advisory across three source-code lines while emitting it as a single logical-line stderr message that pattern-matches T05's verbatim assertion.
- **Skeleton-with-extension-points for source dispatch** — `case "$update_source"` covers `git` functionally and stubs `npm|homebrew|curl` with a SKIP line; mirrors P02 T03's cross-channel-byte-equivalence pattern. P03/P04/P06 extend this dispatch identically.
- **Asset-replay via tab-prefix parameter expansion** — `rel="${asset_line%%	*}"` (literal tab character in pattern) extracts the relative path before the `\tmode:copy` suffix without invoking awk/cut. POSIX-sh + bash 3.2 safe.
- **Detached-HEAD checkout + restore** — `orig_head="$(git rev-parse HEAD)"` before the prior-sha checkout, `git checkout --quiet "$orig_head"` after the asset replay; non-destructive even if the source repo had a branch checked out.

## Verification

- `bash tools/verify/m035-p05-rollback-driver-shape.sh` → `BATTERY: pass=4 fail=0`
- `bash tools/verify/m035-p05-update-skill-doc-shape.sh` → `BATTERY: pass=5 fail=0`
- Regression: `bash tools/verify/m035-p05-rollback-marker-shape.sh` → `BATTERY: pass=6 fail=0` (T01, unchanged)
- Regression: `bash tools/verify/m035-p05-rollback-snapshot-presence.sh` → `BATTERY: pass=3 fail=0` (T01, unchanged)
- Regression: `bash scripts/lifecycle/run-update.sh --help` renders the extended docstring (Usage block now lists `[--rollback]` and a paragraph documenting #Q-G8 refusal semantics).

## Caveats

- **T05 is the byte-equivalence oracle, not T02** — T02 verifier only exercises the four refusal/error branches because they have no source-repo dependency. The actual `git` arm asset-replay loop (checkout / cp / restore HEAD) is exercised end-to-end by T05's `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` against a real source repo + real install fixture. T02 ships the dispatch + the verbatim refusal contract; SC-12 acceptance is T05's deliverable.
- **`update_source` reader is grep+sed not yaml-parser** — pulls from `^update_source:` line in `.orchestrator/config.yml` via grep/head/sed/tr (bash 3.2 safe, no jq/yq dependency). If the config carries multi-line YAML structures around the `update_source` key the reader still returns the first match because `head -1`. Edge case unlikely in practice (canonical shape is a single inline scalar) but worth noting if a future extension needs nested config.
- **`prior_commit_sha` empty-fallback** — when the marker has `prior_commit_sha=` empty, the symlink-mode advisory substitutes the literal string `<prior-sha>` per task plan. The `git` arm refuses with `FAIL: prior_commit_sha is empty — cannot pin rollback target` rather than letting `git cat-file` fail noisily on `^{commit}` against empty input.
- **No JSONL emission test in T02 verifier** — the `update_run` event append is not exercised in the T02 verifier (it requires the full `git` arm to fire, which T02 verifier does not exercise). T05 acceptance test covers this.
