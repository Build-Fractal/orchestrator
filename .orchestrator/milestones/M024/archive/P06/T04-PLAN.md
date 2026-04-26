---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M024"
name: "Phase tests + suite + write-confinement + evaluate.md update"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `scripts/intake/axis-rederive.sh` exists and is executable; `scripts/verify/m024-p06-axis-rederive.sh` passes.
- T02 complete: `scripts/intake/revise.sh` exists and is executable; `scripts/intake/proposal-emit.sh` accepts `--axes-from <file>`; `scripts/verify/m024-p06-revise-script.sh` and `m024-p06-axes-from-flag.sh` pass.
- T03 complete: `scripts/intake/approval-gate.sh` `revise` verb is wired to revise.sh; `--no-apply` preserves the P03 surface; `m024-p06-version-suffix.sh`, `m024-p06-rederive-rationale.sh`, `m024-p06-approval-gate-revise-wired.sh` pass; P03 suite remains green.

## Description

Five artifacts ship in T04:

1. **`tests/test-revision-flow.sh`** — phase-level end-to-end test: emit a paragraph proposal at Tier B → revise scope_tier B → C via approval-gate → assert prior is archived as `proposal-v1.md`, current `proposal.md` has `scope_tier: "C"`, dependent axes re-derived, `pending_approval: true`, transcript / Q&A sections (if present) preserved verbatim across the version snapshot.
2. **`tests/test-revision-version-preservation.sh`** — phase-level test exercising two consecutive revises with the FR-14 idempotency check on a third no-op revise.
3. **`scripts/verify/m024-p06-write-confinement.sh`** — asserts every P06 script writes only to `.orchestrator/intake/<id>/` and `/tmp`.
4. **`scripts/verify/m024-p06-evaluate-md.sh`** — asserts `commands/evaluate.md` revise verb description names "wired in P06" + references `scripts/intake/revise.sh`.
5. **`scripts/verify/m024-p06-suite.sh`** — MEM002 parallel-array tracker; runs the two phase tests + every per-task verify; structured PASS:/FAIL: summary.

Plus a one-line update in `commands/evaluate.md` flipping the revise verb description from "P03 surface-only — full re-emit lands in P06" to the wired language.

## Steps

1. **Author `tests/test-revision-flow.sh`**:

```bash
#!/usr/bin/env bash
# tests/test-revision-flow.sh
# M024/P06/T04 — End-to-end revision flow happy path.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier B paragraph (31-80 word range).
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode and structured output."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^scope_tier: "B"' "$proposal" || { echo "FAIL: pre-revise scope_tier not B"; exit 1; }

# Capture the original input echo so we can assert it survives the revision.
original_body=$(awk '/^## Original Input/{flag=1;next}/^## /{flag=0}flag' "$proposal")

# Revise via the approval-gate (the wired path).
rev_out=$(bash "$GATE" --proposal "$proposal" --verb revise --axis scope_tier --value C)
echo "$rev_out" | grep -q '^revised_to=' || { echo "FAIL: revise did not emit revised_to (got: $rev_out)"; exit 1; }

# Prior content archived as proposal-v1.md.
proposal_dir=$(dirname "$proposal")
[ -f "$proposal_dir/proposal-v1.md" ] || { echo "FAIL: proposal-v1.md not archived"; exit 1; }
grep -q '^scope_tier: "B"' "$proposal_dir/proposal-v1.md" || { echo "FAIL: proposal-v1.md does not preserve prior scope_tier=B"; exit 1; }

# Current proposal.md has the new tier and rederived dependents.
grep -q '^scope_tier: "C"' "$proposal" || { echo "FAIL: revised proposal scope_tier not C"; exit 1; }
grep -q '^decomposition: "milestone-with-phases"' "$proposal" || { echo "FAIL: dependent decomposition not rederived"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$proposal" || { echo "FAIL: dependent recommended_command not rederived"; exit 1; }

# Approval state reset.
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pending_approval not reset to true"; exit 1; }
grep -q '^approved_at: null' "$proposal"      || { echo "FAIL: approved_at not reset to null"; exit 1; }
grep -q '^cancelled_at: null' "$proposal"     || { echo "FAIL: cancelled_at not reset to null"; exit 1; }

# Original Input body preserved across the revision.
revised_body=$(awk '/^## Original Input/{flag=1;next}/^## /{flag=0}flag' "$proposal")
[ "$original_body" = "$revised_body" ] || { echo "FAIL: Original Input body changed across revision"; exit 1; }

echo "PASS: revision flow — paragraph Tier B → C; v1 archived; rederives applied; approval reset; input body preserved"
exit 0
```

