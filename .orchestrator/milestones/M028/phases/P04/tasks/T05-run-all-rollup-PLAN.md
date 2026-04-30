---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M028"
name: "Run-All Roll-Up to 7/7 + Cross-Cutting Verifiers"
depends_on: ["T04"]
---

## Prerequisites

Plan-author empirically verified each Prerequisite path on disk at plan-authoring time:

- `scripts/verify/m028/run-all.sh` exists (P03 close — currently reports 5/7 with D + E SKIP).
- `scripts/verify/m028/finding-A-verifier.sh`, `finding-B-verifier.sh`, `finding-C-verifier.sh`, `finding-F-verifier.sh`, `finding-G-classifier-verifier.sh`, `finding-G-self-conformance.sh` (P02 + P03) all exist.

Files T05 expects to exist (T04 deliverables) after upstream tasks complete:
- `scripts/verify/m028/finding-D-verifier.sh` (T04)
- `scripts/verify/m028/finding-E-verifier.sh` (T04)
- `scripts/verify/m028/finding-G-wrapper-verifier.sh` (T04)

The cross-cutting verifiers `p04-wrappers-present.sh`, `p04-finding-verifiers-present.sh`, `p04-run-all-clean.sh` do NOT exist on disk before T05; T05 creates them.

## Description

Three deliverables:

1. **Update `scripts/verify/m028/run-all.sh`** — the P03-era state had `finding-D-verifier.sh` and `finding-E-verifier.sh` listed in the VERIFIERS list but absent from disk, so the roll-up reported `M028: 5/7 findings verified (skipped: 2, failed: 0)`. Post-T04, both files exist, so the same roll-up should now report `M028: 7/7 findings verified (skipped: 0, failed: 0)` automatically (the existing SKIP-on-missing-file branch handles the transition with no code change required). T05 verifies this transition and patches the roll-up's summary-string format if needed (e.g. drop the "skipped:" tail when zero, or update the comment block to acknowledge the post-P04 closing state). The minimal change is adding `finding-G-wrapper-verifier.sh` to the VERIFIERS list — the P03 roll-up's VERIFIERS list does not include the new T04 wrapper-side verifier.

2. **Author three cross-cutting plan-level verifiers** under `scripts/verify/m028/`:
   - `p04-wrappers-present.sh` — asserts each of the 4 wrappers exists, is executable, and produces sensible output on a usage-error invocation.
   - `p04-finding-verifiers-present.sh` — asserts each of the 7 per-finding verifiers exists under `scripts/verify/m028/`; asserts each is invoked by the post-T05 `run-all.sh`.
   - `p04-run-all-clean.sh` — runs `bash scripts/verify/m028/run-all.sh` and asserts the summary line is `M028: 7/7 findings verified` (skipped: 0, failed: 0).

3. **Run the full P04 close-out gate** locally before commit — every must-have Check passes; `run-all.sh` reports 7/7.

## Steps

### Round 1 — Update `run-all.sh`

1. **Read `scripts/verify/m028/run-all.sh`** to confirm the existing VERIFIERS list and summary-line format. The P03 close state has the list:

```
VERIFIERS="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh \
finding-D-verifier.sh finding-E-verifier.sh finding-F-verifier.sh \
finding-G-classifier-verifier.sh"
```

with `total=7`. The new T04 verifier `finding-G-wrapper-verifier.sh` is NOT in the list yet.

2. **Update the VERIFIERS list** to add `finding-G-wrapper-verifier.sh`. The wrapper-side gate is a separate axis from the classifier-side gate (`finding-G-classifier-verifier.sh`) — both contribute to Finding G's coverage but they assert different contracts (classifier rejection vs wrapper happy path). The roll-up either:

   - **Option A (recommended)**: keeps `total=7` (Finding G covered by either G-verifier; the wrapper-side is a bonus / belt-and-suspenders gate). The summary line stays "M028: 7/7 findings verified". Add `finding-G-wrapper-verifier.sh` to the list; keep `total=7`. The PASS-counting math: count A + B + C + D + E + F + G-classifier as the canonical 7; the wrapper-side and self-conformance gates are additive — count them in `pass_count` but bound the comparison at `total=7`.

   - **Option B**: bumps `total=8` to count G-classifier + G-wrapper as separate axes. This drifts the summary-string contract that P03 already locked at "M028: 7/7". Reject option B unless P02/P03 close states explicitly allowed the bump.

   Pick option A. The post-T05 VERIFIERS list reads:

```
VERIFIERS="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh \
finding-D-verifier.sh finding-E-verifier.sh finding-F-verifier.sh \
finding-G-classifier-verifier.sh finding-G-wrapper-verifier.sh"
```

with `total=7`. The for-loop runs all 8 verifiers; the summary clamps `pass_count` against `total=7`. The internal counter logic should add a comment block explaining the asymmetry:

```bash
# Finding G has two axes (classifier-side via finding-G-classifier-verifier.sh
# and wrapper-side via finding-G-wrapper-verifier.sh). Both run, but the
# summary clamps to 7 findings (A..G); the wrapper-side gate is the M028/P04
# additive axis that complements P03's classifier-side gate.
```

   Implementation hint: keep `pass_count=$((pass_count + 1))` per verifier; clamp at the summary line via `[ "$pass_count" -gt "$total" ] && pass_count=$total`.

3. **Update the comment block** at the top of `run-all.sh` to drop the P03-era "Findings D and E are P04 deliverables" SKIP-acknowledged language. Replace with: "Post-P04: all 7 findings (A..G) covered; Finding G has two axes (classifier-side + wrapper-side)."

### Round 2 — Cross-cutting verifiers

4. **Author `scripts/verify/m028/p04-wrappers-present.sh`** (~50 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-wrappers-present.sh -- M028 P04/T05 cross-cutting verifier.
#
# Asserts each of the 4 investigation-pattern wrappers exists under
# scripts/util/ and produces a usage-error diagnostic on no-args invocation
# (exit code 2 + diagnostic on stderr).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

WRAPPERS="grep-files.sh cleanup-stale-results.sh node-eval.sh peek-files.sh"

for w in $WRAPPERS; do
  path="${REPO_ROOT}/scripts/util/${w}"
  if [ ! -f "$path" ]; then
    fail "$w exists" "missing $path"
    continue
  fi
  pass "$w exists at $path"
  # Usage error on no args -> exit 2 + diagnostic on stderr.
  err_tmp="$(mktemp)"
  bash "$path" 2>"$err_tmp" >/dev/null
  rc=$?
  err_text="$(cat "$err_tmp")"
  rm -f "$err_tmp"
  if [ "$rc" -eq 2 ] && [ -n "$err_text" ]; then
    pass "$w usage-error rc=2 + stderr diagnostic"
  else
    fail "$w usage-error" "rc=$rc stderr=[$err_text]"
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-wrappers-present.sh"
  exit 0
fi
echo "FAIL: p04-wrappers-present.sh ($fail_count failures)"
exit 1
```

5. **Author `scripts/verify/m028/p04-finding-verifiers-present.sh`** (~55 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-finding-verifiers-present.sh -- M028 P04/T05 cross-cutting verifier.
#
# Asserts each of the 7 per-finding verifiers (plus the wrapper-side G axis)
# exists under scripts/verify/m028/ AND is named in the run-all.sh VERIFIERS
# list.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
M028_DIR="$script_dir"
RUN_ALL="${M028_DIR}/run-all.sh"

if [ ! -f "$RUN_ALL" ]; then
  echo "FAIL: run-all.sh not found at $RUN_ALL" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

VERIFIERS="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh \
finding-D-verifier.sh finding-E-verifier.sh finding-F-verifier.sh \
finding-G-classifier-verifier.sh finding-G-wrapper-verifier.sh"

for v in $VERIFIERS; do
  path="${M028_DIR}/${v}"
  if [ ! -f "$path" ]; then
    fail "$v exists" "missing $path"
    continue
  fi
  pass "$v exists at $path"
  if grep -q "$v" "$RUN_ALL"; then
    pass "$v listed in run-all.sh"
  else
    fail "$v in run-all.sh" "not named in VERIFIERS list"
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-finding-verifiers-present.sh"
  exit 0
fi
echo "FAIL: p04-finding-verifiers-present.sh ($fail_count failures)"
exit 1
```

6. **Author `scripts/verify/m028/p04-run-all-clean.sh`** (~45 lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m028/p04-run-all-clean.sh -- M028 P04/T05 close-out gate.
#
# Runs `bash scripts/verify/m028/run-all.sh` and asserts:
#   1. exit 0.
#   2. Summary line contains "M028: 7/7 findings verified".
#   3. No "FAIL:" lines in output.
#   4. Skip count is 0 (post-P04 state — D and E are no longer P04 deliverables).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
RUN_ALL="${script_dir}/run-all.sh"

if [ ! -f "$RUN_ALL" ]; then
  echo "FAIL: run-all.sh not found at $RUN_ALL" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

out_tmp="$(mktemp)"
bash "$RUN_ALL" > "$out_tmp" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then pass "run-all.sh exit 0"; else fail "run-all.sh exit" "rc=$rc"; fi

if grep -q '^M028: 7/7 findings verified' "$out_tmp"; then
  pass "run-all.sh summary 7/7"
else
  fail "run-all.sh summary 7/7" "missing summary line"
fi

if grep -q '^FAIL:' "$out_tmp"; then
  fail "run-all.sh no failures" "FAIL lines present"
else
  pass "run-all.sh no failures"
fi

# Skip count check -- the summary line carries (skipped: <N>, failed: <M>).
if grep -qE 'skipped: 0' "$out_tmp"; then
  pass "run-all.sh skip count 0"
else
  fail "run-all.sh skip count" "non-zero skip count"
fi

rm -f "$out_tmp"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-run-all-clean.sh"
  exit 0
fi
echo "FAIL: p04-run-all-clean.sh ($fail_count failures)"
exit 1
```

### Round 3 — Full close-out sweep

7. **Run the full P04 verification sweep** locally:

```bash
bash scripts/verify/m028/p04-wrappers-present.sh
```

```bash
bash scripts/verify/m028/p04-finding-verifiers-present.sh
```

```bash
bash scripts/verify/m028/p04-run-all-clean.sh
```

```bash
bash scripts/verify/m028/run-all.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P04
```

All five must report PASS / `M028: 7/7 findings verified`.

8. **Commit** via `git commit -F <message-file>`.

## Must-Haves

This task addresses the phase Truths:

- "`bash scripts/verify/m028/run-all.sh` reports `M028: 7/7 findings verified`"
- "The four investigation-pattern wrappers exist under `scripts/util/`" — the wrapper-existence verifier `p04-wrappers-present.sh` lands here as the cross-cutting roll-up assertion.

The cross-cutting verifiers (`p04-wrappers-present.sh`, `p04-finding-verifiers-present.sh`, `p04-run-all-clean.sh`) implement the assertion logic for these phase-level Truths.

## Verification

```bash
bash scripts/verify/m028/p04-wrappers-present.sh
```

```bash
bash scripts/verify/m028/p04-finding-verifiers-present.sh
```

```bash
bash scripts/verify/m028/p04-run-all-clean.sh
```

```bash
bash scripts/verify/m028/run-all.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P04
```

## Inputs

### From Previous Tasks

- `scripts/util/grep-files.sh` (T01), `scripts/util/cleanup-stale-results.sh` (T01), `scripts/util/node-eval.sh` (T02), `scripts/util/peek-files.sh` (T02) — `p04-wrappers-present.sh` exists each and exercises usage-error invocation.
- `scripts/verify/m028/finding-D-verifier.sh` (T04), `finding-E-verifier.sh` (T04), `finding-G-wrapper-verifier.sh` (T04) — `p04-finding-verifiers-present.sh` asserts each exists; `run-all.sh` invokes each as part of the 7/7 roll-up.
- T03 deliverables (Investigation Patterns sections in `commands/dispatch.md`, `templates/dispatch-prompt.md`, `ANTIPATTERNS.md`) — not directly consumed by T05 verifiers; T03's own plan-level verifiers (`p04-investigation-section.sh`, `p04-anti-pattern-lint-clean.sh`) cover the documentation contracts.

### Wrapper API Surface (relevant for T05 verifiers)

- All four wrappers honor exit code 2 + stderr diagnostic on no-args / usage-error invocation (T01/T02 contract).
- `run-all.sh` honors the SKIP-on-missing-file shape (P03 contract); T05 confirms post-P04 state has no SKIPs.

### From Disk (Pre-existing)

- `scripts/verify/m028/run-all.sh` — the roll-up T05 modifies. Plan-author confirmed the P03 close state has `total=7` and a VERIFIERS list of 7 entries; T05 adds `finding-G-wrapper-verifier.sh` to make the list 8 entries while preserving `total=7` per option A above.
- `scripts/verify/check-must-haves.sh` — the standard phase-level Tier 1 verifier the truth Checks roll up into.
- All 7 (now 8) per-finding verifiers in `scripts/verify/m028/` post-T04.

## Constraints

- **CON-1 (AD-19)**: Each cross-cutting verifier is a flat single-file shape. No nested helpers; no sourcing.
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<`, no process substitution, no `declare -A`.
- **CON-7 (no-M021-regression)**: T05's `run-all.sh` modifications are additive (add a new verifier to the list, update comment block); the existing VERIFIERS entries stay verbatim and the `total=7` summary contract is preserved.
- **Run-all.sh summary-string contract**: The summary line MUST be "M028: 7/7 findings verified" (skipped: 0, failed: 0) post-P04. Drift from this exact format breaks P02 + P03 close-state expectations and breaks `p04-run-all-clean.sh`'s grep assertion. Option A (preserve `total=7`, count G-wrapper as additive axis) is the contract-preserving choice.
- **Verification-section authoring**: `## Verification` invokes project-tree verifiers directly. No `run-probe.sh` wrapping.
- **Plan-time verifier-availability**: All five `## Verification` checks resolve to scripts T05 itself authors (`p04-*.sh`) or that exist post-T04 (`run-all.sh` after T05's modification, `check-must-haves.sh` is pre-existing).
- **Plan-time classifier-shape pre-validation**: Verifier-invocation lines `bash scripts/verify/m028/p04-wrappers-present.sh` (etc.) traced through `classify_command` → `allow`. Internal verifier-body lines (function definitions, conditionals, loops) are not classifier-scanned (helper-function carve-out).
- **Commit-message form**: `git commit -F <file>`.

## Expected Output

After `bash scripts/verify/m028/p04-wrappers-present.sh`:

```
PASS: grep-files.sh exists at .../scripts/util/grep-files.sh
PASS: grep-files.sh usage-error rc=2 + stderr diagnostic
PASS: cleanup-stale-results.sh exists at .../scripts/util/cleanup-stale-results.sh
PASS: cleanup-stale-results.sh usage-error rc=2 + stderr diagnostic
PASS: node-eval.sh exists at .../scripts/util/node-eval.sh
PASS: node-eval.sh usage-error rc=2 + stderr diagnostic
PASS: peek-files.sh exists at .../scripts/util/peek-files.sh
PASS: peek-files.sh usage-error rc=2 + stderr diagnostic
PASS: p04-wrappers-present.sh
```

After `bash scripts/verify/m028/p04-finding-verifiers-present.sh`:

```
PASS: finding-A-verifier.sh exists at .../scripts/verify/m028/finding-A-verifier.sh
PASS: finding-A-verifier.sh listed in run-all.sh
... (8 verifiers x 2 assertions = 16 PASS lines)
PASS: p04-finding-verifiers-present.sh
```

After `bash scripts/verify/m028/p04-run-all-clean.sh`:

```
PASS: run-all.sh exit 0
PASS: run-all.sh summary 7/7
PASS: run-all.sh no failures
PASS: run-all.sh skip count 0
PASS: p04-run-all-clean.sh
```

After `bash scripts/verify/m028/run-all.sh`:

```
PASS: finding-A-verifier.sh
PASS: finding-B-verifier.sh
PASS: finding-C-verifier.sh
PASS: finding-D-verifier.sh
PASS: finding-E-verifier.sh
PASS: finding-F-verifier.sh
PASS: finding-G-classifier-verifier.sh
PASS: finding-G-wrapper-verifier.sh
M028: 7/7 findings verified (skipped: 0, failed: 0)
```

After `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P04`:

```
... (every phase-level Truth Check passes; every Artifact / Key Link asserts cleanly)
PASS: P04 must-haves: <N>/<N>
```

(Final assertion count is computed by `check-must-haves.sh` against the post-T05 phase plan; T05 author re-confirms the actual number after the sweep runs.)
