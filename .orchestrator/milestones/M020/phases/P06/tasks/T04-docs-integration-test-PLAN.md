---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M020"
name: "Documentation + integration test (references/preferences.md + tests/test-preferences-resolution.sh)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped: `scripts/knowledge/lib/preferences.sh` is sourceable and exposes `pref_resolve <key>` with the documented precedence + malformed-fallback semantics.
- T02 has shipped: `scripts/knowledge/query.sh` is wired to consume `default_state_filter` from preferences when no `--state` flag.
- T03 has shipped: `scripts/knowledge/consolidate-artifacts.sh --cluster` is wired to consume `similarity_threshold` from preferences when no positional threshold AND emits `effective_threshold=<N>` on stdout BEFORE the per-cluster output blocks.
- M020-CONTEXT.md DC-8 THREAT-007 disposition: per-key partial-overlap behavior — each key resolves independently — is documented in this phase per the conversus disposition note ("Documentation task lands in M020 plan-phase").
- spec 025 SC-5: `effective_threshold=0.6` propagates through `consolidate-artifacts.sh --cluster` when project=0.6 + user=0.8.
- spec 025 US-5 acceptance scenarios + Edge Cases ("Preferences file declares a threshold outside the valid range").
- AD-19: every verifier's external invocation is a single `bash <script>` call.
- Plan-deviation invariant (P04): every verifier this task references in its Verification section is authored by this task or by an upstream phase.

## Description

Two deliverables:

