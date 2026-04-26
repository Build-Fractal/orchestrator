---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M024"
name: "revise.sh + --axes-from extension to proposal-emit.sh"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/intake/axis-rederive.sh` exists, is executable, and emits `key=value` stdout lines for dependent-axis recomputations per the scope_tier and decomposition rule tables.
- P01 complete: `templates/intake-proposal.md` defines the 25-key frontmatter; `scripts/intake/proposal-emit.sh` exists and renders the template via `swap()` substitution against `{{placeholder}}` markers.
- P03 complete: `scripts/intake/approval-gate.sh` validates the closed-enum axis names (T02 reuses the same enum).
- P05 complete: `scripts/intake/proposal-emit.sh` already supports `--qa-answers-from <file>`. T02's new `--axes-from <file>` flag composes alongside it without conflict.

## Description

Two artifacts ship in T02:

### Part A — `scripts/intake/proposal-emit.sh` extension: `--axes-from <file>` flag

Extends the existing P01/P02/P03/P04/P05 emitter with a new `--axes-from <file>` flag. When supplied, the file is read as one `key=value` pair per line covering any subset of:

- `scope_tier=A|B|C`
- `decomposition=single-task|single-phase|milestone-with-phases|multi-milestone`
- `design_gate=none|walkthrough`
- `conversus_gate=<value>` (open-set passthrough)
- `intensity=Quick|Standard|Full`
- `recommended_command=orchestrator:dispatch|orchestrator:specify|orchestrator:roadmap`

Lines starting with `#` and blank lines are ignored. Unknown keys exit 2 with `ERR: unknown axes-from key '<k>' — supported: scope_tier decomposition design_gate conversus_gate intensity recommended_command`.

Each parsed value populates the corresponding override shell var (`scope_tier_override` etc.) — these are the same vars the paragraph-classify and spec-shape-classify branches already populate. The existing override-precedence block at lines 150–153 of `proposal-emit.sh` (today: `[ -n "${scope_tier_override:-}" ] && scope_tier="$scope_tier_override"`) covers them automatically.

A new `REVISE_AXES_DONE=1` flag is set when `--axes-from` is supplied. The rationale-loop (lines 354–366 of `proposal-emit.sh`) gets a new branch that skips the rationale slot for any axis whose key appeared in the axes-from file:

```bash
# REVISE_AXES_DONE — operator-driven revision overrides axes; rationale slots are filled by revise.sh post-emit.
if [ "${REVISE_AXES_DONE:-0}" = "1" ]; then
  case "$axis" in
    scope_tier|decomposition|design_gate|conversus_gate|intensity)
      # Skip — revise.sh will fill the rationale_<axis> + evidence_<axis> slots after the emitter returns.
      if echo "$REVISE_AXES_KEYS" | grep -qx "$axis"; then
        continue
      fi
      ;;
  esac
fi
```

