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

Neither file is created by the orchestrator. Operators author them by
hand (or via configuration management). The preferences helper at
`scripts/knowledge/lib/preferences.sh` only reads from these files and
NEVER writes to either one.

## Keys

| Key                      | Type   | Range / Enum                         | Default         |
|--------------------------|--------|--------------------------------------|-----------------|
| `default_state_filter`   | string | `candidate`, `graduated`, `archived` | `graduated`     |
| `similarity_threshold`   | float  | 0.0–1.0                              | 0.7             |
| `staleness_threshold`    | int    | 1–365 (days)                         | 14              |
| `preferred_cluster_size` | int    | 1–50                                 | 8               |
| `operator_identifier`    | string | non-empty                            | `unknown@local` |

The vocabulary is closed: any key not in this table is rejected by
`pref_resolve` (returns non-zero with `FAIL: pref_resolve: unknown key`
on stderr). Adding a key requires an M020 D-row + a schema-evolution
note (parallels the FR-9 schema-authority pattern for entry frontmatter
documented in `knowledge/conventions/MEM031.md`).

## Precedence

For every key, the resolution order is:

1. **CLI flag** (when the consumer script accepts one — e.g.
   `query.sh --state` or `consolidate-artifacts.sh --cluster
   <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]`).
2. **Project preferences file** (`.orchestrator/preferences.yml`).
3. **User preferences file** (`~/.orchestrator/preferences.yml`).
4. **Built-in default** (table above).

Each key resolves INDEPENDENTLY (THREAT-007 disposition). If the
project file declares only `similarity_threshold` and the user file
declares only `staleness_threshold`, the project file's value wins for
the first key and the user file's value wins for the second; this is
NOT a conflict.

### Worked partial-overlap example

```yaml
# .orchestrator/preferences.yml (project)
similarity_threshold: 0.6

# ~/.orchestrator/preferences.yml (user)
staleness_threshold: 30
operator_identifier: alice@example.com
```

Resolution:

- `similarity_threshold` → `0.6` (project wins; user does not declare).
- `staleness_threshold` → `30` (user wins; project does not declare).
- `operator_identifier` → `alice@example.com` (user wins; project does
  not declare).
- `default_state_filter` → `graduated` (built-in default).
- `preferred_cluster_size` → `8` (built-in default).

No conflict is reported: per-key independent resolution is the
contract.

## Malformed values

When a preferences file declares a key with a malformed value (non-
numeric for numeric keys, out-of-range for bounded keys, value outside
the closed enum for `default_state_filter`), `pref_resolve`:

- Skips the malformed source.
- Emits a single-line stderr diagnostic: `WARN: pref_resolve: malformed
  value for '<key>' in '<file>': '<raw-value>' — falling back to <next>`.
- Continues to the next source per the precedence chain.
- NEVER rewrites the preferences file (operator-owned).

### Worked malformed example

```yaml
# .orchestrator/preferences.yml (project)
similarity_threshold: not-a-number
```

No user file is present.

Invocation: `scripts/knowledge/consolidate-artifacts.sh --cluster
<orch-root> <milestone>`

- stdout: `effective_threshold=0.7` (the built-in default).
- stderr: `WARN: pref_resolve: malformed value for 'similarity_threshold'
  in '<project-path>': 'not-a-number' — falling back to user-or-default`.
- The project preferences file is byte-identical (md5 unchanged) before
  and after the invocation.

The same fallback chain applies to every key: out-of-range integers,
non-numeric floats, and enum violations all degrade to the next source
in the precedence list rather than aborting.

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

Example team-wide project file:

```yaml
similarity_threshold: 0.65
default_state_filter: graduated
```

Example per-operator user file (alice):

```yaml
operator_identifier: alice@example.com
staleness_threshold: 7
```

Resolved values: project wins for `similarity_threshold` and
`default_state_filter`; user wins for `operator_identifier` and
`staleness_threshold`; `preferred_cluster_size` falls back to the
built-in default.

### No preferences file

Built-in defaults take effect. `consolidate-artifacts.sh --cluster`
emits `effective_threshold=0.7` on stdout (the new audit line is
emitted on every invocation regardless of whether a preferences file
exists; pre-M020 behavior is otherwise unchanged).

## Implementation

The helper at `scripts/knowledge/lib/preferences.sh` exposes
`pref_resolve <key>`. Consumer scripts:

- `scripts/knowledge/query.sh` — resolves `default_state_filter` when
  no `--state` flag is supplied on the CLI.
- `scripts/knowledge/consolidate-artifacts.sh --cluster` — resolves
  `similarity_threshold` when no positional threshold is supplied on
  the CLI; emits `effective_threshold=<N>` on stdout BEFORE the per-
  cluster output blocks for audit purposes.

The helper is read-only (FR-8 / CON-1) — it never writes to either
preferences file. Path resolution honors `PROJECT_ROOT` and `HOME`
environment variables for fixture isolation in tests (the P01/P02/P05
verifier convention).

## Related references

- `knowledge/conventions/MEM031.md` — schema-authority pattern for
  closed-enum vocabularies (the FR-9 cousin of this layer's closed
  key vocabulary).
- `references/state-machine.md` — definitions of the
  `candidate`/`graduated`/`archived` state values referenced by
  `default_state_filter`.
- `references/file-formats.md` — full inventory of orchestrator file
  formats; `preferences.yml` is the M020 addition.