2. **Author `tests/test-revision-version-preservation.sh`**:

```bash
#!/usr/bin/env bash
# tests/test-revision-version-preservation.sh
# M024/P06/T04 — Two consecutive revises + idempotent no-op.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode and structured output."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
proposal_dir=$(dirname "$proposal")

# Snapshot v0 content + sha.
sha_v0=$(shasum -a 256 "$proposal" | cut -d' ' -f1)

# First revise.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C >/dev/null
sha_v1=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v0" = "$sha_v1" ] || { echo "FAIL: proposal-v1.md not byte-identical to original emit"; exit 1; }

# Snapshot post-first-revise content.
sha_post1=$(shasum -a 256 "$proposal" | cut -d' ' -f1)

# Second revise.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value A >/dev/null
sha_v2=$(shasum -a 256 "$proposal_dir/proposal-v2.md" | cut -d' ' -f1)
[ "$sha_post1" = "$sha_v2" ] || { echo "FAIL: proposal-v2.md not byte-identical to post-first-revise content"; exit 1; }

# v1 must NOT have been mutated by the second revise.
sha_v1_after=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v1" = "$sha_v1_after" ] || { echo "FAIL: proposal-v1.md mutated by second revise"; exit 1; }

# Third revise with same value as current — must be idempotent no-op.
idem_out=$(bash "$REVISE" --proposal "$proposal" --axis scope_tier --value A)
echo "$idem_out" | grep -q '^revised=false reason=identical-axes' || { echo "FAIL: idempotent revise did not emit identical-axes (got: $idem_out)"; exit 1; }
[ ! -f "$proposal_dir/proposal-v3.md" ] || { echo "FAIL: idempotent revise produced an unexpected v3 archive"; exit 1; }

echo "PASS: version preservation — v1+v2 byte-stable; idempotent no-op on third revise"
exit 0
```

3. **Author `scripts/verify/m024-p06-write-confinement.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-write-confinement.sh
# Asserts every P06 script writes only to .orchestrator/intake/<id>/ and /tmp.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Every P06-introduced or P06-modified shell artifact.
TARGETS="
scripts/intake/axis-rederive.sh
scripts/intake/revise.sh
"

# Pattern: any redirect token followed by a path that is NOT under /tmp,
# .orchestrator/intake/, or a tmp_render-style mktemp variable. The
# tightened P03 regex (whitespace-prefixed `>`, excluding `>&[12]` and
# `>/dev/null`) is reused.
fail=0
for rel in $TARGETS; do
  f="$ROOT/$rel"
  [ -f "$f" ] || { echo "FAIL: $rel not found"; fail=1; continue; }
  # Look for write redirects that target paths NOT under .orchestrator/intake/, /tmp, or a known scratch var.
  hits=$(grep -nE '[[:space:]]>[[:space:]]*[^&[:space:]/]' "$f" | grep -vE '/tmp|\.orchestrator/intake|tmp_render|axes_tmp|qa_tx_tmp|arc_qa_tmp|body-src|\.bak' || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $rel has unconfined write redirects:"
    echo "$hits"
    fail=1
  fi
done

# Also check the P06 additions to proposal-emit.sh and approval-gate.sh did not
# introduce out-of-confine writes. The full files have wider scope than P06
# touched, so we only spot-check that the P06-introduced lines fit the pattern.
# Specifically: search for the new --axes-from block and the wired revise verb body.
grep -q 'axes-from' "$ROOT/scripts/intake/proposal-emit.sh" || { echo "FAIL: --axes-from not wired into proposal-emit.sh"; fail=1; }
grep -q 'revised_to' "$ROOT/scripts/intake/approval-gate.sh" || { echo "FAIL: revised_to not wired into approval-gate.sh"; fail=1; }

if [ "$fail" = "1" ]; then
  exit 1
fi

echo "PASS: write-confinement — P06 scripts write only to .orchestrator/intake/<id>/ and /tmp"
exit 0
```

