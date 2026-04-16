---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M015"
name: "Remove extension-validation test artifacts"
depends_on: ["T01"]
---

## Prerequisites

- T01 has completed: `extension.yml` has been deleted, the 9 dogfooded `/speckit.*` commands are gone, `.specify/scripts/bash/` is gone, and the 6 root-level spec-kit templates plus `.specify/templates/commands/` are gone.
- The repo currently contains 3 extension-shape test artifacts:
  - `scripts/verify/m002-p07-extension-registration.sh` (12 lines) — asserts `extension.yml` exists and registers the doctor command + 5 diagnostic scripts.
  - `tests/fixtures/verify-pass/extension.yml` (11 lines) — fixture used by extension-shape verification tests.
  - `tests/fixtures/verify-fail/extension.yml` (10 lines) — negative fixture for the same.

## Description

Decide the disposition of each extension-validation test artifact. Per the spec's FR-015, each is either deleted (if no standalone equivalent applies) or rewritten (if their underlying validation still has value in the standalone world).

For all 3 artifacts, the disposition is **delete**:

- `m002-p07-extension-registration.sh` asserts `extension.yml` registers commands and scripts. After T01, `extension.yml` does not exist. There is no standalone equivalent — the standalone orchestrator's command and script discovery is via skill files (`packaging/SKILL.md`, `packaging/bundle/skills/`), not a manifest. A standalone "command discovery" test would need a different shape entirely and belongs in M015 P04 (validation phase) or a future doctor enhancement, not as a renamed M002-era extension test.
- The two fixtures only exist to feed extension-shape tests. With the test gone and no other consumers, they are dead weight.

Then write a single verify script that confirms all 3 artifacts are absent.

## Steps

1. Delete `scripts/verify/m002-p07-extension-registration.sh`.
2. Delete `tests/fixtures/verify-pass/extension.yml`.
3. Delete `tests/fixtures/verify-fail/extension.yml`.
4. If `tests/fixtures/verify-pass/` and `tests/fixtures/verify-fail/` directories become empty as a result, remove the empty directories. (If they contain other fixture files unrelated to extension shape, leave them.)
5. Search the test suites for any harness that runs `m002-p07-extension-registration.sh`. The likely consumers are `tests/test-s04-core-commands.sh`, `tests/test-s07-integration.sh`, or a top-level test runner. If a runner calls this script by name, remove that call. Use:

   ```
   grep -rln 'm002-p07-extension-registration' tests/
   ```

   For each match, edit the file to remove the lines that invoke the deleted script. If removing the lines leaves a syntactically broken construct (an empty `for` loop, an empty `if` block), restructure so the surrounding test still passes.
6. Create `scripts/verify/m015-p01-no-extension-test-artifacts.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   test ! -e scripts/verify/m002-p07-extension-registration.sh || { echo "FAIL: m002-p07-extension-registration.sh still exists"; exit 1; }
   test ! -e tests/fixtures/verify-pass/extension.yml || { echo "FAIL: tests/fixtures/verify-pass/extension.yml still exists"; exit 1; }
   test ! -e tests/fixtures/verify-fail/extension.yml || { echo "FAIL: tests/fixtures/verify-fail/extension.yml still exists"; exit 1; }
   echo "PASS: all extension-validation test artifacts are absent"
   ```

7. Make the verify script executable.

## Must-Haves

- All 3 extension-shape test artifacts are absent.
- No retained test or runner attempts to invoke the deleted `m002-p07-extension-registration.sh`.
- The remaining test suites still parse and execute (no broken shell syntax left behind by removing test runner invocations).

## Verification

```
bash scripts/verify/m015-p01-no-extension-test-artifacts.sh
bash -n tests/test-s04-core-commands.sh
bash -n tests/test-s07-integration.sh
```

The first must print `PASS:` and exit 0. The two `bash -n` syntax checks must exit 0 (no parse errors).

## Inputs

### From Previous Tasks

- T01 has deleted `extension.yml`. This task's verify script does not depend on T01's outputs, but the disposition decision (delete, not rewrite) is justified by T01 having removed the underlying file the test asserts on.

### From Disk (Pre-existing)

- `scripts/verify/m002-p07-extension-registration.sh` — to be deleted
- `tests/fixtures/verify-pass/extension.yml` — to be deleted
- `tests/fixtures/verify-fail/extension.yml` — to be deleted
- `tests/test-s04-core-commands.sh`, `tests/test-s07-integration.sh`, and any other test runner — search for and remove invocations of the deleted script

## Constraints

- Hard delete only. Do not move the test to a `legacy/` directory.
- Do not invent a new "standalone command discovery" test in this task — that decision belongs in P04 if it's needed at all.
- If a test runner invokes the deleted script via a glob (`scripts/verify/m002-*.sh`), the glob may still be acceptable; verify that no runner has explicit name references that would fail.

## Expected Output

After this task:
- `git status` shows deletions for the 3 extension-shape artifacts and a new file `scripts/verify/m015-p01-no-extension-test-artifacts.sh`.
- If any test runner was edited, `git status` shows that modification too.
- The verify script prints `PASS:` and exits 0.
- All 7 test suites either pass or fail for reasons unrelated to the deleted extension-shape test (the latter is fine — P04 is the gate for full suite green; T02 only needs the *parsing* to be clean).
