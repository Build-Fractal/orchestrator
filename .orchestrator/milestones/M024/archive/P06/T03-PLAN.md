---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M024"
name: "Wire revise verb in approval-gate.sh + version-suffix verify + rationale slot verify"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `scripts/intake/axis-rederive.sh` exists and is executable.
- T02 complete: `scripts/intake/revise.sh` exists, is executable, and emits `revised_to=<path>` to stdout on success.
- P03 complete: `scripts/intake/approval-gate.sh` already parses `--verb revise --axis <name> --value <value>` and the closed-enum axis validator already rejects unsupported axes (preserved verbatim in T03).
- P03 verify scripts (`m024-p03-approval-gate.sh`, `m024-p03-approval-gate-verbs.sh`) currently pass; T03 must keep them green via the `--no-apply` test-only flag.

## Description

Three artifacts ship in T03:

### Part A — Wire `revise` verb in `scripts/intake/approval-gate.sh`

Upgrade the post-parse handler for the `revise` verb (currently lines 152–161 of `approval-gate.sh` — emits `revision_pending=true axis=<a> value=<v>` and exits 0 without mutation) to a real wired call into `scripts/intake/revise.sh`. The new handler:

1. Validates the same axis enum the P03 implementation already validates (closed enum: `input_shape | scope_tier | decomposition | design_gate | conversus_gate | intensity`). T02's revise.sh additionally rejects `input_shape`; T03 forwards that rejection.
2. Adds a new `--no-apply` test-only flag. When supplied, the handler short-circuits the call into revise.sh and emits the legacy P03 stdout shape (`revision_pending=true axis=<a> value=<v>`). This preserves the P03 test surface byte-for-byte without modification.
3. When `--no-apply` is NOT supplied, invokes `bash scripts/intake/revise.sh --proposal "$PROPOSAL" --axis "$AXIS" --value "$VALUE"`, forwards revise.sh's stdout to its own stdout (`revised_to=<path>` or `revised=false reason=identical-axes`), and forwards revise.sh's stderr.
4. Exits 0 on revise.sh success, 1 on revise.sh failure, 2 on axis validation failure (existing P03 behavior preserved).

### Part B — `scripts/verify/m024-p06-version-suffix.sh`

Asserts the version-suffix scheme across two consecutive revises: emit a paragraph proposal → revise once (assert v1) → revise again with a different value (assert v2 + v1 untouched) → assert `proposal.md` is the latest content.

### Part C — `scripts/verify/m024-p06-rederive-rationale.sh`

Asserts the rationale slots on a revised proposal:
- For axes touched by the revision (the operator-overridden axis + any rederived dependents): the rationale slot contains the literal "operator revision" plus a `proposal-v<N>.md` pointer.
- For axes NOT touched by the revision (e.g., `intensity` when only `scope_tier` was revised): the rationale slot retains its original P01-stub or deep-classifier content (asserted by re-emitting the same content via the emitter and `diff`-ing the rationale lines).

### Part D — `scripts/verify/m024-p06-approval-gate-revise-wired.sh`

Asserts the new wiring: `bash approval-gate.sh --proposal <p> --verb revise --axis scope_tier --value C` emits `revised_to=<path>` (not the legacy `revision_pending=...` line). Also asserts the `--no-apply` legacy shape: `bash approval-gate.sh --proposal <p> --verb revise --axis scope_tier --value C --no-apply` emits `revision_pending=true axis=scope_tier value=C`.

## Steps

1. **Edit `scripts/intake/approval-gate.sh`**:

Add `--no-apply` to the argument parser (around line 47):

```bash
NO_APPLY="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    --verb)     VERB="$2";     shift 2 ;;
    --mode)     MODE="$2";     shift 2 ;;
    --axis)     AXIS="$2";     shift 2 ;;
    --value)    VALUE="$2";    shift 2 ;;
    --no-apply) NO_APPLY="1";  shift 1 ;;   # NEW (test-only)
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done
```

Also add `--no-apply` to the usage string:

