#!/usr/bin/env bash
# scripts/intake/revise.sh
# M024/P06/T02 — Full re-emit revision flow with version-suffix preservation (FR-12).
#
# Inputs:
#   --proposal <path>             The proposal.md to revise.
#   --axis <name> --value <value> Operator override (repeatable).
#
# Output:
#   revised_to=<new-proposal-path>       to stdout (success)
#   revised=false reason=identical-axes  to stdout (FR-14 idempotent no-op)
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
# Parallel arrays kept as newline-delimited strings (bash 3.2 — no associative arrays).
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

[ -n "$PROPOSAL" ] || usage
[ -n "$AXES" ]     || usage
[ -n "$VALUES" ]   || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }
[ -x "$EMIT" ]     || { echo "ERR: proposal-emit.sh not executable" >&2; exit 1; }
[ -x "$REDERIVE" ] || { echo "ERR: axis-rederive.sh not executable" >&2; exit 1; }

# input_shape is not revisable — structural change requires fresh evaluate.
case "$AXES" in
  *input_shape*) echo "ERR: input_shape is not revisable; re-run orchestrator:evaluate from scratch" >&2; exit 2 ;;
esac

# Validate every axis name against the FR-12 closed enum.
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  case "$ax" in
    scope_tier|decomposition|design_gate|conversus_gate|intensity) ;;
    *) echo "ERR: unknown axis '$ax' — supported: scope_tier decomposition design_gate conversus_gate intensity" >&2; exit 2 ;;
  esac
done <<EOF
$AXES
EOF

# Read frontmatter helpers (single-pipeline shape — sed | head allowed per AD-19).
read_fm() {
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}
read_fm_bare() {
  sed -n "s/^${1}: \\(.*\\)\$/\\1/p" "$PROPOSAL" | head -1
}

# FR-14 idempotency: if every override matches the current frontmatter value,
# emit a no-op signal and exit 0 without archiving or re-emitting.
diff_marker=$(mktemp)
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  val=$(echo "$VALUES" | sed -n "${i}p")
  cur=$(read_fm "$ax")
  if [ -z "$cur" ]; then
    cur=$(read_fm_bare "$ax")
  fi
  if [ "$cur" != "$val" ]; then
    echo "DIFF" >> "$diff_marker"
  fi
done <<EOF
$AXES
EOF

if ! grep -q DIFF "$diff_marker" 2>/dev/null; then
  rm -f "$diff_marker"
  echo "revised=false reason=identical-axes"
  exit 0
fi
rm -f "$diff_marker"

# Already-approved advisory — proceed but warn (operator approval will be reset).
pa=$(read_fm_bare pending_approval)
ap=$(read_fm approved_at)
if [ "$pa" = "false" ] && [ -n "$ap" ] && [ "$ap" != "null" ]; then
  echo "WARN: revising an already-approved proposal — operator approval will be reset" >&2
fi

# Build the axes-from tmp file: rederives FIRST, operator overrides SECOND so
# operator overrides win on conflict (proposal-emit reads the file top-to-bottom
# and last-write-wins for the override shell vars).
axes_tmp=$(mktemp)
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  val=$(echo "$VALUES" | sed -n "${i}p")
  rd_out=$(bash "$REDERIVE" --axis "$ax" --value "$val" --proposal "$PROPOSAL" 2>/dev/null) || {
    echo "ERR: axis-rederive failed for $ax=$val" >&2
    rm -f "$axes_tmp"
    exit 1
  }
  if [ -n "$rd_out" ]; then
    echo "$rd_out" >> "$axes_tmp"
  fi
done <<EOF
$AXES
EOF

# Append operator overrides AFTER rederives (last-wins precedence).
i=0
while IFS= read -r ax; do
  i=$((i+1))
  [ -n "$ax" ] || continue
  val=$(echo "$VALUES" | sed -n "${i}p")
  echo "${ax}=${val}" >> "$axes_tmp"
done <<EOF
$AXES
EOF

# Allocate next version suffix — scan proposal-v*.md, find highest existing N, use N+1.
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

# Re-derive emitter inputs from the CURRENT proposal BEFORE archiving so we can
# read its body sections.
arc_input=""
arc_spec_path=""
arc_qa_tmp=""

# Original input echo: extract the first non-empty line under "## Original Input".
arc_input=$(awk '/^## Original Input/{flag=1;next}/^## /{flag=0}flag && NF' "$PROPOSAL" | head -1)