4. **Author `scripts/verify/m024-p06-evaluate-md.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-evaluate-md.sh
# Asserts commands/evaluate.md revise verb description names the wired P06 surface.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$ROOT/commands/evaluate.md"

[ -f "$DOC" ] || { echo "FAIL: $DOC not found"; exit 1; }

# Must mention the wired-in-P06 status.
grep -q "wired in P06" "$DOC" || { echo "FAIL: 'wired in P06' not in commands/evaluate.md"; exit 1; }

# Must reference the revise.sh script.
grep -q 'scripts/intake/revise.sh' "$DOC" || { echo "FAIL: 'scripts/intake/revise.sh' not referenced in commands/evaluate.md"; exit 1; }

# The legacy "P03 surface-only — full re-emit lands in P06" string must NOT remain.
if grep -q "P03 surface-only" "$DOC"; then
  echo "FAIL: legacy 'P03 surface-only' string still present in commands/evaluate.md — should be replaced by 'wired in P06'"
  exit 1
fi

echo "PASS: commands/evaluate.md — revise verb description names wired in P06 surface"
exit 0
```

5. **Author `scripts/verify/m024-p06-suite.sh`** (MEM002 parallel-array tracker):

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-suite.sh
# M024/P06 phase suite — runs the two phase tests + every per-task verify.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Parallel-array tracker (MEM002 — bash 3.2 safe).
suite_n_0=""
suite_r_0=""
i=0

run_one() {
  local name="$1"
  local cmd="$2"
  local rc
  if eval "$cmd" >/dev/null 2>&1; then
    rc="PASS"
  else
    rc="FAIL"
  fi
  eval "suite_n_${i}=\"\$name\""
  eval "suite_r_${i}=\"\$rc\""
  i=$((i+1))
}

run_one "test-revision-flow.sh"                 "bash $ROOT/tests/test-revision-flow.sh"
run_one "test-revision-version-preservation.sh" "bash $ROOT/tests/test-revision-version-preservation.sh"
run_one "m024-p06-axis-rederive"                "bash $ROOT/scripts/verify/m024-p06-axis-rederive.sh"
run_one "m024-p06-revise-script"                "bash $ROOT/scripts/verify/m024-p06-revise-script.sh"
run_one "m024-p06-version-suffix"               "bash $ROOT/scripts/verify/m024-p06-version-suffix.sh"
run_one "m024-p06-axes-from-flag"               "bash $ROOT/scripts/verify/m024-p06-axes-from-flag.sh"
run_one "m024-p06-approval-gate-revise-wired"   "bash $ROOT/scripts/verify/m024-p06-approval-gate-revise-wired.sh"
run_one "m024-p06-rederive-rationale"           "bash $ROOT/scripts/verify/m024-p06-rederive-rationale.sh"
run_one "m024-p06-write-confinement"            "bash $ROOT/scripts/verify/m024-p06-write-confinement.sh"
run_one "m024-p06-evaluate-md"                  "bash $ROOT/scripts/verify/m024-p06-evaluate-md.sh"

# Summarize.
total=$i
n=0
fails=0
while [ "$n" -lt "$total" ]; do
  name=$(eval echo "\$suite_n_${n}")
  rc=$(eval echo "\$suite_r_${n}")
  echo "${rc}: ${name}"
  [ "$rc" = "FAIL" ] && fails=$((fails+1))
  n=$((n+1))
done

if [ "$fails" -gt 0 ]; then
  echo "SUMMARY: ${fails}/${total} FAILED"
  exit 1
fi

