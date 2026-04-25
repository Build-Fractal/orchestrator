---
schema_version: "1.0"
task: "T03"
phase: "P02"
milestone: "M026"
name: "Dual-edition regression test with visible-skip annotations (FR-8 / SC-4 / SC-6 / DC-4)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: adapter's `check` stdout emits `edition=` and `reason=` lines.
- `tests/test-conversus-adapter-shim.sh` exists with stub-path sections (labeled 1, 1b, 2 per M026-CONTEXT.md DC-2).
- `.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md` is authoritative for the operator environment:
  - `ollama=absent` — the test's OSS-Anthropic branch cannot use ollama as a provider per the original plan (M026-CONTEXT.md OQ-3 resolution).
  - `paid_venv_conversus_binary_present=false` — paid is currently uninstalled; test must handle absence gracefully via `SKIP: paid build not installed`.
  - `oss_venv_conversus_binary_present=true` — OSS is installed at `~/.local/pipx/venvs/conversus/`.
- Parity-matrix row "Upstream PR #29" = `verified-absent` on OSS. Invoking OSS via `--provider anthropic` on OAuth credentials will hit a policy-gate 429 (see `references/architecture.md` "Conversus Adapter — Operator Notes").

## Description

Extend `tests/test-conversus-adapter-shim.sh` with a `CONVERSUS_INTEGRATION=1`-gated **dual-edition** block that exercises the adapter against both Conversus editions when both are installed. Under the current operator environment, both branches are visible-skip:

- **OSS-Anthropic branch**: `SKIP: known-upstream-429 (OSS lacks PR #29)` — OSS's `--provider anthropic` path cannot run against OAuth credentials because PR #29 is absent. The test annotates and skips rather than 429-ing and failing or masking the reality.
- **Paid branch**: `SKIP: paid build not installed` — paid's `conversus` pipx install is not present.

Visible-skip means the test prints the annotated `SKIP:` line to stdout and proceeds to the next branch (returns exit 0 at the branch level; the overall test exits 0 iff no branch fails). Silent-skip (running and pretending to pass) is forbidden.

The assertion contract, per DC-4, is **shape not value**: when a branch actually runs (both editions installed + running under `CONVERSUS_PROVIDER=claude-code` or a locally reachable non-Anthropic provider), it asserts identical exit codes and identical `gate-result.md` frontmatter key sets across editions via sorted-key diff (SC-6). No comparison of verdict values.

The stub-path sections (1, 1b, 2) are untouched.

## Steps

1. **Read the current test** at `tests/test-conversus-adapter-shim.sh` to locate:
   - The top-of-file section comment enumerating sections 1, 1b, 2 (stub-paths).
   - The existing `CONVERSUS_INTEGRATION=1` block (if any); if none, the dual-edition block is net-new at the end.
   - The venv-python lookup fallback chain at lines 119-124 (referenced by OQ-3 resolution).