# Q&A answers re-synthesis (if the proposal carried a Q&A transcript).
if grep -q '^## Q&A' "$PROPOSAL"; then
  arc_qa_tmp=$(mktemp)
  awk '/^## Q&A/{flag=1;next}flag && /^### Q[0-9]+/{getline ans; print ans}' "$PROPOSAL" > "$arc_qa_tmp"
fi

# Spec path: feature_slug → specs/<slug>/spec.md if it exists.
slug=$(sed -n 's/^feature_slug: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
if [ -n "$slug" ] && [ "$slug" != "null" ] && [ -f "$ROOT/specs/$slug/spec.md" ]; then
  arc_spec_path="$ROOT/specs/$slug/spec.md"
fi

# Compute intake-root: parent of the proposal's directory.
intake_root=$(dirname "$proposal_dir")

# Archive the current proposal (must happen BEFORE re-emit so the emitter can
# overwrite proposal.md cleanly).
mv "$PROPOSAL" "$archive_path"

# Invoke the emitter with the axes-from override file plus re-derived inputs.
# Use an array so values with spaces survive (paragraph input is a sentence).
emit_args="--axes-from \"$axes_tmp\" --intake-root \"$intake_root\""
if [ -n "$arc_spec_path" ]; then
  emit_out=$(bash "$EMIT" --axes-from "$axes_tmp" --intake-root "$intake_root" --spec-path "$arc_spec_path" 2>&1) || emit_failed=1
elif [ -n "$arc_qa_tmp" ]; then
  emit_out=$(bash "$EMIT" --axes-from "$axes_tmp" --intake-root "$intake_root" --qa-answers-from "$arc_qa_tmp" 2>&1) || emit_failed=1
elif [ -n "$arc_input" ]; then
  emit_out=$(bash "$EMIT" --axes-from "$axes_tmp" --intake-root "$intake_root" --input "$arc_input" 2>&1) || emit_failed=1
else
  emit_out=$(bash "$EMIT" --axes-from "$axes_tmp" --intake-root "$intake_root" 2>&1) || emit_failed=1
fi

if [ "${emit_failed:-0}" = "1" ]; then
  # Restore the archived proposal so the operator's state is not corrupted.
  mv "$archive_path" "$PROPOSAL"
  rm -f "$axes_tmp"
  [ -n "$arc_qa_tmp" ] && rm -f "$arc_qa_tmp"
  echo "ERR: proposal-emit.sh failed; archive restored to $PROPOSAL" >&2
  echo "$emit_out" >&2
  exit 1
fi

new_proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p' | head -1)
if [ -z "$new_proposal" ] || [ ! -f "$new_proposal" ]; then
  mv "$archive_path" "$PROPOSAL"
  rm -f "$axes_tmp"
  [ -n "$arc_qa_tmp" ] && rm -f "$arc_qa_tmp"
  echo "ERR: emitter did not produce a proposal" >&2
  echo "$emit_out" >&2
  exit 1
fi

# Stable-id preservation (#Q-6): the id-allocate script counter-allocates a
# fresh <NNN>-slug whenever the original directory is non-empty, so the emitter
# may have landed the new proposal at a sibling directory. Move it back to the
# original proposal path so the intake_id is stable across revisions, then prune
# the empty sibling directory created by the emitter.
if [ "$new_proposal" != "$PROPOSAL" ]; then
  new_dir=$(dirname "$new_proposal")
  mv "$new_proposal" "$PROPOSAL"
  # Best-effort cleanup of the now-empty sibling dir.
  rmdir "$new_dir" 2>/dev/null || true
  new_proposal="$PROPOSAL"
fi

# Post-process the new proposal: replace placeholder rationale strings with
# version-pointer rationales (FR-13 evidence honesty: cite the prior version).
ver_rat="operator revision (revise.sh) — see proposal-v${new_n}.md for prior rationale"
esc_rat=$(printf '%s' "$ver_rat" | sed 's/[\/&]/\\&/g')
ver_ev="proposal-v${new_n}.md"
esc_ev=$(printf '%s' "$ver_ev" | sed 's/[\/&]/\\&/g')

sed -i.bak "s/Operator revision via revise.sh — see prior version for original rationale./${esc_rat}/g" "$new_proposal"
sed -i.bak "s/see proposal-v<N>.md (revise.sh post-processes this slot)/${esc_ev}/g" "$new_proposal"
rm -f "${new_proposal}.bak"

# Cleanup tmp scratch.
rm -f "$axes_tmp"
[ -n "$arc_qa_tmp" ] && rm -f "$arc_qa_tmp"

echo "revised_to=$new_proposal"
exit 0
