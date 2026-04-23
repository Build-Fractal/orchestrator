#!/usr/bin/env bash
# tests/test-specify-number-allocator.sh — regression for the octal-NEXT bug.
#
# Bash treats zero-padded numerics as octal in $((...)) context. Before the
# fix at specify.sh:336, pre-existing `024-*` produced NEXT=021 (024 as octal
# is decimal 20, +1 = 21 → formatted as `021`); `008-*`/`009-*` errored with
# "value too great for base". Both paths are covered below.
#
# Bash 3.2 compatible. Hermetic scratch; never mutates the live repo.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SPECIFY_SRC="${PROJECT_ROOT}/scripts/specify/specify.sh"
PROBE_SRC="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
DUAL_WRITE_SRC="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"
TEMPLATE_SRC="${PROJECT_ROOT}/templates/spec-template.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

for f in "$SPECIFY_SRC" "$PROBE_SRC" "$DUAL_WRITE_SRC" "$TEMPLATE_SRC"; do
  [ -e "$f" ] || fail "missing upstream artifact: $f"
done

# Helper: scaffold a scratch repo pre-seeded with one spec at the given NNN.
# Returns the absolute scratch path on stdout.
make_scratch() {
  seed_nnn="$1"
  s="$(mktemp -d)"
  mkdir -p "${s}/.orchestrator" "${s}/templates" "${s}/specs/${seed_nnn}-seed" \
           "${s}/scripts/specify" "${s}/scripts/knowledge" "${s}/scripts/util"
  cp "$SPECIFY_SRC"    "${s}/scripts/specify/specify.sh"
  cp "$PROBE_SRC"      "${s}/scripts/knowledge/spec-complexity-probe.sh"
  cp "$DUAL_WRITE_SRC" "${s}/scripts/util/dual-write-runtime-md.sh"
  cp "$TEMPLATE_SRC"   "${s}/templates/spec-template.md"
  printf -- '---\nschema_version: "1.0"\n---\n# seed\n' > "${s}/specs/${seed_nnn}-seed/spec.md"
  touch "${s}/CLAUDE.md"
  cat > "${s}/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: false
EOF
  printf '%s' "$s"
}

# Helper: invoke specify --dry-run and return the scaffold-spec target path's
# numeric prefix (e.g. "025").
get_next_nnn() {
  scratch="$1"
  out="$(cd "$scratch" && bash "${scratch}/scripts/specify/specify.sh" \
    --dry-run --yes --slug reg-probe --description "regression probe" 2>/dev/null)" \
    || fail "specify --dry-run failed rc=$?"
  target="$(printf '%s\n' "$out" | grep '"action_type":"scaffold-spec"' | head -1)"
  [ -n "$target" ] || fail "no scaffold-spec manifest record in dry-run output"
  path="$(printf '%s' "$target" | sed -n 's/.*"target_path":"\([^"]*\)".*/\1/p')"
  base="$(basename "$(dirname "$path")")"
  printf '%s' "${base%%-*}"
}

# Case 1: seed=024 → expect next=025 (not 021).
S1="$(make_scratch 024)"
trap 'rm -rf "$S1" "${S2:-}" "${S3:-}"' EXIT
NXT="$(get_next_nnn "$S1")"
[ "$NXT" = "025" ] || fail "seed=024 expected next=025, got $NXT (octal bug regression)"

# Case 2: seed=008 → expect next=009 (not error).
S2="$(make_scratch 008)"
NXT="$(get_next_nnn "$S2")"
[ "$NXT" = "009" ] || fail "seed=008 expected next=009, got $NXT (octal invalid-digit regression)"

# Case 3: seed=009 → expect next=010 (this is the octal-error boundary).
S3="$(make_scratch 009)"
NXT="$(get_next_nnn "$S3")"
[ "$NXT" = "010" ] || fail "seed=009 expected next=010, got $NXT (octal invalid-digit regression)"

echo "PASS: specify number-allocator handles 008/009/024 boundary correctly"