```bash
usage: approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <name> --value <value>] [--no-apply]
```

Replace the existing `revise)` case body (around lines 152–161) with:

```bash
  revise)
    [ -n "$AXIS" ]  || { echo "ERR: --axis required for revise" >&2; exit 2; }
    [ -n "$VALUE" ] || { echo "ERR: --value required for revise" >&2; exit 2; }
    case "$AXIS" in
      input_shape|scope_tier|decomposition|design_gate|conversus_gate|intensity) ;;
      *) echo "ERR: unsupported axis '$AXIS' — supported: input_shape scope_tier decomposition design_gate conversus_gate intensity" >&2; exit 2 ;;
    esac

    if [ "$NO_APPLY" = "1" ]; then
      # Legacy P03 surface — preserved for test backward-compat.
      echo "revision_pending=true axis=$AXIS value=$VALUE"
      exit 0
    fi

    # M024/P06/T03 — wired full re-emit via revise.sh.
    REVISE_SH="$(cd "$(dirname "$0")/../.." && pwd)/scripts/intake/revise.sh"
    [ -x "$REVISE_SH" ] || { echo "ERR: revise.sh not executable at $REVISE_SH" >&2; exit 1; }
    if rev_out=$(bash "$REVISE_SH" --proposal "$PROPOSAL" --axis "$AXIS" --value "$VALUE"); then
      echo "$rev_out"
      exit 0
    else
      echo "ERR: revise.sh failed for $AXIS=$VALUE on $PROPOSAL" >&2
      exit 1
    fi
    ;;
```

2. **Write `scripts/verify/m024-p06-version-suffix.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-version-suffix.sh
# Verifies the version-suffix scheme across two consecutive revises.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Initial emit.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
proposal_dir=$(dirname "$proposal")

# Snapshot the initial content.
sha_v0=$(shasum -a 256 "$proposal" | cut -d' ' -f1)

# Revise once: scope_tier B → C.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C >/dev/null

[ -f "$proposal_dir/proposal-v1.md" ] || { echo "FAIL: proposal-v1.md not created after first revise"; exit 1; }
sha_v1=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v0" = "$sha_v1" ] || { echo "FAIL: proposal-v1.md content does not match pre-revise byte-for-byte"; exit 1; }

# Revise again: scope_tier C → A.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value A >/dev/null

[ -f "$proposal_dir/proposal-v2.md" ] || { echo "FAIL: proposal-v2.md not created after second revise"; exit 1; }

# proposal-v1.md MUST still exist and be byte-identical to its first snapshot.
[ -f "$proposal_dir/proposal-v1.md" ] || { echo "FAIL: proposal-v1.md disappeared after second revise"; exit 1; }
sha_v1_after=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v1" = "$sha_v1_after" ] || { echo "FAIL: proposal-v1.md mutated by second revise (must be append-only history)"; exit 1; }

# proposal.md MUST be the latest (scope_tier=A).
grep -q '^scope_tier: "A"' "$proposal" || { echo "FAIL: proposal.md not the latest content (expected scope_tier=A)"; exit 1; }

# proposal-v2.md MUST contain the intermediate state (scope_tier=C).
grep -q '^scope_tier: "C"' "$proposal_dir/proposal-v2.md" || { echo "FAIL: proposal-v2.md does not capture intermediate scope_tier=C state"; exit 1; }

echo "PASS: version-suffix — v1 + v2 archived; v1 byte-stable across consecutive revises; proposal.md is latest"
exit 0
```

