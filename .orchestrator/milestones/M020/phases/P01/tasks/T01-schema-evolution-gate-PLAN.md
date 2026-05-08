---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M020"
name: "Schema-evolution gate — D024 + MEM031"
depends_on: []
---

## Prerequisites

None. This task is the foundational schema-authority gate that lands BEFORE
any code touches the `knowledge/**/MEM*.md` frontmatter schema. Its outputs
(D024 + MEM031) are the contract that T02/T03/T04/T05 honor.

Pre-existing state required:
- `.orchestrator/DECISIONS.md` exists with D-rows up through D023.
- `knowledge/conventions/` directory exists and currently contains MEM030 as
  the highest-numbered convention entry (next available = MEM031).
- `KNOWLEDGE-INDEX.md` exists at the repo root and registers each MEM entry
  as one row in its conventions table.

## Description

M020 holds exclusive schema authority over `knowledge/spec/**` and
`knowledge/**/MEM*.md` frontmatter (FR-9). The `status:` field addition that
the rest of P01 depends on is a schema evolution and MUST land via:

1. A **D-row** in `.orchestrator/DECISIONS.md` recording the schema-authority
   decision, the closed-enum vocabulary, and the boundary-of-extension rules
   for consuming milestones (M024, M019 Tier 2+3).
2. A **schema-evolution note** at `knowledge/conventions/MEM031.md`
   documenting the field's vocabulary, default semantics for pre-M020
   entries, and the migration approach.
3. A **KNOWLEDGE-INDEX.md** row registering MEM031 under the conventions
   table.

This task does NOT touch any executable code or any `knowledge/**/MEM*.md`
file other than creating MEM031. Code-level enforcement (graduate.sh,
frontmatter helper, validation report) lands in T02–T05.

## Steps

### Step 1: Append D024 to `.orchestrator/DECISIONS.md`

Open `/Users/brettkellgren/Sites/orchestrator/.orchestrator/DECISIONS.md`
and append a new D-row at the end of the table. Use the same column shape
the file already uses (Decision ID | Source | Tags | Decision | Rationale |
Reversible). Sample row content:

```
| D024 | M020/P01 (2026-04-25) | scope, contract, knowledge, schema-authority | M020 schema-evolution: introduce `status:` frontmatter field (closed enum `{candidate, graduated, archived}`), `decision_history:` (append-only list of `{rationale, timestamp, operator, cluster_id}` records), and `archived_into:` (single canonical entry-ID back-reference) on every `knowledge/**/MEM*.md` and `knowledge/spec/**` entry. M020 holds exclusive schema authority over these surfaces per FR-9. Pre-M020 entries without `status:` are treated as `graduated` on first read; the field is written on next touch (FR-10 incremental migration). Vocabulary documented in `knowledge/conventions/MEM031.md`. Consuming milestones (M024 universal intake, M019 Tier 2+3 observability) MAY READ these fields but MUST NOT introduce new fields without a follow-up M020 D-row. | Anchors the schema evolution in the audit trail BEFORE code lands. The closed enum prevents downstream surfaces from inventing alternate state names (e.g., `pending`, `superseded`) that would fragment the query surface (FR-2). Append-only `decision_history:` keeps a non-destructive review log; compaction is deferred (NG-6). Incremental on-touch migration honors NG-3 (no retroactive bulk migration). | Yes — (a) if a fourth state proves necessary (e.g., `deprecated` distinct from `archived`), open a follow-up D-row that extends the closed enum and updates MEM031. (b) If `decision_history:` length becomes unwieldy (>50 records on a single entry), compact via a follow-up D-row that defines compaction rules (NG-6 currently defers this). (c) If consuming milestones discover a needed field, the handshake is: open an M020 D-row → M020 lands the schema change → consuming milestone uses the field. Never bypass this gate. |
```

The exact prose may be adjusted for clarity but MUST retain the four
load-bearing elements: (a) the literal token `D024`, (b) the literal token
`status:`, (c) the closed-enum values `candidate`, `graduated`, `archived`,
and (d) the citation of MEM031 as the vocabulary note.

### Step 2: Create `knowledge/conventions/MEM031.md`

Write the file at
`/Users/brettkellgren/Sites/orchestrator/knowledge/conventions/MEM031.md`
with the following content (verbatim frontmatter; body may be elaborated for
clarity but must preserve the load-bearing tokens):

```markdown
---
id: MEM031
scope_tags: "[project], [milestone:M020]"
category: conventions
confidence: 0.90
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "M020/P01"
source_type: schema-evolution
supersedes: ""
superseded_by: ""
relates_to: [MEM013, MEM014]
content_hash: ""
---

# MEM031: Knowledge entry `status:` field vocabulary (M020 schema evolution)

### Convention

Every `knowledge/**/MEM*.md` and `knowledge/spec/**` entry carries a
`status:` frontmatter field with one of three values from a **closed enum**:

| Value      | Meaning                                                                 |
|------------|-------------------------------------------------------------------------|
| `candidate`  | Tentative — written by a dispatch or operator, not yet reviewed.        |
| `graduated`  | Reviewed and accepted; visible to the default query surface (FR-2).     |
| `archived`   | Reviewed and rejected, OR superseded by a graduated canonical entry.    |

### Default semantics for pre-M020 entries

Entries that exist on main without a `status:` field are treated as
`graduated` on first read (most conservative — do not re-review what was
already implicitly trusted). The field is written on next touch by
`scripts/knowledge/lib/frontmatter.sh` per FR-10. **No bulk migration pass
is performed in M020.**

### Companion fields

Two paired fields land in the same schema evolution and are documented
together for cohesion:

- `decision_history:` — append-only YAML list of records. Each record is a
  YAML map containing `rationale: <text>`, `timestamp: <ISO 8601 UTC>`,
  `operator: <identifier>`, `cluster_id: <id-or-empty>`. Written by
  `graduate.sh` (P03 cluster-aware path) and `archive` operations.
  Compaction is deferred (NG-6).
- `archived_into: <entry-id>` — single canonical entry-ID back-reference
  written when an entry is archived as a sibling of a graduated canonical
  entry within a cluster. Empty / absent for outright-rejection archives.

### Authority

M020 holds exclusive schema authority over these fields per FR-9. Consuming
milestones (M024 universal intake, M019 Tier 2+3 observability) MAY READ
the fields but MUST NOT introduce new fields without a follow-up M020 D-row.

### Authorising decision

`.orchestrator/DECISIONS.md` D024 (2026-04-25).

### MEM031 internal verification (informational)

- `scripts/verify/m020-p01-mem031-vocabulary.sh` checks the closed enum and
  the pre-M020 default are documented verbatim.
- `scripts/verify/knowledge-schema-lint.sh` (lands in P02 per FR-9 + SC-8)
  enforces the schema-authority boundary at lint time.
```

### Step 3: Register MEM031 in `KNOWLEDGE-INDEX.md`

Open `/Users/brettkellgren/Sites/orchestrator/KNOWLEDGE-INDEX.md`
and add a row to the conventions table matching the format of the existing
MEM030 row. Required field values:

- ID: `MEM031`
- scope_tags: `[project], [milestone:M020]`
- category: `conventions`
- confidence: `0.90`
- created_at: `2026-04-25`
- last_verified: `2026-04-25`
- hit_count: `0`
- description: `Knowledge entry status: field vocabulary (M020 schema evolution)`

Match the column ordering already used in the file. If the file uses pipe-
delimited markdown rows, mirror that format.

### Step 4: Create the verification scripts for this task

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-mem031-vocabulary.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-mem031-vocabulary.sh — assert MEM031 documents the closed enum
# and pre-M020 default semantics. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NOTE="$ROOT/knowledge/conventions/MEM031.md"

if [ ! -f "$NOTE" ]; then
  echo "FAIL: MEM031.md missing at $NOTE"
  exit 1
fi

# Closed enum values must all appear
for token in candidate graduated archived; do
  if ! grep -qw "$token" "$NOTE"; then
    echo "FAIL: MEM031 missing closed-enum token: $token"
    exit 1
  fi
done

# Pre-M020 default sentence
if ! grep -q "treated as .graduated" "$NOTE"; then
  echo "FAIL: MEM031 missing pre-M020 default sentence (treated as graduated)"
  exit 1
fi

# Schema-authority citation
if ! grep -qw "FR-9" "$NOTE"; then
  echo "FAIL: MEM031 missing FR-9 schema-authority citation"
  exit 1
fi

# Authorising decision citation
if ! grep -qw "D024" "$NOTE"; then
  echo "FAIL: MEM031 missing D024 authorising-decision citation"
  exit 1
fi

echo "PASS: MEM031 vocabulary contract honored"
exit 0
```

Create
`/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p01-d024-row.sh`:

```bash
#!/usr/bin/env bash
# m020-p01-d024-row.sh — assert D024 row exists in DECISIONS.md and cites
# the load-bearing schema-authority tokens. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT/.orchestrator/DECISIONS.md"

if [ ! -f "$FILE" ]; then
  echo "FAIL: DECISIONS.md missing at $FILE"
  exit 1
fi

if ! grep -qw "D024" "$FILE"; then
  echo "FAIL: D024 row missing from DECISIONS.md"
  exit 1
fi

# The D024 row line must mention status, candidate, graduated, archived, MEM031
line="$(grep "^| D024 " "$FILE" | head -1)"
if [ -z "$line" ]; then
  echo "FAIL: D024 not in pipe-row form (expected '| D024 |' prefix)"
  exit 1
fi

for token in status: candidate graduated archived MEM031 FR-9; do
  case "$line" in
    *"$token"*) ;;
    *)
      echo "FAIL: D024 row missing token: $token"
      exit 1
      ;;
  esac
done

echo "PASS: D024 row present and cites schema-authority tokens"
exit 0
```

Both scripts must be marked executable (`chmod +x`).

## Must-Haves

- D024 row appears in `.orchestrator/DECISIONS.md` with `status:`, `candidate`, `graduated`, `archived`, `MEM031`, `FR-9` tokens.
- `knowledge/conventions/MEM031.md` exists with the closed-enum vocabulary, pre-M020 default sentence, FR-9 citation, and D024 citation.
- `KNOWLEDGE-INDEX.md` includes a MEM031 conventions row.
- `scripts/verify/m020-p01-mem031-vocabulary.sh` and `scripts/verify/m020-p01-d024-row.sh` exist, are executable, and exit 0 against the produced artifacts.

## Verification

```bash
bash scripts/verify/m020-p01-mem031-vocabulary.sh
bash scripts/verify/m020-p01-d024-row.sh
```

Both must print `PASS:` and exit 0.

Additionally:

```bash
bash scripts/knowledge/rebuild-index.sh
```

Must succeed (rebuilds the knowledge index — confirms MEM031 frontmatter is
parseable by existing knowledge tooling).

## Inputs

### From Previous Tasks

None.

### From Disk (Pre-existing)

- `/Users/brettkellgren/Sites/orchestrator/.orchestrator/DECISIONS.md` — existing D-row table; append D024 at the end preserving column shape.
- `/Users/brettkellgren/Sites/orchestrator/knowledge/conventions/MEM030.md` — reference for frontmatter shape + content style of a recent convention entry; copy frontmatter field set verbatim, change ID + dates + body.
- `/Users/brettkellgren/Sites/orchestrator/KNOWLEDGE-INDEX.md` — existing conventions table; append a MEM031 row matching the existing format.
- `/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/rebuild-index.sh` — existing index rebuilder; run after MEM031 is in place to confirm parseability.

## Constraints

- **AD-19 shape compliance**: every `Check:` and verification command in
  this task plan is a single-script-file invocation. No inline compound
  bash.
- **MEM001 + MEM003**: bash 3.2 compatible (no `declare -A`); structured
  prefixed output (`PASS:` / `FAIL:`); idempotent.
- **CON-4 (Surgical Precision)**: do not touch any other D-row in
  `DECISIONS.md`; do not touch any other entry in `KNOWLEDGE-INDEX.md`; do
  not touch any other file in `knowledge/conventions/`.
- **FR-9 (schema authority)**: MEM031 vocabulary is a closed enum. Do not
  introduce a fourth state value in this task — that requires a follow-up
  D-row.
- **Token preservation**: the verification scripts grep for literal tokens
  (`status:`, `candidate`, `graduated`, `archived`, `MEM031`, `D024`,
  `FR-9`). All must appear verbatim in the produced artifacts.

## Expected Output

After this task completes:

1. `.orchestrator/DECISIONS.md` is one row longer (D024 appended).
2. `knowledge/conventions/MEM031.md` exists (~50–100 lines).
3. `KNOWLEDGE-INDEX.md` is one row longer (MEM031 entry).
4. `scripts/verify/m020-p01-mem031-vocabulary.sh` exists and is executable.
5. `scripts/verify/m020-p01-d024-row.sh` exists and is executable.
6. Both verification scripts print `PASS:` and exit 0.
7. `bash scripts/knowledge/rebuild-index.sh` exits 0.

**Done when**: both verification scripts return `PASS:` and the rebuild-
index dry-run succeeds.