1. **`references/preferences.md`** — an operator-facing reference for the M020 preferences layer. Modelled after the structure of existing `references/*.md` files (matter-of-fact prose, named sections, code blocks with literal commands). Documents:

   - The five preference keys + their built-in defaults + their type/range constraints (the table from T01's reference plan, repeated here for the operator-side).
   - The two file paths (`~/.orchestrator/preferences.yml` user, `.orchestrator/preferences.yml` project) and the precedence rule (project>user>default).
   - The per-key partial-overlap behavior (THREAT-007 disposition): each key resolves INDEPENDENTLY — declaring `similarity_threshold` at project and `staleness_threshold` at user means project wins for the first and user wins for the second; this is NOT a conflict. A worked example demonstrates partial overlap.
   - The malformed-value fallback semantics — what counts as "malformed" per-key (non-numeric for numeric keys, out-of-range for bounded keys, value outside the closed enum for `default_state_filter`), the stderr diagnostic shape, and the explicit guarantee that the operator's preferences file is NEVER rewritten.
   - The closed-enum key vocabulary (and the rule that adding a key requires an M020 D-row + schema-evolution note, paralleling the FR-9 schema-authority pattern for entry frontmatter).
   - Three operator-runbook scenarios:
     a. Single-operator project (no user file; project file overrides defaults for one or two keys).
     b. Multi-operator project (user file declares per-operator preferences; project file declares team-wide overrides; project wins on collision).
     c. Project with no preferences file at all (built-in defaults take effect; behavior is identical to pre-M020 behavior modulo new `effective_threshold=` line in consolidate output).

2. **`tests/test-preferences-resolution.sh`** — an end-to-end integration test that exercises SC-5 and the per-key precedence + malformed-fallback semantics through the production scripts (`query.sh` + `consolidate-artifacts.sh --cluster`), not just through `preferences.sh` in isolation. Three scenarios:

   a. **SC-5 directly**: project=0.6, user=0.8, no positional threshold, `consolidate-artifacts.sh --cluster` emits `effective_threshold=0.6` on stdout. JSONL `threshold_used=0.6`. Both preferences files md5 unchanged after invocation.
   b. **State-filter precedence through `query.sh`**: project=`candidate`, user=`graduated`, no `--state` flag, `query.sh --topic X --format ids` returns the candidate entry's ID only.
   c. **Malformed-value fallback through `consolidate-artifacts.sh --cluster`**: project file `similarity_threshold: not-a-number`, user file absent. Invocation emits `effective_threshold=0.7` on stdout AND a stderr line matching `WARN: pref_resolve: malformed value for 'similarity_threshold'`. Project preferences file is byte-identical (md5) before and after the invocation (operator's file untouched per spec edge case).

## Steps

### Step 1: Create `references/preferences.md`

Path: `/Users/brettkellgren/Sites/orchestrator/references/preferences.md`

Reference content outline (use the EXACT key list, defaults, and stderr diagnostic shape from T01 — copy verbatim to keep the doc and the helper in sync):

```markdown
# Preferences Layer (M020 / FR-6 / US-5)

The orchestrator's preferences layer lets an operator tune knowledge
resolution behavior — default state filter, similarity threshold,
staleness threshold, preferred cluster size, operator identifier — at
both the user level and the project level. Project preferences win
over user preferences on a per-key basis; built-in defaults apply when
neither file declares a key.

## Files

- `~/.orchestrator/preferences.yml` — user-level preferences. Applied
  to every project the operator works on.
- `.orchestrator/preferences.yml` — project-level preferences. Applied
  to one project; checked into version control as the team's shared
  defaults.

Both files are scalar-only YAML. Nested structures are not supported in
M020 (AD-5). If the schema later requires nesting, an M020 D-row will
authorize the parser swap.

## Keys

| Key                    | Type   | Range / Enum                           | Default        |
|------------------------|--------|----------------------------------------|----------------|
| `default_state_filter` | string | `candidate`, `graduated`, `archived`   | `graduated`    |
| `similarity_threshold` | float  | 0.0–1.0                                | 0.7            |
| `staleness_threshold`  | int    | 1–365 (days)                           | 14             |
| `preferred_cluster_size` | int  | 1–50                                   | 8              |
| `operator_identifier`  | string | non-empty                              | `unknown@local`|

The vocabulary is closed: any key not in this table is rejected by
`pref_resolve` (returns non-zero with `FAIL: pref_resolve: unknown key`
on stderr). Adding a key requires an M020 D-row + a schema-evolution
note (parallels the FR-9 schema-authority pattern for entry frontmatter).

## Precedence

For every key, the resolution order is:

1. **CLI flag** (when the consumer script accepts one — e.g. `query.sh
   --state` or `consolidate-artifacts.sh --cluster <orch> <milestone>
   [<knowledge-root>] [<threshold>]`).
2. **Project preferences file** (`.orchestrator/preferences.yml`).
3. **User preferences file** (`~/.orchestrator/preferences.yml`).
4. **Built-in default** (table above).

Each key resolves INDEPENDENTLY (THREAT-007 disposition). If the
project file declares only `similarity_threshold` and the user file
declares only `staleness_threshold`, the project file's value wins for
the first key and the user file's value wins for the second; this is
NOT a conflict.

## Malformed values

When a preferences file declares a key with a malformed value (non-
numeric for numeric keys, out-of-range for bounded keys, value outside
the closed enum for `default_state_filter`), `pref_resolve`:

- Skips the malformed source.
- Emits a single-line stderr diagnostic: `WARN: pref_resolve: malformed
  value for '<key>' in '<file>': '<raw-value>' — falling back to <next>`.
- Continues to the next source per the precedence chain.
- NEVER rewrites the preferences file (operator-owned).

Example: a project file with `similarity_threshold: not-a-number` and
no user file falls back to the built-in default `0.7`, with the WARN
line on stderr.

## Operator runbooks

### Single-operator project

Create only `.orchestrator/preferences.yml` with the keys you want to
override. Example:

```yaml
similarity_threshold: 0.6
preferred_cluster_size: 12
```

Other keys (state filter, staleness threshold, operator identifier)
fall back to built-in defaults.

### Multi-operator project (team-wide overrides + per-operator opt-in)

Check in `.orchestrator/preferences.yml` with the team-wide settings.
Each operator may add `~/.orchestrator/preferences.yml` for keys
NOT declared in the project file. Where both files declare the same
key, the project (team-wide) value wins.

### No preferences file

Built-in defaults take effect. `consolidate-artifacts.sh --cluster`
emits `effective_threshold=0.7` on stdout (the new audit line is
emitted on every invocation regardless of whether a preferences file
exists; pre-M020 behavior is otherwise unchanged).

## Implementation

The helper at `scripts/knowledge/lib/preferences.sh` exposes
`pref_resolve <key>`. Consumer scripts: `scripts/knowledge/query.sh`
(default state filter) and `scripts/knowledge/consolidate-artifacts.sh
--cluster` (similarity threshold). The helper is read-only — it
never writes to either file.
```

The verifier in Step 3 below asserts the doc names the five keys, the precedence rule, the malformed example, and the closed-enum vocabulary.

### Step 2: Create `tests/test-preferences-resolution.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/tests/test-preferences-resolution.sh`

Three scenarios. Use the MEM002 `pass()`/`fail()` parallel-scalar pattern, tempdir + trap cleanup, and HOME / PROJECT_ROOT / ORCH_ROOT env-override fixture isolation per the P03/P05 conventions (no live filesystem access).

```bash
#!/usr/bin/env bash
# tests/test-preferences-resolution.sh — SC-5 + per-key precedence +
# malformed-fallback integration test through query.sh and
# consolidate-artifacts.sh --cluster.
#
# Bash 3.2 + MEM002 conventions. Tempdir + HOME / PROJECT_ROOT / ORCH_ROOT
# fixture isolation per P03/P05.

set -u

# pass/fail parallel-scalar pattern (no declare -A).
pc=0; fc=0
pass() { pc=$((pc+1)); echo "PASS: $*"; }
fail() { fc=$((fc+1)); echo "FAIL: $*" >&2; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export PROJECT_ROOT="$TMP/project"
export ORCH_ROOT="$TMP/project/.orchestrator"
KNOWLEDGE_ROOT="$TMP/project/knowledge"

mkdir -p "$HOME/.orchestrator" "$PROJECT_ROOT/.orchestrator" "$KNOWLEDGE_ROOT" "$ORCH_ROOT"

# Helper: write a candidate entry. Args: <id> <topic> <tag1>
write_candidate() {
  local id="$1" topic="$2" tag="$3"
  local file="$KNOWLEDGE_ROOT/${id}.md"
  cat >"$file" <<EOF
---
schema_version: "1.0"
id: ${id}
status: candidate
topic: ${topic}
tags: [${tag}]
title: "${id} title"
last_verified: "2026-04-25"
---
${id} body words go here for clustering. ${tag} ${topic} ${id} alpha beta gamma.
EOF
}
write_graduated() {
  local id="$1" topic="$2"
  local file="$KNOWLEDGE_ROOT/${id}.md"
  cat >"$file" <<EOF
---
schema_version: "1.0"
id: ${id}
status: graduated
topic: ${topic}
tags: [${topic}]
title: "${id} title"
last_verified: "2026-04-25"
---
${id} body for ${topic}.
EOF
}

# Scenario A — SC-5 direct: project=0.6, user=0.8 -> effective_threshold=0.6.
write_candidate MEM501 alpha alpha
write_candidate MEM502 beta beta
write_candidate MEM503 gamma gamma

cat >"$PROJECT_ROOT/.orchestrator/preferences.yml" <<EOF
similarity_threshold: 0.6
EOF
cat >"$HOME/.orchestrator/preferences.yml" <<EOF
similarity_threshold: 0.8
EOF

stdout_a="$TMP/stdout-a.txt"
bash "$REPO_ROOT/scripts/knowledge/consolidate-artifacts.sh" --cluster \
  "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" >"$stdout_a" 2>/dev/null

if grep -q '^effective_threshold=0\.6$' "$stdout_a"; then
  pass "scenario A: project=0.6 wins over user=0.8 -> effective_threshold=0.6"
else
  fail "scenario A: stdout missing effective_threshold=0.6 (got: $(head -3 "$stdout_a" | tr '\n' '|'))"
fi

# JSONL check.
if grep -q '"threshold_used":"0\.6"' "$ORCH_ROOT/execution-log.jsonl" 2>/dev/null \
   || grep -q 'threshold_used=0\.6' "$ORCH_ROOT/execution-log.jsonl" 2>/dev/null; then
  pass "scenario A: JSONL threshold_used=0.6"
else
  fail "scenario A: JSONL missing threshold_used=0.6"
fi

# Both preference files unchanged.
proj_md5_a="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
# (verifier defines md5_or_sha portably; pseudo-code here)

# Scenario B — state-filter precedence via query.sh.
rm -f "$ORCH_ROOT/execution-log.jsonl"
write_graduated MEM510 zeta
write_candidate MEM511 zeta zeta

cat >"$PROJECT_ROOT/.orchestrator/preferences.yml" <<EOF
default_state_filter: candidate
EOF
cat >"$HOME/.orchestrator/preferences.yml" <<EOF
default_state_filter: graduated
EOF

stdout_b="$TMP/stdout-b.txt"
bash "$REPO_ROOT/scripts/knowledge/query.sh" --topic zeta >"$stdout_b" 2>/dev/null

if grep -q '^entry_id=MEM511$' "$stdout_b" && ! grep -q '^entry_id=MEM510$' "$stdout_b"; then
  pass "scenario B: project=candidate wins over user=graduated -> MEM511 returned, MEM510 not"
else
  fail "scenario B: query.sh stdout did not honor project default_state_filter=candidate"
fi

# Scenario C — malformed value via consolidate-artifacts.sh --cluster.
rm -f "$HOME/.orchestrator/preferences.yml"
cat >"$PROJECT_ROOT/.orchestrator/preferences.yml" <<EOF
similarity_threshold: not-a-number
EOF
proj_pre_md5="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"

stdout_c="$TMP/stdout-c.txt"
stderr_c="$TMP/stderr-c.txt"
bash "$REPO_ROOT/scripts/knowledge/consolidate-artifacts.sh" --cluster \
  "$ORCH_ROOT" MTEST "$KNOWLEDGE_ROOT" >"$stdout_c" 2>"$stderr_c"

if grep -q '^effective_threshold=0\.7$' "$stdout_c"; then
  pass "scenario C: malformed project value -> effective_threshold=0.7 (built-in default)"
else
  fail "scenario C: stdout missing effective_threshold=0.7"
fi

if grep -q "WARN: pref_resolve: malformed value for 'similarity_threshold'" "$stderr_c"; then
  pass "scenario C: stderr WARN diagnostic emitted"
else
  fail "scenario C: stderr missing WARN diagnostic"
fi

proj_post_md5="$(md5_or_sha "$PROJECT_ROOT/.orchestrator/preferences.yml")"
if [ "$proj_pre_md5" = "$proj_post_md5" ]; then
  pass "scenario C: project preferences file md5 unchanged (operator file untouched)"
else
  fail "scenario C: project preferences file mutated by consolidate run"
fi

echo "RESULT: ${pc}/$((pc+fc)) PASS"
[ "$fc" -eq 0 ] || exit 1
exit 0
```

NOTE: the test author should provide a portable `md5_or_sha` helper (try `md5 -q`, fall back to `md5sum | awk`, fall back to `shasum -a 1 | awk`). The pattern is established in P02/P05 verifier scripts; reuse verbatim.

### Step 3: Create `scripts/verify/m020-p06-preferences-doc-content.sh`

Verifier asserts `references/preferences.md` documents the load-bearing facts:

- File exists at `references/preferences.md`.
- File mentions ALL FIVE keys verbatim: `default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`.
- File mentions the precedence words in order (project ... user ... default) — single grep for the phrase or three sequential greps.
- File mentions the THREAT-007 disposition phrase ("each key resolves" or "independently" — pick one literal token to grep for).
- File contains a worked malformed example (grep for `not-a-number` AND `WARN: pref_resolve`).
- File mentions the closed-enum vocabulary phrase (grep for `closed`).
- File mentions both file paths verbatim: `~/.orchestrator/preferences.yml` AND `.orchestrator/preferences.yml`.

Use `pass()`/`fail()` parallel-scalar pattern. No tempdir needed — this verifier reads the static doc.

## Must-Haves

This task addresses the following P06 must-haves:

- Truth: `references/preferences.md` documents the five keys + precedence + partial-overlap + malformed semantics + closed-enum vocabulary (Check: `m020-p06-preferences-doc-content.sh`).
- Truth: `tests/test-preferences-resolution.sh` exists, is executable, and exits 0 covering SC-5 + state-filter precedence + malformed fallback (Check: `bash tests/test-preferences-resolution.sh`).
- Artifact: `references/preferences.md` (min 80 lines, contains `similarity_threshold`).
- Artifact: `tests/test-preferences-resolution.sh` (min 150 lines, contains `effective_threshold=`).
- Artifact: `scripts/verify/m020-p06-preferences-doc-content.sh`.
- Key Link: `tests/test-preferences-resolution.sh → scripts/knowledge/lib/preferences.sh` (test sources or invokes the helper).
- Key Link: `references/preferences.md → scripts/knowledge/lib/preferences.sh` (doc names the file path verbatim).

## Verification

```bash
bash scripts/verify/m020-p06-preferences-doc-content.sh
bash tests/test-preferences-resolution.sh
```

Both exit 0. AD-19 compliant: each is a single `bash <script>` invocation. Per the P04 plan-deviation invariant: this task's Verification section names ONLY verifiers authored by this task. Cross-task / phase-rollup verification (`bash scripts/verify/check-must-haves.sh ...`) lives in the phase plan's Verification Commands block, not in this task's section.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/preferences.sh` (from T01)
  - Key API: `pref_resolve <key>` echoes effective scalar value, project>user>built-in-default precedence, malformed → stderr WARN + fallback.
- `scripts/knowledge/query.sh` (from T02 — already wired)
  - Key API: `query.sh --topic <X> [--state <S>] [--format ids|json]`. When `--state` absent, resolves via `pref_resolve default_state_filter`.
- `scripts/knowledge/consolidate-artifacts.sh` (from T03 — already wired)
  - Key API: `consolidate-artifacts.sh --cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]`. When threshold positional absent, resolves via `pref_resolve similarity_threshold`. Emits `effective_threshold=<N>` on stdout BEFORE per-cluster blocks.

### From Disk (Pre-existing)

- `references/installation.md`, `references/state-machine.md` and other `references/*.md` — referenced for the prose / sectioning convention. Do not modify; only mirror their style.
- P03/P05 verifier scripts under `scripts/verify/` — referenced for the `md5_or_sha` portability helper pattern and the tempdir+trap fixture-isolation idiom.

## Constraints

- **AD-19 (single-script-invocation shape)**: each verifier and the integration test is invoked externally as `bash <script>`.
- **MEM002 (test conventions)**: integration test uses tempdir + trap cleanup; HOME / PROJECT_ROOT / ORCH_ROOT all set to fresh tempdirs (no live filesystem access).
- **MEM001 (Bash 3.2)**: no `declare -A` in any new code.
- **CON-1 / FR-8 (read-only)**: the integration test asserts the project preferences file md5 is unchanged after every invocation that reads from it. The doc-content verifier reads the static doc only.
- **CON-4 (surgical precision)**: this task creates new files only; no in-place edits to other M020 files except the documentation file (which is a new artifact). No drive-by edits to `query.sh`, `consolidate-artifacts.sh`, or `preferences.sh`.
- **Plan-deviation invariant (P04)**: this task's Verification section names ONLY verifiers authored by this task.

## Expected Output

```
$ bash scripts/verify/m020-p06-preferences-doc-content.sh
PASS: references/preferences.md exists
PASS: doc names default_state_filter
PASS: doc names similarity_threshold
PASS: doc names staleness_threshold
PASS: doc names preferred_cluster_size
PASS: doc names operator_identifier
PASS: doc names project>user>default precedence
PASS: doc mentions per-key independent resolution
PASS: doc contains worked malformed example
PASS: doc mentions closed enum vocabulary
PASS: doc names both file paths
RESULT: 11/11 PASS
exit 0

$ bash tests/test-preferences-resolution.sh
PASS: scenario A: project=0.6 wins over user=0.8 -> effective_threshold=0.6
PASS: scenario A: JSONL threshold_used=0.6
PASS: scenario A: project preferences file md5 unchanged
PASS: scenario A: user preferences file md5 unchanged
PASS: scenario B: project=candidate wins over user=graduated -> MEM511 returned, MEM510 not
PASS: scenario C: malformed project value -> effective_threshold=0.7 (built-in default)
PASS: scenario C: stderr WARN diagnostic emitted
PASS: scenario C: project preferences file md5 unchanged (operator file untouched)
RESULT: 8/8 PASS
exit 0
```