2. **Add a new section 3** (dual-edition block) gated by `[ "${CONVERSUS_INTEGRATION:-0}" = "1" ]`. Structure:
   ```sh
   if [ "${CONVERSUS_INTEGRATION:-0}" = "1" ]; then
     # --- Section 3: dual-edition integration ---
     # Per M026/P02 FR-8, SC-4, SC-6 and M026-CONTEXT.md DC-4.
     echo "---- Section 3: dual-edition integration ----"

     # Resolve editions from the adapter's check subcommand.
     _s3_check="$(bash "$REPO_ROOT/scripts/dispatch/adapters/tool/conversus.sh" check 2>/dev/null || true)"
     _s3_oss_available="false"
     _s3_paid_available="false"
     # Edition is determined by what the current install advertises; the test
     # flips CONVERSUS_EDITION per branch to probe both. Absence detection
     # uses the venv-python `pip show conversus` Home-page same as the
     # adapter's metadata probe.
     _s3_venv_py="$HOME/.local/pipx/venvs/conversus/bin/python"
     if [ -x "$_s3_venv_py" ]; then
       _s3_home="$("$_s3_venv_py" -m pip show conversus 2>/dev/null | grep -E '^Home-page:' | head -n 1 | sed -E 's/^Home-page:[[:space:]]*//;s/[[:space:]]*$//')"
       case "$_s3_home" in
         *conversus-oss*) _s3_oss_available="true" ;;
         "") : ;;
         *) _s3_paid_available="true" ;;
       esac
     fi

     # OSS branch.
     if [ "$_s3_oss_available" = "true" ]; then
       if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ "${CONVERSUS_PROVIDER:-}" != "claude-code" ]; then
         # OSS direct-API Anthropic on OAuth hits PR #29 absence (verified-absent
         # in M026-CONVERSUS-PARITY.md). Visible-skip per OLLAMA-PROBE.md's
         # known-upstream-429 convention. Not a failure.
         echo "SKIP: known-upstream-429 (OSS lacks PR #29; set CONVERSUS_PROVIDER=claude-code or ANTHROPIC_API_KEY to actually run)"
       else
         # Real dual-edition run: invoke adapter gate against OSS.
         # Stub-mode fixture is used to keep the test deterministic under
         # CONVERSUS_INTEGRATION=1 (the integration contract is the
         # frontmatter shape + exit code, not the verdict value — see DC-4).
         # [implementation follows the existing section-1 stub-gate pattern,
         #  reusing the fixture at tests/fixtures/gate-result-pass.md, with
         #  CONVERSUS_EDITION=oss set for the invocation. Asserts exit 0
         #  and captures the produced gate-result.md key set.]
         CONVERSUS_EDITION=oss CONVERSUS_STUB=1 bash "$REPO_ROOT/scripts/dispatch/adapters/tool/conversus.sh" gate \
           spec-pressure-test "$REPO_ROOT/tests/fixtures/sample-spec.md" "$_s3_tmp/oss-gate.md"
         _s3_oss_rc=$?
         if [ $_s3_oss_rc -ne 0 ]; then
           echo "FAIL: section 3 OSS branch rc=${_s3_oss_rc}" >&2
           exit 1
         fi
         # Capture and store OSS frontmatter key set for the paid-side diff.
         grep -E '^[a-z_]+:' "$_s3_tmp/oss-gate.md" | sed -E 's/:.*$//' | sort -u > "$_s3_tmp/oss-keys.txt"
       fi
     else
       echo "SKIP: OSS not installed"
     fi

     # Paid branch.
     if [ "$_s3_paid_available" = "true" ]; then
       CONVERSUS_EDITION=paid CONVERSUS_STUB=1 bash "$REPO_ROOT/scripts/dispatch/adapters/tool/conversus.sh" gate \
         spec-pressure-test "$REPO_ROOT/tests/fixtures/sample-spec.md" "$_s3_tmp/paid-gate.md"
       _s3_paid_rc=$?
       if [ $_s3_paid_rc -ne 0 ]; then
         echo "FAIL: section 3 paid branch rc=${_s3_paid_rc}" >&2
         exit 1
       fi
       grep -E '^[a-z_]+:' "$_s3_tmp/paid-gate.md" | sed -E 's/:.*$//' | sort -u > "$_s3_tmp/paid-keys.txt"
     else
       echo "SKIP: paid build not installed"
     fi

     # SC-6: sorted-key diff when both ran.
     if [ -f "$_s3_tmp/oss-keys.txt" ] && [ -f "$_s3_tmp/paid-keys.txt" ]; then
       if ! diff -q "$_s3_tmp/oss-keys.txt" "$_s3_tmp/paid-keys.txt" >/dev/null; then
         echo "FAIL: section 3 frontmatter key-set diverges between OSS and paid" >&2
         diff "$_s3_tmp/oss-keys.txt" "$_s3_tmp/paid-keys.txt" >&2
         exit 1
       fi
       echo "PASS: section 3 frontmatter key sets match"
     fi

     echo "PASS: section 3 dual-edition integration"
   fi
   ```