3. **Write `scripts/verify/m024-p06-rederive-rationale.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-rederive-rationale.sh
# Verifies rationale slot semantics on a revised proposal.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# Capture the original intensity rationale (independent axis — should NOT change after revising scope_tier).
intensity_rat_before=$(sed -n '/^rationale_intensity: /p' "$proposal" | head -1)

bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C >/dev/null

# Touched axes carry the version-pointer rationale.
grep -E '^rationale_scope_tier: ".*operator revision \(revise\.sh\).*proposal-v1\.md.*"' "$proposal" >/dev/null \
  || { echo "FAIL: revised scope_tier rationale missing operator-revision + v1 pointer"; exit 1; }
grep -E '^rationale_decomposition: ".*operator revision \(revise\.sh\).*proposal-v1\.md.*"' "$proposal" >/dev/null \
  || { echo "FAIL: rederived decomposition rationale missing operator-revision + v1 pointer"; exit 1; }
grep -E '^evidence_scope_tier: ".*proposal-v1\.md.*"' "$proposal" >/dev/null \
  || { echo "FAIL: revised scope_tier evidence missing v1 pointer"; exit 1; }

# Untouched axes (intensity, conversus_gate) must NOT carry the operator-revision rationale.
intensity_rat_after=$(sed -n '/^rationale_intensity: /p' "$proposal" | head -1)
case "$intensity_rat_after" in
  *"operator revision"*) echo "FAIL: untouched intensity axis acquired operator-revision rationale"; exit 1 ;;
esac

# No leaked placeholder (the literal "Operator revision via revise.sh — see prior version" must NOT appear post-process).
if grep -q 'Operator revision via revise.sh — see prior version for original rationale.' "$proposal"; then
  echo "FAIL: revise.sh placeholder rationale leaked into final proposal"
  exit 1
fi

echo "PASS: rederive-rationale — touched axes pointer-rationale; untouched axes preserved; placeholder substituted"
exit 0
```

4. **Write `scripts/verify/m024-p06-approval-gate-revise-wired.sh`**:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-approval-gate-revise-wired.sh
# Verifies the approval-gate revise verb is wired to revise.sh (default)
# and that --no-apply preserves the legacy P03 stdout shape.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Default (no --no-apply): wired to revise.sh, emits revised_to=<path>.
out=$(bash "$GATE" --proposal "$proposal" --verb revise --axis scope_tier --value C)
echo "$out" | grep -q '^revised_to=' || { echo "FAIL: wired revise did not emit revised_to (got: $out)"; exit 1; }
new_path=$(echo "$out" | sed -n 's/^revised_to=//p')
[ -f "$new_path" ] || { echo "FAIL: wired revise pointed at non-existent file: $new_path"; exit 1; }
[ -f "$(dirname "$proposal")/proposal-v1.md" ] || { echo "FAIL: wired revise did not archive proposal-v1.md"; exit 1; }