The `REVISE_AXES_KEYS` shell var is built during axes-from parsing and contains a newline-separated list of the axis names actually present in the file (so revising only `scope_tier` doesn't skip the `intensity` rationale slot).

After the swap loop completes, the emitter writes a placeholder rationale for revised axes (the literal string `Operator revision via revise.sh — see prior version for original rationale.`) so the proposal does not ship with `{{rationale_<axis>}}` literals leaking into the body. revise.sh (Part B below) post-processes the emitted file to replace these placeholders with version-pointer rationales.

### Part B — `scripts/intake/revise.sh`

The user-facing revision driver. Steps in execution order:

1. **Parse arguments**: `--proposal <path>` plus one or more `--axis <name> --value <value>` pairs (repeatable). Validate axis names against the FR-12 closed enum (six routing axes). Reject `--axis input_shape` with `ERR: input_shape is not revisable; re-run orchestrator:evaluate from scratch` (exit 2).
2. **Confirm proposal exists**: missing path or non-existent file exits 1 with `ERR: proposal not found at <path>`.
3. **Read current proposal frontmatter values** for every axis the operator overrode. If every override is byte-identical to the current value, exit 0 with `revised=false reason=identical-axes` to stdout — FR-14 idempotency. Do NOT archive or re-emit.
4. **Confirm not double-finalized**: if `pending_approval: false` AND `approved_at: <ISO8601>` is present, emit a stderr advisory `WARN: revising an already-approved proposal — operator approval will be reset` but proceed.
5. **For each operator override, invoke axis-rederive.sh**: `bash scripts/intake/axis-rederive.sh --axis <a> --value <v> --proposal <proposal>`. Capture stdout and append to a tmp axes-from file (`/tmp/axes-from.<pid>.txt`).
6. **Append operator overrides AFTER the rederives** so operator overrides win on conflict (an operator who overrides both `scope_tier=C` *and* `decomposition=single-task` keeps `single-task`).
7. **Allocate next version suffix**: scan the proposal's directory for `proposal-v*.md`, extract the numeric suffix from each match, find the highest existing N (default 0), and use N+1.
8. **Archive the current `proposal.md`**: `mv "$proposal_dir/proposal.md" "$proposal_dir/proposal-v$N.md"`.
9. **Re-derive emitter inputs from the archived version**:
   - `--input <string>` from the archived proposal's `## Original Input` body section (or the `input_body` substituted text immediately after the `## Original Input` heading).
   - `--spec-path <path>` from the archived proposal's `feature_slug` frontmatter if it points at an existing spec.
   - `--qa-answers-from <file>` synthesized from the archived proposal's `## Q&A` section (if present): write one answer per line to a tmp file, in `### Q<N>` order.
   - `--intake-root` from the parent of the proposal's directory (e.g., proposal at `.orchestrator/intake/001-foo/proposal.md` → `--intake-root .orchestrator/intake`).
   - The intake_id (`001-foo`) is preserved by passing the same `--input` (which the id-allocate script counter-allocates from) — but since the directory already exists, the id-allocate script will reuse it; the intake_id is stable across revisions per #Q-6.
10. **Invoke proposal-emit.sh with `--axes-from <tmp>`** plus the re-derived input flags. The emitter writes the new content to the same `<proposal_dir>/proposal.md` path (the existing `mkdir -p` is a no-op since the directory already exists).
11. **Post-process the new proposal**: for each axis present in the axes-from file, replace the placeholder rationale (`Operator revision via revise.sh — see prior version for original rationale.`) with the version-pointer rationale (`operator revision (revise.sh) — see proposal-v<N>.md for prior rationale`). Use the same `sed -i.bak` BSD/GNU-portable idiom. Independent axes (`conversus_gate`, `intensity`) untouched by the revision retain whatever rationale the emitter wrote.
12. **Reset approval state**: the new proposal lands with `pending_approval: true`, `approved_at: null`, `cancelled_at: null` — the operator must re-approve before any downstream command runs. (The emitter already sets these by default; revise.sh does not need to re-mutate.)
13. **Cleanup tmp files**: `rm -f /tmp/axes-from.<pid>.txt` and any qa-answers tmp.
14. **Emit `revised_to=<new-proposal-path>` to stdout**. Exit 0.

### Error handling

- Missing `--proposal` or no `--axis`/`--value` pairs: exit 2 with usage.
- Proposal file does not exist: exit 1 with `ERR: proposal not found at <path>`.
- Axis name not in the FR-12 closed enum: exit 2 with `ERR: unknown axis '<name>' — supported: scope_tier decomposition design_gate conversus_gate intensity` (note: input_shape is rejected separately above).
- axis-rederive.sh non-zero exit: exit 1 with the rederive's stderr forwarded.
- proposal-emit.sh non-zero exit: exit 1 with the emitter's stderr forwarded; restore the archived `proposal-v<N>.md` back to `proposal.md` so the operator's state is not corrupted.

## Steps

1. **Extend `scripts/intake/proposal-emit.sh`** — add the `--axes-from <file>` flag in the argument parser (after the existing `--qa-answers-from` case), add the parsing block (after the existing arg-parse loop), and add the rationale-loop skip branch. Pseudocode delta:

```bash
# In the argument parser (around line 33):
--axes-from)        AXES_FROM="$2"; shift 2 ;;

# After the parse loop (around line 42):
AXES_FROM="${AXES_FROM:-}"

# New parser block (insert after the existing axes resolution but BEFORE the rationale loop, around line 150):
REVISE_AXES_KEYS=""
if [ -n "$AXES_FROM" ]; then
  [ -f "$AXES_FROM" ] || { echo "proposal-emit.sh: axes-from file not found: $AXES_FROM" >&2; exit 1; }
  while IFS= read -r line; do
    case "$line" in '' | '#'*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      scope_tier)            scope_tier_override="$val" ;;
      decomposition)         decomposition_override="$val" ;;
      design_gate)           design_gate_override="$val" ;;
      conversus_gate)        conversus_gate_override="$val" ;;
      intensity)             intensity_override="$val" ;;
      recommended_command)   recommended_command_override="$val" ;;
      *)
        echo "proposal-emit.sh: unknown axes-from key '$key' — supported: scope_tier decomposition design_gate conversus_gate intensity recommended_command" >&2
        exit 2 ;;
    esac
    REVISE_AXES_KEYS="${REVISE_AXES_KEYS}${key}
"
  done < "$AXES_FROM"
  REVISE_AXES_DONE=1
fi

# Apply design_gate / conversus_gate / intensity overrides where the existing block did not
# (the existing block only covers scope_tier, decomposition, recommended_command):
[ -n "${design_gate_override:-}" ]    && design_gate="$design_gate_override"
[ -n "${conversus_gate_override:-}" ] && conversus_gate="$conversus_gate_override"
[ -n "${intensity_override:-}" ]      && intensity="$intensity_override"
```

In the rationale loop (around line 354), add the REVISE_AXES_DONE branch:

```bash
for axis in input_shape scope_tier decomposition design_gate conversus_gate intensity; do
  # ... existing PARA_AXES_DONE / SPEC_AXES_DONE / QA_AXES_DONE branches ...

  # NEW — REVISE_AXES_DONE: skip rationale for axes operator overrode; revise.sh fills them post-emit.
  if [ "${REVISE_AXES_DONE:-0}" = "1" ]; then
    if echo "$REVISE_AXES_KEYS" | grep -qx "$axis"; then
      swap "rationale_${axis}" "Operator revision via revise.sh — see prior version for original rationale."
      swap "evidence_${axis}" "see proposal-v<N>.md (revise.sh post-processes this slot)"
      continue
    fi
  fi

  swap "rationale_${axis}" "$stub_rationale"
  swap "evidence_${axis}" "$stub_evidence"
done
```

2. **Create `scripts/intake/revise.sh`**:

```bash
#!/usr/bin/env bash
# scripts/intake/revise.sh
# M024/P06/T02 — Full re-emit revision flow with version-suffix preservation (FR-12).
#
# Inputs:
#   --proposal <path>             The proposal.md to revise.
#   --axis <name> --value <value> Operator override (repeatable).
#
# Output:
#   revised_to=<new-proposal-path>   to stdout
#   revised=false reason=identical-axes  (idempotent no-op)
#
# Exit 0 on success, 1 on internal error, 2 on usage error.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REDERIVE="$ROOT/scripts/intake/axis-rederive.sh"

usage() {
  cat >&2 <<'EOF'
usage: revise.sh --proposal <path> --axis <name> --value <value> [--axis ... --value ...]

Axes (closed enum): scope_tier  decomposition  design_gate  conversus_gate  intensity
(input_shape is not revisable — re-run orchestrator:evaluate from scratch.)
EOF
  exit 2
}

PROPOSAL=""
# Parallel arrays (bash 3.2 — no associative arrays).
AXES=""
VALUES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    --axis)     AXES="${AXES}${2}
"; shift 2 ;;
    --value)    VALUES="${VALUES}${2}
"; shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$PROPOSAL" ]    || usage
[ -n "$AXES" ]        || usage
[ -n "$VALUES" ]      || usage
[ -f "$PROPOSAL" ]    || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }
[ -x "$EMIT" ]        || { echo "ERR: proposal-emit.sh not executable" >&2; exit 1; }
[ -x "$REDERIVE" ]    || { echo "ERR: axis-rederive.sh not executable" >&2; exit 1; }

# input_shape is not revisable.
case "$AXES" in
  *input_shape*) echo "ERR: input_shape is not revisable; re-run orchestrator:evaluate from scratch" >&2; exit 2 ;;
esac

# Read frontmatter helper.
read_fm() {
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}
read_fm_bare() {
  sed -n "s/^${1}: \\(.*\\)\$/\\1/p" "$PROPOSAL" | head -1
}

# FR-14 idempotency: if every override matches the current value, no-op.
identical=1
ax_idx=0
i=0
echo "$AXES" | while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  val=$(echo "$VALUES" | sed -n "${i}p")
  cur=$(read_fm "$ax")
  if [ "$cur" != "$val" ]; then
    echo "DIFF" >&2
    break
  fi
done > /tmp/revise.diff.$$ 2>&1
# Note: the `while | read` subshell loses the variable; we use a tmp marker file.
if grep -q DIFF /tmp/revise.diff.$$ 2>/dev/null; then
  identical=0
fi
rm -f /tmp/revise.diff.$$
if [ "$identical" = "1" ]; then
  echo "revised=false reason=identical-axes"
  exit 0
fi

# Already-approved advisory.
pa=$(read_fm_bare pending_approval)
ap=$(read_fm approved_at)
if [ "$pa" = "false" ] && [ -n "$ap" ] && [ "$ap" != "null" ]; then
  echo "WARN: revising an already-approved proposal — operator approval will be reset" >&2
fi

# Build the axes-from tmp file: rederives FIRST, operator overrides SECOND so overrides win.
axes_tmp=$(mktemp)
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  val=$(echo "$VALUES" | sed -n "${i}p")
  bash "$REDERIVE" --axis "$ax" --value "$val" --proposal "$PROPOSAL" >> "$axes_tmp" 2>/dev/null || {
    echo "ERR: axis-rederive failed for $ax=$val" >&2
    rm -f "$axes_tmp"
    exit 1
  }
done <<EOF
$AXES
EOF

# Append operator overrides AFTER rederives.
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  val=$(echo "$VALUES" | sed -n "${i}p")
  echo "${ax}=${val}" >> "$axes_tmp"
done <<EOF
$AXES
EOF

# Allocate next version suffix.
proposal_dir=$(dirname "$PROPOSAL")
max_n=0
for f in "$proposal_dir"/proposal-v*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  n=$(echo "$base" | sed -nE 's/^proposal-v([0-9]+)\.md$/\1/p')
  [ -n "$n" ] || continue
  if [ "$n" -gt "$max_n" ]; then
    max_n="$n"
  fi
done
new_n=$((max_n + 1))
archive_path="$proposal_dir/proposal-v${new_n}.md"

# Archive the current proposal.
mv "$PROPOSAL" "$archive_path"

# Re-derive emitter inputs from the archived version.
arc_input=""
arc_spec_path=""
arc_qa_tmp=""

# Original input echo: extract the body line under "## Original Input".
arc_input=$(awk '/^## Original Input/{flag=1;next}/^## /{flag=0}flag && NF' "$archive_path" | head -1)

# Q&A answers re-synthesis (if present).
if grep -q '^## Q&A' "$archive_path"; then
  arc_qa_tmp=$(mktemp)
  awk '/^## Q&A/{flag=1;next}flag && /^### Q[0-9]+/{getline ans; print ans}' "$archive_path" > "$arc_qa_tmp"
fi

# Spec path: feature_slug → specs/<slug>/spec.md if it exists.
slug=$(sed -n 's/^feature_slug: \"\(.*\)\"$/\1/p' "$archive_path" | head -1)
if [ -n "$slug" ] && [ "$slug" != "null" ] && [ -f "$ROOT/specs/$slug/spec.md" ]; then
  arc_spec_path="$ROOT/specs/$slug/spec.md"
fi

# Compute intake-root: parent of the proposal's dir.
intake_root=$(dirname "$proposal_dir")

# Invoke the emitter.
emit_args="--axes-from $axes_tmp --intake-root $intake_root"
if [ -n "$arc_spec_path" ]; then
  emit_args="$emit_args --spec-path $arc_spec_path"
elif [ -n "$arc_qa_tmp" ]; then
  emit_args="$emit_args --qa-answers-from $arc_qa_tmp"
elif [ -n "$arc_input" ]; then
  emit_args="$emit_args --input $arc_input"
fi

if ! emit_out=$(bash "$EMIT" $emit_args); then
  # Restore the archived proposal so the operator's state is not corrupted.
  mv "$archive_path" "$PROPOSAL"
  rm -f "$axes_tmp"
  [ -n "$arc_qa_tmp" ] && rm -f "$arc_qa_tmp"
  echo "ERR: proposal-emit.sh failed; archive restored to $PROPOSAL" >&2
  exit 1
fi

new_proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$new_proposal" ] || {
  mv "$archive_path" "$PROPOSAL"
  rm -f "$axes_tmp"
  [ -n "$arc_qa_tmp" ] && rm -f "$arc_qa_tmp"
  echo "ERR: emitter did not produce a proposal" >&2
  exit 1
}

# Post-process: replace placeholder rationale with version-pointer rationale.
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  ver_rat="operator revision (revise.sh) — see proposal-v${new_n}.md for prior rationale"
  esc=$(printf '%s' "$ver_rat" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/Operator revision via revise.sh — see prior version for original rationale./${esc}/" "$new_proposal"
  ver_ev="proposal-v${new_n}.md"
  esc2=$(printf '%s' "$ver_ev" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/see proposal-v<N>.md (revise.sh post-processes this slot)/${esc2}/" "$new_proposal"
done <<EOF
$AXES
EOF
rm -f "${new_proposal}.bak"

# Cleanup.
rm -f "$axes_tmp"
[ -n "$arc_qa_tmp" ] && rm -f "$arc_qa_tmp"

echo "revised_to=$new_proposal"
exit 0
```

3. **Make scripts executable**: `chmod +x scripts/intake/revise.sh`.

4. **Write the verify script for revise.sh** at `scripts/verify/m024-p06-revise-script.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-revise-script.sh
# Verifies revise.sh archives the prior proposal, re-emits with overrides, and emits revised_to.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Generate a paragraph proposal at Tier B (31-80 word range).
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode and structured output."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^scope_tier: "B"' "$proposal" || { echo "FAIL: pre-state scope_tier not B"; exit 1; }

# Revise scope_tier B → C.
rev_out=$(bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C)
echo "$rev_out" | grep -q '^revised_to=' || { echo "FAIL: revise did not emit revised_to (got: $rev_out)"; exit 1; }

new_path=$(echo "$rev_out" | sed -n 's/^revised_to=//p')
[ -f "$new_path" ] || { echo "FAIL: revise pointed at non-existent file: $new_path"; exit 1; }

# proposal.md should now have scope_tier=C and rederived dependent axes.
grep -q '^scope_tier: "C"' "$new_path" || { echo "FAIL: revised proposal scope_tier not C"; exit 1; }
grep -q '^decomposition: "milestone-with-phases"' "$new_path" || { echo "FAIL: dependent decomposition not rederived"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$new_path" || { echo "FAIL: dependent recommended_command not rederived"; exit 1; }

# Approval state should be reset.
grep -q '^pending_approval: true' "$new_path" || { echo "FAIL: pending_approval not reset to true"; exit 1; }
grep -q '^approved_at: null' "$new_path"      || { echo "FAIL: approved_at not reset to null"; exit 1; }

# proposal-v1.md should exist with the prior content.
v1="$(dirname "$proposal")/proposal-v1.md"
[ -f "$v1" ] || { echo "FAIL: proposal-v1.md not archived"; exit 1; }
grep -q '^scope_tier: "B"' "$v1" || { echo "FAIL: archived v1 lost prior scope_tier"; exit 1; }

# FR-14 idempotency: revising with the same value as current is a no-op.
idem_out=$(bash "$REVISE" --proposal "$new_path" --axis scope_tier --value C)
echo "$idem_out" | grep -q '^revised=false reason=identical-axes' || { echo "FAIL: idempotent revise did not emit identical-axes (got: $idem_out)"; exit 1; }
[ ! -f "$(dirname "$proposal")/proposal-v2.md" ] || { echo "FAIL: idempotent revise produced an unexpected v2 archive"; exit 1; }

echo "PASS: revise.sh — archives v1, re-emits with overrides + rederives, resets approval, idempotent on no-op"
exit 0
```

5. **Write the verify script for the `--axes-from` flag** at `scripts/verify/m024-p06-axes-from-flag.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p06-axes-from-flag.sh
# Verifies proposal-emit.sh accepts --axes-from and applies overrides.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

axes_file="$tmp/axes.txt"
cat > "$axes_file" <<'EOF'
# axes-from override file
scope_tier=C
decomposition=milestone-with-phases
recommended_command=orchestrator:specify
intensity=Full
EOF

emit_out=$(bash "$EMIT" --input "Some short paragraph input." --axes-from "$axes_file" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^scope_tier: "C"' "$proposal" || { echo "FAIL: scope_tier override not applied"; exit 1; }
grep -q '^decomposition: "milestone-with-phases"' "$proposal" || { echo "FAIL: decomposition override not applied"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$proposal" || { echo "FAIL: recommended_command override not applied"; exit 1; }
grep -q '^intensity: "Full"' "$proposal" || { echo "FAIL: intensity override not applied"; exit 1; }

# REVISE_AXES_DONE rationale skip — overridden axes carry the placeholder rationale.
grep -qE '(Operator revision via revise.sh|operator revision \(revise.sh\))' "$proposal" || {
  echo "FAIL: REVISE_AXES_DONE rationale placeholder not present"
  exit 1
}

# Unknown key exits 2.
bad="$tmp/bad.txt"
echo "frobnicate=X" > "$bad"
if bash "$EMIT" --input "x" --axes-from "$bad" --intake-root "$tmp/intake-bad" >/dev/null 2>&1; then
  echo "FAIL: unknown axes-from key should exit non-zero"
  exit 1
fi

echo "PASS: --axes-from flag applies overrides + REVISE_AXES_DONE rationale skip; unknown keys rejected"
exit 0
```

6. **Make verify scripts executable**: `chmod +x scripts/verify/m024-p06-revise-script.sh scripts/verify/m024-p06-axes-from-flag.sh`.

## Must-Haves

- `scripts/intake/revise.sh` exists and is executable.
- `scripts/intake/proposal-emit.sh` accepts a new `--axes-from <file>` flag whose values populate the existing `<axis>_override` shell vars.
- A revision archives the prior `proposal.md` to `proposal-v<N>.md` (next-free-N) and writes the new content to `proposal.md`.
- A revision re-derives dependent axes via axis-rederive.sh and applies operator overrides last so operator overrides win on conflict.
- The new proposal lands with `pending_approval: true`, `approved_at: null`, `cancelled_at: null` — operator must re-approve.
- FR-14 idempotency: revising with the same axis values as current is a no-op (`revised=false reason=identical-axes`, no archive).
- input_shape revisions are rejected (exit 2).
- All writes target only the proposal's intake directory (SB-3 — verified by T04's write-confinement script).
- AD-19 single-script-file shape in every verify script.
- Bash 3.2 portable; no `declare -A`; no process substitution.