3. **Adapt the block to the existing file's conventions**: variable naming (`_s3_*` avoids clashes with sections 1/1b/2); `REPO_ROOT` derivation should match the pattern already used at the top of the test file; `_s3_tmp` should be allocated via `mktemp -d` and trap-cleaned following the file's existing cleanup idiom.
4. **Verify the section 1/1b/2 stub-mode paths still work** — the dual-edition block must not introduce global variable pollution or trap clobbering.
5. **Write `scripts/verify/m026-p02-dual-edition-test-shape.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - `tests/test-conversus-adapter-shim.sh` contains a section-3 marker (`---- Section 3: dual-edition integration ----`) guarded by `CONVERSUS_INTEGRATION=1`.
   - The OSS branch contains the literal `known-upstream-429` skip annotation.
   - The paid branch contains the literal `paid build not installed` skip annotation.
   - The sorted-key diff pattern (`diff -q "$_s3_tmp/oss-keys.txt" "$_s3_tmp/paid-keys.txt"`) is present as the SC-6 contract.
   - Running `bash tests/test-conversus-adapter-shim.sh` without `CONVERSUS_INTEGRATION=1` exits 0 (stub-paths only; no regression).
   - Running `CONVERSUS_INTEGRATION=1 bash tests/test-conversus-adapter-shim.sh` exits 0 on the operator's current machine (OSS installed, paid absent) with visible-skip annotations for both branches (OSS-Anthropic OAuth path skips; paid absent skips).

## Must-Haves

Addresses phase must-haves:
- "Truth: dual-edition test with visible-skip annotations" (T03 owns)
- Artifact: `scripts/verify/m026-p02-dual-edition-test-shape.sh`

## Verification

```
bash scripts/verify/m026-p02-dual-edition-test-shape.sh
```

Must exit 0 and print `PASS: m026-p02-dual-edition-test-shape.sh`.

Additionally (smoke):

```
bash tests/test-conversus-adapter-shim.sh
CONVERSUS_INTEGRATION=1 bash tests/test-conversus-adapter-shim.sh
```

Both must exit 0. The `CONVERSUS_INTEGRATION=1` invocation prints at least one `SKIP:` line with `known-upstream-429` and at least one `SKIP:` line with `paid build not installed` (given the current operator environment).

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/tool/conversus.sh` (from T01)
  - Key API: `check` subcommand includes `edition=` / `reason=` lines; `gate` subcommand behavior unchanged under `CONVERSUS_STUB=1` (returns fixture).
  - Key behavior: respects `CONVERSUS_EDITION` per-branch when invoked.

### From Disk (Pre-existing)

- `tests/test-conversus-adapter-shim.sh` — target file. Existing stub-paths (sections 1, 1b, 2) must continue passing.
- `tests/fixtures/gate-result-pass.md`, `tests/fixtures/gate-result-block.md` — stub-mode fixtures. Read-only.
- `tests/fixtures/sample-spec.md` — if not present, author a minimal spec fixture (one header + one user-story block + one FR) so stub-gate has an artifact to cite. The stub path does not actually analyze the artifact; it just needs a readable path. If a canonical spec fixture already exists under `tests/fixtures/`, reuse it.
- `~/.local/pipx/venvs/conversus/bin/python` — used for metadata probe. Read-only.

## Constraints

- **CON-1** (adapter invariants): this task does not modify `conversus.sh`.
- **CON-2** (Bash 3.2): test file stays Bash 3.2 compatible (existing convention per MEM001).
- **DC-4** (shape-not-value contract): test asserts key-set equality via sorted-diff, never value equality.
- **OQ-3 resolution** (per OLLAMA-PROBE.md): ollama is absent → FR-8 OSS-Anthropic branch uses `skip-on-429` with `known-upstream-429` annotation. This is the operator-approved fallback posture for P02. If ollama becomes available later, a future task can switch the OSS branch to real `--provider ollama` execution; not P02 scope.
- **AD-6** (stub-path untouched): sections 1, 1b, 2 are not modified.
- **AD-19** (single-script-file Check shape): verifier script uses no inline compound bash that triggers the harness heuristic. Extract helper logic if needed.
- **Stderr/stdout discipline**: `SKIP:` / `PASS:` / `FAIL:` annotations go to stdout; diagnostic detail (the `diff` output on frontmatter-mismatch) goes to stderr.

## Expected Output

- `tests/test-conversus-adapter-shim.sh` — modified: new section-3 block added at end (before the final summary print, if one exists). Line count delta ≤ +90. No changes to sections 1, 1b, 2.
- `scripts/verify/m026-p02-dual-edition-test-shape.sh` — created (~50-80 lines).
- `bash scripts/verify/m026-p02-dual-edition-test-shape.sh` exits 0.
- `CONVERSUS_INTEGRATION=1 bash tests/test-conversus-adapter-shim.sh` exits 0 with visible-skip annotations naming `known-upstream-429` and `paid build not installed`.