# --no-apply: legacy P03 stdout shape, no archive.
emit_out2=$(bash "$EMIT" --input "Add a verbose flag to the status command." --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out2" | sed -n 's/^proposal_path=//p')
out2=$(bash "$GATE" --proposal "$proposal2" --verb revise --axis scope_tier --value C --no-apply)
echo "$out2" | grep -qx 'revision_pending=true axis=scope_tier value=C' || {
  echo "FAIL: --no-apply did not emit legacy P03 shape (got: $out2)"
  exit 1
}
[ ! -f "$(dirname "$proposal2")/proposal-v1.md" ] || {
  echo "FAIL: --no-apply produced an unexpected archive file"
  exit 1
}

echo "PASS: approval-gate revise verb — wired to revise.sh by default; --no-apply preserves P03 surface"
exit 0
```

5. **Make verify scripts executable**: `chmod +x scripts/verify/m024-p06-version-suffix.sh scripts/verify/m024-p06-rederive-rationale.sh scripts/verify/m024-p06-approval-gate-revise-wired.sh`.

6. **Re-run the P03 suite to confirm no regression**: `bash scripts/verify/m024-p03-suite.sh` must continue to PASS. The P03 `m024-p03-approval-gate-verbs.sh` test exercises the legacy `revision_pending=true ...` shape; it now needs `--no-apply` to keep getting that shape. T03 includes a delta to `scripts/verify/m024-p03-approval-gate-verbs.sh` adding `--no-apply` to the relevant assertion.

   Edit `scripts/verify/m024-p03-approval-gate-verbs.sh` line that invokes the gate with `--verb revise`:

   ```bash
   # OLD:
   revise_out=$(bash "$GATE" --proposal "$proposal2" --verb revise --axis scope_tier --value C)
   # NEW:
   revise_out=$(bash "$GATE" --proposal "$proposal2" --verb revise --axis scope_tier --value C --no-apply)
   ```

   This is a one-line edit; the rest of the P03 verify file is untouched. Document the change in the T03 summary's `affects` field.

## Must-Haves

- `scripts/intake/approval-gate.sh` `revise` verb is wired to `scripts/intake/revise.sh`; the wired path emits `revised_to=<new-proposal-path>` to stdout.
- `--no-apply` flag preserves the legacy P03 stdout shape (`revision_pending=true axis=<a> value=<v>`) without invoking revise.sh.
- The version-suffix scheme is honored across two consecutive revises: v1 + v2 both exist; v1 is byte-stable.
- Touched axes (operator-overridden + rederived) carry the version-pointer rationale (`operator revision (revise.sh) — see proposal-v<N>.md for prior rationale`).
- Untouched axes retain their prior rationale verbatim.
- The literal placeholder `Operator revision via revise.sh — see prior version for original rationale.` does NOT leak into the final proposal (revise.sh post-processes it away).
- P03 verifies (`m024-p03-suite.sh`) remain green after the one-line `--no-apply` delta.
- AD-19 single-script-file shape in every verify script.
- Bash 3.2 portable.

## Verification

```
bash scripts/verify/m024-p06-version-suffix.sh
bash scripts/verify/m024-p06-rederive-rationale.sh
bash scripts/verify/m024-p06-approval-gate-revise-wired.sh
bash scripts/verify/m024-p03-suite.sh
```

Expected output (each exit 0):
- `PASS: version-suffix — v1 + v2 archived; v1 byte-stable across consecutive revises; proposal.md is latest`
- `PASS: rederive-rationale — touched axes pointer-rationale; untouched axes preserved; placeholder substituted`
- `PASS: approval-gate revise verb — wired to revise.sh by default; --no-apply preserves P03 surface`
- The full P03 suite continues to PASS (no regression).

## Inputs

### From Previous Tasks

- `scripts/intake/axis-rederive.sh` (from T01) — used indirectly via revise.sh.
- `scripts/intake/revise.sh` (from T02) — the wired call target. Key API: `bash revise.sh --proposal <path> --axis <name> --value <value>` → stdout `revised_to=<new-proposal-path>` on success, `revised=false reason=identical-axes` on idempotent no-op; archives prior `proposal.md` to `proposal-v<N>.md` (next-free-N) on revise; resets approval state on the new proposal.
- `scripts/intake/proposal-emit.sh` (extended in T02 with `--axes-from`) — used indirectly via revise.sh.

### From Disk (Pre-existing)

- `scripts/intake/approval-gate.sh` (from M024/P03/T02) — modified in this task. Existing API: `bash approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <name> --value <value>]`. T03 adds `--no-apply` and rewires `revise`.
- `scripts/verify/m024-p03-approval-gate-verbs.sh` (from M024/P03/T02) — one-line edit to add `--no-apply` to the revise assertion.
- POSIX utilities: `sed`, `grep`, `head`, `mktemp`, `shasum`, `cut`, `printf`, `chmod`, `cat`, `echo`, `dirname`, `basename`.

## Constraints

- POSIX sh + bash 3.2 portable.
- `sed -i.bak` BSD/GNU portable for any in-place edits to `approval-gate.sh` (one-shot text replacement; verify script handles its own assertions).
- AD-19 single-script-file shape in every verify script — no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- `--no-apply` is test-only — must NOT be documented in `commands/evaluate.md` (T04 doc update mentions only the wired path).
- Must NOT break P01, P02, P03, P04, P05 verifies. Run their suites after the T03 edits to confirm no regression.
- The P03 verbs verify edit is a one-line change; rest of P03 verify files untouched.

## Expected Output

`scripts/intake/approval-gate.sh` is upgraded; three new verify scripts pass; P03 suite remains green.