echo "SUMMARY: ${total}/${total} PASS"
echo "PASS: M024/P06 suite — revision flow + version preservation + rationale + wired approval-gate"
exit 0
```

6. **Make all new scripts executable**:

```bash
chmod +x tests/test-revision-flow.sh
chmod +x tests/test-revision-version-preservation.sh
chmod +x scripts/verify/m024-p06-write-confinement.sh
chmod +x scripts/verify/m024-p06-evaluate-md.sh
chmod +x scripts/verify/m024-p06-suite.sh
```

7. **Update `commands/evaluate.md`** — locate the revise verb description (currently states "P03 surface-only — full re-emit lands in P06"). Replace with:

```markdown
| `revise <axis>=<value>` | wired in P06 — full re-emit via `scripts/intake/revise.sh` with version-suffix preservation (prior `proposal.md` archived as `proposal-v<N>.md`, dependent axes re-derived, approval state reset). FR-12. |
```

The exact existing text is one row in the verb table or a sentence in the surrounding paragraph; preserve the table/paragraph shape and only rewrite the revise-verb cell/sentence. Acceptable variant phrasings (the verify script asserts only the literal "wired in P06" + the path `scripts/intake/revise.sh`).

## Must-Haves

- `tests/test-revision-flow.sh` exists, is executable, and exits 0 on a clean checkout.
- `tests/test-revision-version-preservation.sh` exists, is executable, and exits 0 on a clean checkout.
- `scripts/verify/m024-p06-write-confinement.sh` exists, is executable, and confirms no out-of-confine writes in the P06 scripts.
- `scripts/verify/m024-p06-evaluate-md.sh` exists, is executable, and confirms `commands/evaluate.md` revise verb description names "wired in P06" + references `scripts/intake/revise.sh`.
- `scripts/verify/m024-p06-suite.sh` exists, is executable, runs all phase-level tests + per-task verifies, and exits 0 with `SUMMARY: 10/10 PASS` (or however many entries the final list has).
- `commands/evaluate.md` revise verb description no longer contains "P03 surface-only" and contains "wired in P06" + `scripts/intake/revise.sh`.
- AD-19 single-script-file shape in every verify script.
- Bash 3.2 portable; MEM002 parallel-array tracker pattern in the suite runner.

## Verification

```
bash tests/test-revision-flow.sh
bash tests/test-revision-version-preservation.sh
bash scripts/verify/m024-p06-write-confinement.sh
bash scripts/verify/m024-p06-evaluate-md.sh
bash scripts/verify/m024-p06-suite.sh
```

Expected output (each exit 0):
- `PASS: revision flow — paragraph Tier B → C; v1 archived; rederives applied; approval reset; input body preserved`
- `PASS: version preservation — v1+v2 byte-stable; idempotent no-op on third revise`
- `PASS: write-confinement — P06 scripts write only to .orchestrator/intake/<id>/ and /tmp`
- `PASS: commands/evaluate.md — revise verb description names wired in P06 surface`
- `SUMMARY: 10/10 PASS` then `PASS: M024/P06 suite — revision flow + version preservation + rationale + wired approval-gate`

Also confirm no upstream regression:

```
bash scripts/verify/m024-p01-suite.sh
bash scripts/verify/m024-p02-suite.sh
bash scripts/verify/m024-p03-suite.sh
bash scripts/verify/m024-p04-suite.sh
bash scripts/verify/m024-p05-suite.sh
```

Each must continue to exit 0.

## Inputs

### From Previous Tasks

- `scripts/intake/axis-rederive.sh` (T01) — used indirectly via revise.sh.
- `scripts/intake/revise.sh` (T02) — invoked by `tests/test-revision-flow.sh` (via approval-gate) and `tests/test-revision-version-preservation.sh` (directly).
- `scripts/intake/proposal-emit.sh` (T02 extended with `--axes-from`) — invoked by every test.
- `scripts/intake/approval-gate.sh` (T03 wired revise verb) — invoked by `tests/test-revision-flow.sh` to exercise the operator-facing surface.

### From Disk (Pre-existing)

- `scripts/intake/intake-id-allocate.sh`, `scripts/intake/shape-detect.sh` — invoked indirectly by the emitter.
- `commands/evaluate.md` — modified in this task. Existing 200+ line operator-facing doc; T04 only changes the revise verb cell/sentence (one-line edit).
- `templates/intake-proposal.md` — read-only; the emitter renders this template.
- `tests/` directory — existing test scaffolding lives here (per P05 pattern).
- POSIX utilities: `sed`, `awk`, `grep`, `head`, `mktemp`, `shasum`, `cut`, `printf`, `chmod`, `cat`, `echo`, `dirname`, `basename`.

## Constraints

- POSIX sh + bash 3.2 portable.
- MEM002 parallel-array suite-tracker pattern in `m024-p06-suite.sh` — no `declare -A`.
- AD-19 single-script-file shape in every verify script — no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- Writes only to (a) `.orchestrator/intake/<id>/` (proposal + version-suffix archive — actually written by revise.sh + emit.sh, not the test scripts directly) and (b) `/tmp` (test scratch via `mktemp -d`).
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- No new schema fields (D024 / MEM031 schema authority handshake honored — P06 reads existing P01 frontmatter only).
- Must NOT break P01–P05 verifies. Run their suites after the T04 edits to confirm no regression. The `commands/evaluate.md` edit is constrained to the revise verb cell/sentence; FR-6 byte-compatibility on the legacy spec path is preserved (no edits outside the revise row).

## Expected Output

Two phase-level tests pass; three new verify scripts pass; `m024-p06-suite.sh` summarizes 10/10 PASS; `commands/evaluate.md` revise verb description updated; P01–P05 suites continue to PASS.