## Verification

```
bash scripts/verify/m024-p06-revise-script.sh
bash scripts/verify/m024-p06-axes-from-flag.sh
```

Expected output (each exit 0):
- `PASS: revise.sh — archives v1, re-emits with overrides + rederives, resets approval, idempotent on no-op`
- `PASS: --axes-from flag applies overrides + REVISE_AXES_DONE rationale skip; unknown keys rejected`

## Inputs

### From Previous Tasks

- `scripts/intake/axis-rederive.sh` (from T01) — invoked once per operator override. Key API: `bash axis-rederive.sh --axis <name> --value <value> --proposal <path>` → stdout `key=value` lines for dependent axes; exit 2 on bad input. Independent axes (`conversus_gate`, `intensity`) emit no lines.

### From Disk (Pre-existing)

- `scripts/intake/proposal-emit.sh` (from M024/P01/T04, modified by P02/P03/P04/P05) — extended in this task with `--axes-from`. Existing API: `bash proposal-emit.sh [--input <s>|--spec-path <p>|--qa-answers-from <f>] [--intake-root <d>]` → stdout `proposal_path=<absolute path>`. The emitter writes a 25-key-frontmatter proposal at `<intake-root>/<id>/proposal.md`.
- `templates/intake-proposal.md` — read-only consumer; the emitter renders this template; T02 does not change the template.
- `scripts/intake/intake-id-allocate.sh` — invoked by the emitter; reuses an existing intake_id when the directory exists (so a revision lands at the same `<id>`).
- `scripts/intake/shape-detect.sh` — invoked by the emitter; will re-classify the original input shape on revision (input_shape is unchanged across revisions per the input_shape-not-revisable rule).
- POSIX utilities: `sed`, `awk`, `grep`, `head`, `mktemp`, `mv`, `cp`, `rm`, `dirname`, `basename`, `printf`, `chmod`, `cat`, `echo`.

## Constraints

- POSIX sh + bash 3.2 portable. `sed -i.bak` (with `.bak` suffix then `rm`) — never `sed -i ''`.
- Writes only to (a) `.orchestrator/intake/<id>/` (proposal + version-suffix archive + body mutations) and (b) `/tmp` (axes-from scratch + qa-answers re-synthesis tmp). The axis-rederive.sh script itself writes nothing.
- AD-19 single-script-file shape: every external invocation in verify scripts is top-level; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes (single-pipe `sed | head` is OK as established in P03).
- No conversus invocations, no knowledge writes (NG-2, NG-5).
- No new schema fields (D024 / MEM031 schema authority handshake honored — P06 reads existing P01 frontmatter only).
- Must NOT break P01–P05 verifies. Verify by running `bash scripts/verify/m024-p01-suite.sh` through `bash scripts/verify/m024-p05-suite.sh` after the proposal-emit.sh edit.
- The revise.sh script must restore the archived `proposal-v<N>.md` back to `proposal.md` if the emitter fails — operator state must not be left corrupted.

## Expected Output

`scripts/intake/revise.sh` exists and is executable; `scripts/intake/proposal-emit.sh` accepts `--axes-from <file>`; both verify scripts exit 0 with `PASS:` lines.
