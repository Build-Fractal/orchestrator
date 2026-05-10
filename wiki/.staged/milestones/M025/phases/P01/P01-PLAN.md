---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M025"
goal: "Remediate the M013/P04/T04 regression: patch claude-code.sh --hook-config to emit valid Claude Code schema, patch install-claude-code.sh to merge-not-overwrite ~/.claude/settings.json, add coexistence + reversibility gates, and file the knowledge entries. Claude Code runtime scoped (FR-9); Codex/Cursor adapters + installers stay byte-identical under negative-grep guard (CON-5). Bash 3.2 + optional-jq compatible throughout (CON-1, CON-2)."
demo_sentence: "On a fresh home with a pre-seeded GSD-shaped ~/.claude/settings.json, running bash packaging/install/install-claude-code.sh --project-dir <tmp-project> leaves the file with (a) every pre-existing top-level key preserved byte-identically, (b) the orchestrator's hook entries appended under real CC event names (post_verify → Stop, before_commit → PreToolUse with Bash matcher) each tagged _orchestrator_managed: true, (c) no wrapper metadata (runtime/hook_count/target_file) at root; running it a second time produces a byte-identical file (idempotent); running the documented uninstall path restores the file to its pre-install sha256. bash scripts/verify/m025-p01-phase-suite.sh exits 0."
risk: "medium"
depends_on: []
---

## Must-Haves

<!-- Every Check is a single-script-file shape (AD-19). All verification logic
     lives inside scripts/verify/m025-p01-*.sh. Negative-grep guard enforces
     FR-9 (Claude Code only); every new script passes bash-3.2 compat.
     Event mapping (planner decision, locked here): post_verify → Stop;
     before_commit → PreToolUse + Bash matcher + command-regex "git commit";
     before_tasks / after_tasks / before_implement / after_implement → deferred
     (no CC equivalent), documented as TODO(M025+) in adapter source and
     references/hooks.md.
     Tagging (planner decision, locked here): inline "_orchestrator_managed":
     true on each orchestrator-inserted hook object. No sidecar manifest.
     Byte-identity invariant: install-codex.sh, install-cursor.sh, and the
     codex + cursor runtime adapters stay untouched. -->

### Truths

- `scripts/dispatch/adapters/runtime/claude-code.sh` `--hook-config` mode emits a JSON document whose root is a Claude Code `hooks` object — no `runtime`, `hook_count`, or `target_file` keys at root. Each entry uses the CC matcher+hooks[] shape: `{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "<cmd>", "_orchestrator_managed": true}]}], "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "<cmd>", "_orchestrator_managed": true}]}]}}`. Only the two mapped events (`Stop`, `PreToolUse`) are present in the output. A source-level comment block enumerates the four deferred orchestrator events (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`) with `TODO(M025+):` tracking notes.
  - Check: `bash scripts/verify/m025-p01-hook-schema.sh`

- `packaging/install/install-claude-code.sh` reads any pre-existing `~/.claude/settings.json` via a new helper `merge_settings_json` (added to a new file `scripts/util/settings-merge.sh`) that (a) preserves every top-level key not owned by the orchestrator byte-identically, (b) merges the orchestrator's `hooks.Stop[]` and `hooks.PreToolUse[]` arrays into any existing arrays at those paths without replacing them (orchestrator entries appended after user entries), (c) skips insertion of any orchestrator entry that already exists in the target (idempotency via `_orchestrator_managed: true` tag + command-string match), (d) writes via temp-file-then-rename. The helper uses `jq` when available (`-S` for deterministic ordering) and falls back to an awk/sed path that produces semantically-equivalent output when `jq` is absent. `--dry-run` emits `would_write=<path>` plus a canonical post-merge preview to stdout without touching disk. A `--uninstall` flag reads the current `settings.json`, removes every entry whose `_orchestrator_managed` is `true`, writes back via temp-file-then-rename, and reports `removed=<N>` entries.
  - Check: `bash scripts/verify/m025-p01-merge-preservation.sh`

- `tests/fixtures/m025-p01/gsd-baseline/settings.json` exists as a representative GSD-shaped baseline containing at minimum `{"$schema", "statusLine", "hooks": {"SessionStart": [...], "PostToolUse": [...]}, "permissions"}`. The fixture is opaque to the installer (unknown keys preserved verbatim). `tests/fixtures/m025-p01/expected-post-install.json` pins the post-install shape; `tests/fixtures/m025-p01/expected-post-uninstall.sha256` pins the byte-identical round-trip sum.
  - Check: `bash scripts/verify/m025-p01-coexistence.sh`

- A round-trip install-then-uninstall sequence against the fixture produces a `settings.json` whose sha256 matches the pre-install sha256 byte-for-byte. The uninstaller removes only entries tagged `_orchestrator_managed: true`; every other key is untouched. Tagging is the sole authority for what gets removed.
  - Check: `bash scripts/verify/m025-p01-uninstall-reversibility.sh`

- Running the installer twice in succession against the same fixture produces byte-identical output on the second run (no duplicate orchestrator entries accreted). The idempotency check compares the sha256 of the post-first-install file against the sha256 of the post-second-install file.
  - Check: `bash scripts/verify/m025-p01-idempotency.sh`

- `packaging/install/install-codex.sh`, `packaging/install/install-cursor.sh`, `scripts/dispatch/adapters/runtime/codex.sh`, and `scripts/dispatch/adapters/runtime/cursor.sh` are BYTE-IDENTICAL to their pre-P01 state — sha256 pins embedded in the gate script match post-phase. Negative grep: none of those four files contain `_orchestrator_managed`, `settings-merge`, or `M025`.
  - Check: `bash scripts/verify/m025-p01-runtime-scope-guard.sh`

- Every new/modified `.sh` file in P01 passes bash 3.2 compatibility (no `declare -A`, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`, no `<(...)`/`>(...)`, no `&>`/`|&`) and the anti-pattern lint. Gate self-excludes via case-branch + comment-discipline synonyms (P03/T05 + P04/T06 precedent).
  - Check: `bash scripts/verify/m025-p01-bash32-compat.sh`

- `references/installation.md` contains an "Uninstall" section documenting the `--uninstall` flag and the manual-uninstall recipe (remove entries whose `_orchestrator_managed` is `true`). `references/hooks.md` contains the six-event → CC-event mapping table, explicitly listing the two mapped events and the four deferred events with their `TODO(M025+)` rationale. `CHANGELOG.md` has a new top-entry under a `## v0.9.1` heading naming the M013/P04/T04 regression, the three remediation surfaces (schema, merge, reversibility), and a link to `specs/021-github-installer-coexistence/spec.md`.
  - Check: `bash scripts/verify/m025-p01-docs.sh`

- [`knowledge/lessons/MEM026.md`](../../../../knowledge/lessons/MEM026.md) (next available MEM number; see `KNOWLEDGE-INDEX.md`) is a new lesson entry titled "M013/P04/T04 hook-config regression" that cross-references commit `d33b8a7`, explains why the P04 gates missed the regression (no pre-existing-settings-file path exercised), and names the remediation milestone (M025). `knowledge/patterns/MEM0##.md` (next available) is a new pattern entry for `merge-not-overwrite-user-scope-config` capturing the jq-with-awk-fallback + inline-tag convention. `KNOWLEDGE-INDEX.md` rebuilt via `bash scripts/knowledge/rebuild-index.sh` lists both new entries.
  - Check: `bash scripts/verify/m025-p01-knowledge-entries.sh`

- Recent Changes dual-write: `CLAUDE.md` and `AGENTS.md` both have their `# >>> orchestrator:recent-changes >>>` region updated with a one-line M025 P01 summary via `scripts/util/dual-write-runtime-md.sh --marker recent-changes --content "<fragment>" --file CLAUDE.md --file AGENTS.md`.
  - Check: `bash scripts/verify/m025-p01-recent-changes.sh`

- `bash scripts/verify/m025-p01-phase-suite.sh` orchestrates all P01 gates in dependency order (hook-schema, merge-preservation, coexistence, uninstall-reversibility, idempotency, runtime-scope-guard, bash32-compat, docs, knowledge-entries, recent-changes) and exits 0 on green, non-zero with per-gate PASS/FAIL breakdown otherwise. SUMMARY line: `SUMMARY: m025-p01-phase-suite.sh pass=N fail=M`.
  - Check: `bash scripts/verify/m025-p01-phase-suite.sh`

### Artifacts

- `scripts/dispatch/adapters/runtime/claude-code.sh` (contains "_orchestrator_managed", contains "TODO(M025+)") — modify-in-place, rewrite `--hook-config` emitter body
- `packaging/install/install-claude-code.sh` (contains "merge_settings_json", contains "--uninstall") — modify-in-place, replace overwrite with merge + add uninstall flag
- `scripts/util/settings-merge.sh` (min 120 lines, contains "jq", contains "awk") — create
- `tests/fixtures/m025-p01/gsd-baseline/settings.json` (contains "statusLine", contains "SessionStart") — create
- `tests/fixtures/m025-p01/expected-post-install.json` (contains "_orchestrator_managed") — create
- `tests/fixtures/m025-p01/expected-post-uninstall.sha256` (min 1 line) — create
- `scripts/verify/m025-p01-hook-schema.sh` (min 25 lines, contains "_orchestrator_managed") — create
- `scripts/verify/m025-p01-merge-preservation.sh` (min 40 lines, contains "gsd-baseline") — create
- `scripts/verify/m025-p01-coexistence.sh` (min 40 lines, contains "expected-post-install") — create
- `scripts/verify/m025-p01-uninstall-reversibility.sh` (min 30 lines, contains "sha256") — create
- `scripts/verify/m025-p01-idempotency.sh` (min 25 lines, contains "sha256") — create
- `scripts/verify/m025-p01-runtime-scope-guard.sh` (min 30 lines, contains "codex", contains "cursor") — create
- `scripts/verify/m025-p01-bash32-compat.sh` (min 40 lines, contains "declare -A") — create
- `scripts/verify/m025-p01-docs.sh` (min 25 lines, contains "v0.9.1") — create
- `scripts/verify/m025-p01-knowledge-entries.sh` (min 20 lines, contains "MEM026") — create
- `scripts/verify/m025-p01-recent-changes.sh` (min 20 lines, contains "dual-write") — create
- `scripts/verify/m025-p01-phase-suite.sh` (min 40 lines, contains "SUMMARY:") — create
- `references/installation.md` (contains "Uninstall") — modify-in-place, add Uninstall section
- `references/hooks.md` (contains "M025", contains "TODO(M025+)") — modify-in-place, add six-event mapping table
- `CHANGELOG.md` (contains "v0.9.1", contains "M013/P04/T04") — modify-in-place, add v0.9.1 entry
- [`knowledge/lessons/MEM026.md`](../../../../knowledge/lessons/MEM026.md) (min 20 lines, contains "d33b8a7") — create (adjust MEM number at task time if KNOWLEDGE-INDEX advanced)
- `knowledge/patterns/MEM0##.md` (min 20 lines, contains "merge-not-overwrite") — create (next MEM number after MEM026)
- `KNOWLEDGE-INDEX.md` — modify (rebuilt via `scripts/knowledge/rebuild-index.sh`)
- `CLAUDE.md` (Recent Changes region) — modify-in-place via dual-write helper
- `AGENTS.md` (Recent Changes region) — modify-in-place via dual-write helper

### Key Links

- `specs/021-github-installer-coexistence/spec.md` → [`.orchestrator/milestones/M025/M025-ROADMAP.md`](../../../../milestones/M025/M025-ROADMAP.md) (spec authoritatively drives this phase's scope)
- [`.orchestrator/milestones/M013/phases/P04/P04-SUMMARY.md`](../../../../milestones/M013/phases/P04/P04-SUMMARY.md) → this plan (regression origin; read-only context)
- `packaging/bundle/hooks/post-verify.json` → `scripts/dispatch/adapters/runtime/claude-code.sh` (hook descriptor consumed by the new schema emitter)
- `scripts/util/dual-write-runtime-md.sh` → `m025-p01-recent-changes.sh` (verifier asserts dual-write outcome)

## Tasks

### T01: Hook-config schema fix + event mapping

**Zero-context brief.** The file `scripts/dispatch/adapters/runtime/claude-code.sh` at lines 126–150 contains a `--hook-config` mode that emits JSON. The current emission wraps a `hooks` array in metadata keys (`runtime`, `hook_count`, `target_file`) and uses orchestrator-internal event names (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`, `post_verify`) that Claude Code does not recognize. Replace the emission with a valid Claude Code `hooks` object using the exact mapping below. Do not change the `--probe` or `--register` modes.

**Mapping (locked):**

| Orchestrator event | CC target | Notes |
|---|---|---|
| `post_verify` | `Stop` | Command: `orchestrator-post-verify`. No matcher (Stop fires terminal). |
| `before_commit` | `PreToolUse` | Matcher: `Bash`. Additional per-hook filter via command-regex on `git commit` is applied inside the command wrapper, not in the matcher (the matcher is CC's tool-name only). Command: `orchestrator-before-commit`. |
| `before_tasks` | **deferred** | No CC equivalent. TODO(M025+): revisit if CC gains a task-start event. |
| `after_tasks` | **deferred** | Same. |
| `before_implement` | **deferred** | Same. |
| `after_implement` | **deferred** | Same. |

**Required output shape (JSON, pretty-printed):**

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "orchestrator-post-verify", "_orchestrator_managed": true }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "orchestrator-before-commit", "_orchestrator_managed": true }
        ]
      }
    ]
  }
}
```

**Source-level requirements:**

1. Prepend a comment block (4–8 lines) above the `--hook-config` mode body listing the four deferred orchestrator events with `TODO(M025+):` markers. Preserve the existing mode-documentation comment (lines 25–29) — append, do not replace.
2. The emitter must be a single here-doc or a single `cat` invocation — no conditional branches on event mapping at runtime. The mapping is static.
3. Keep the HOME guard used by `--register` mode for consistency; not strictly needed for stdout emission but preserves adapter convention.

**Verification.** `scripts/verify/m025-p01-hook-schema.sh` (create as artifact) runs `bash scripts/dispatch/adapters/runtime/claude-code.sh --hook-config | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'hooks' in d; assert set(d['hooks'].keys()) == {'Stop','PreToolUse'}; assert d['hooks']['PreToolUse'][0]['matcher']=='Bash'; …"` and asserts: (a) root keys are exactly `{"hooks"}`, (b) `hooks.Stop[0].hooks[0].command == "orchestrator-post-verify"`, (c) `hooks.PreToolUse[0].matcher == "Bash"`, (d) every leaf hook object carries `"_orchestrator_managed": true`, (e) grep the adapter source for the four `TODO(M025+):` markers.

**Exit criteria.** Adapter emits valid schema. Schema gate passes. Codex + Cursor adapters untouched (runtime-scope guard gate will verify at phase close).

### T02: Merge-not-overwrite installer + uninstall flag

**Zero-context brief.** The file `packaging/install/install-claude-code.sh` at lines 133–150 currently writes `$hook_json` to `$HOME/.claude/settings.json` via `printf > "$hook_target"`, unconditionally replacing any existing file. Replace this block with a merge call into a new helper `scripts/util/settings-merge.sh`. Add a `--uninstall` flag to the installer that removes only orchestrator-tagged entries.

**Create `scripts/util/settings-merge.sh` (~120 lines) with this CLI:**

```
bash scripts/util/settings-merge.sh merge --target <path> --fragment <json-string> [--dry-run]
bash scripts/util/settings-merge.sh uninstall --target <path> [--dry-run]
```

**Merge algorithm:**

1. If `--target` does not exist, write `<fragment>` verbatim (new-file path).
2. If `--target` exists, parse as JSON. On parse failure, exit 4 with `FAIL: <target> is not valid JSON; refusing to merge` on stderr. Never overwrite.
3. For each top-level key in the fragment:
   - If the key is `hooks`, deep-merge per-event arrays. For each event (`Stop`, `PreToolUse`, etc.), append the fragment's entries to the existing event array ONLY if the entry's command string is not already present in the array under an object carrying `"_orchestrator_managed": true` (idempotency guard).
   - If the key is anything else, set it only if absent in the target. Do not overwrite existing values.
4. Every non-orchestrator top-level key in the target is preserved byte-identically.
5. Write output via temp-file-then-rename (`$target.tmp.$$` → `mv -f`).

**Uninstall algorithm:**

1. Parse `--target` as JSON. On parse failure, exit 4 as above.
2. For each event array in `hooks`, remove objects whose `hooks[].command` has `_orchestrator_managed: true` on any hook entry — if that removal leaves the outer wrapper with an empty `hooks` array, remove the wrapper too. If that leaves the event key with an empty array, remove the event key. If that leaves `hooks` empty, remove the `hooks` key.
3. Write via temp-file-then-rename. Report `removed=<N>` to stdout where N is the count of outer-wrapper removals.

**jq path vs awk/sed fallback.** Detect `jq` via `command -v jq >/dev/null 2>&1`. Under jq, use `jq -S` (sorted keys, stable output). Under fallback, use a bash-3.2-compatible awk script to parse + reshape JSON. The fallback output is NOT required to be byte-identical to jq output — semantic equivalence is the contract. The gate compares parsed structure via python, not byte-identity.

**Installer changes (`install-claude-code.sh`):**

1. Replace lines 138–150 (the `DRY_RUN`/FORCE/mkdir/printf block) with a call to the merge helper:
   ```bash
   hook_json="$(bash "$ADAPTER" --hook-config 2>/dev/null)"
   hook_target="$HOME/.claude/settings.json"
   mkdir -p "$HOME/.claude"
   if [ "$DRY_RUN" = "1" ]; then
     bash "$REPO_ROOT/scripts/util/settings-merge.sh" merge --target "$hook_target" --fragment "$hook_json" --dry-run
   else
     bash "$REPO_ROOT/scripts/util/settings-merge.sh" merge --target "$hook_target" --fragment "$hook_json"
   fi
   hooks_wired=1
   ```
2. Add a `--uninstall` flag parser branch. When set, skip probe/register/config-stage and dispatch only to `settings-merge.sh uninstall --target "$hook_target"` (plus uninstall the staged `.orchestrator/config.yml` via `rm -f` gated by a marker comment in the config). Emit `UNINSTALLED: hooks-removed=<N> config-removed=<0|1>` and exit 0.
3. `--force` is retained but its semantics change: it now forces insertion of orchestrator entries even if a same-command entry already exists in the target (intended for recovering from manual edits that stripped the managed tag).

**Verification.** `scripts/verify/m025-p01-merge-preservation.sh` (create) seeds `$HOME/.claude/settings.json` from `tests/fixtures/m025-p01/gsd-baseline/settings.json`, runs the installer, diffs the result against `expected-post-install.json` through a python structural comparator (ignoring whitespace/key-order). Asserts: (a) every top-level key from the seed survives, (b) `hooks.SessionStart` / `hooks.PostToolUse` from the seed are unchanged, (c) `hooks.Stop` and `hooks.PreToolUse` are appended. `scripts/verify/m025-p01-idempotency.sh` runs the installer twice and asserts sha256 equality on runs 1-vs-2.

**Exit criteria.** Merge works with and without jq. Idempotent on double-install. Uninstall flag operational. Gates pass.

### T03: Fixture + gate suite

**Zero-context brief.** Create the fixture tree and all P01 verification scripts except those already created by T01 (hook-schema) and T02 (merge-preservation, idempotency). T03 creates the seven remaining gates plus the phase-suite orchestrator.

**Fixture tree:**

- `tests/fixtures/m025-p01/gsd-baseline/settings.json` — representative GSD-authored settings.json. Shape:
  ```json
  {
    "$schema": "https://json.schemastore.org/claude-code-settings.json",
    "statusLine": { "type": "command", "command": "echo gsd-statusline" },
    "hooks": {
      "SessionStart": [ { "hooks": [ { "type": "command", "command": "~/.claude/hooks/gsd-session-start.sh" } ] } ],
      "PostToolUse": [ { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "~/.claude/hooks/gsd-post-edit.sh" } ] } ]
    },
    "permissions": { "allow": ["Bash(git status)"] }
  }
  ```
- `tests/fixtures/m025-p01/expected-post-install.json` — result of merging the orchestrator fragment into the baseline. Hand-authored; pinned.
- `tests/fixtures/m025-p01/expected-post-uninstall.sha256` — sha256 of the GSD baseline (pre-install state). Generated at fixture-create time via `shasum -a 256 gsd-baseline/settings.json | awk '{print $1}'`.

**Gate scripts (all follow M013/P04 pattern — set -u, explicit exit codes, pass/fail counts, SUMMARY line):**

1. `scripts/verify/m025-p01-coexistence.sh` — end-to-end: `HOME=$(mktemp -d)`, seed settings.json from fixture, run installer, compare result to `expected-post-install.json` via python structural comparator. Exit 0 on match.
2. `scripts/verify/m025-p01-uninstall-reversibility.sh` — round-trip: capture sha256 of seeded file, install, uninstall (`bash install-claude-code.sh --uninstall`), capture post-uninstall sha256, assert equal to pre-install sha256 and to `expected-post-uninstall.sha256`.
3. `scripts/verify/m025-p01-runtime-scope-guard.sh` — embeds pinned sha256 of `install-codex.sh`, `install-cursor.sh`, `scripts/dispatch/adapters/runtime/codex.sh`, `scripts/dispatch/adapters/runtime/cursor.sh` captured at plan time (the gate script Read these files pre-edit and embeds the digests as literal strings). Post-phase shasum comparison must equal the literals. Additionally grep those four files for `_orchestrator_managed`, `settings-merge`, `M025` and assert zero matches.
4. `scripts/verify/m025-p01-bash32-compat.sh` — scans all new/modified `.sh` files in P01 for bash 3.2 violations using the M013/P04/T06 pattern (`m013-p04-bash32-compat.sh` as reference; self-exclude via case-branch + comment-discipline synonyms).
5. `scripts/verify/m025-p01-docs.sh` — greps `references/installation.md` for "Uninstall" section heading + uninstall recipe keywords; greps `references/hooks.md` for the mapping table and `TODO(M025+)` markers on the four deferred events; greps `CHANGELOG.md` for the v0.9.1 heading and M013/P04/T04 reference. (Note: T04 populates these; T03 creates the gate that will fail until T04 lands.)
6. `scripts/verify/m025-p01-knowledge-entries.sh` — asserts [`knowledge/lessons/MEM026.md`](../../../../knowledge/lessons/MEM026.md) (or whichever number T04 picks) exists and contains `d33b8a7` + `M013/P04/T04`; asserts a matching pattern entry exists; asserts `KNOWLEDGE-INDEX.md` lists both.
7. `scripts/verify/m025-p01-recent-changes.sh` — greps `CLAUDE.md` and `AGENTS.md` `# >>> orchestrator:recent-changes >>>` regions for a `M025` or `021-github-installer-coexistence` fragment.
8. `scripts/verify/m025-p01-phase-suite.sh` — orchestrator. Invokes all 10 gates in order, tallies pass/fail, prints `SUMMARY: m025-p01-phase-suite.sh pass=N fail=M`, exits 0 iff `fail=0`.

**Fixture-capture helper.** Before writing the `expected-post-install.json`, the task agent should run the merge manually against the seed and capture the output, hand-verify it's correct, then commit as the pinned snapshot. Pattern lifted from M013/P04/T02 `expected-sync-dryrun-manifest.txt`.

**Exit criteria.** All fixtures in place. All gates (except 5 + 6 + 7, which depend on T04) invocable and green. Phase-suite runs end-to-end.

### T04: Docs + knowledge entries + dual-write

**Zero-context brief.** Close the phase with user-facing documentation and the knowledge-tree entries the spec's Constitution Check (Principle VII) commits to.

**Doc writes:**

1. `references/installation.md` — add `## Uninstall` section. Content: (a) one sentence naming `--uninstall` as the canonical removal path, (b) the manual recipe (use jq or a text editor to remove entries whose `_orchestrator_managed` is `true`), (c) a note that uninstall preserves every other key byte-identically.
2. `references/hooks.md` — add (or extend, if the file already has a hook-mapping section) a subsection titled `## Claude Code Event Mapping`. Embed the six-row mapping table from the P01-PLAN. For the four deferred events, each row carries a `TODO(M025+):` tracking note naming the proposed deferral reason.
3. `CHANGELOG.md` — add a `## v0.9.1 (2026-04-23)` heading at the top (under the "Unreleased"/"Latest" region, matching existing file convention). Entry body: bullet list naming (a) the M013/P04/T04 regression, (b) FR-1 schema fix, (c) FR-3 merge-not-overwrite, (d) FR-6 coexistence fixture, (e) FR-8 uninstall reversibility. Link to `specs/021-github-installer-coexistence/spec.md`.

**Knowledge entries.** Determine next available MEM numbers by reading `KNOWLEDGE-INDEX.md`. Create:

1. `knowledge/lessons/MEM<N>.md` titled "M013/P04/T04 hook-config regression" — frontmatter matching existing entries in `knowledge/lessons/`. Body: (a) what regressed (two-paragraph technical summary); (b) why the P04 gate suite missed it (no pre-existing-settings path exercised in `m013-p04-post-verify-hook.sh`); (c) lesson: every user-scope-config write must have a coexistence gate with a pre-seeded non-orchestrator fixture.
2. `knowledge/patterns/MEM<N+1>.md` titled "merge-not-overwrite user-scope config" — frontmatter matching `knowledge/patterns/`. Body: (a) the problem (user-scope config files are jointly owned); (b) the pattern (inline `_orchestrator_managed` tag + jq-with-awk-fallback merge + temp-file-then-rename); (c) the gate shape (coexistence fixture + round-trip reversibility).

Then run `bash scripts/knowledge/rebuild-index.sh` to refresh `KNOWLEDGE-INDEX.md`.

**Dual-write.** Invoke `bash scripts/util/dual-write-runtime-md.sh --marker recent-changes --content "- M025/P01: settings.json coexistence — hook-config schema fix + merge-not-overwrite installer + uninstall reversibility" --file CLAUDE.md --file AGENTS.md`. The existing 021-github-installer-coexistence fragment from `orchestrator:specify` is replaced by the P01-completion fragment; dual-write helper handles this.

**Update CLAUDE.md status line.** In the `## Project Status` section of CLAUDE.md, edit the line naming completed milestones to add "M025 (installer coexistence, 2026-04-23)" alongside the existing entries. Update the Forward Roadmap paragraph to remove the stale "[M013](../../../../milestones/M013/index.md) P04 is the only phase left in M013" sentence.

**Exit criteria.** Docs written, knowledge entries filed, index rebuilt, dual-write fired, CLAUDE.md status current. Gates 5, 6, 7 from T03 now pass. Full phase-suite green.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Linear chain. T02 depends on T01's emitter output shape. T03's merge-preservation + idempotency gates depend on T02's installer changes. T04's gate 5/6/7 unblocks require T03's phase-suite scaffold.

## Files Likely Touched

- `scripts/dispatch/adapters/runtime/claude-code.sh` (modify)
- `packaging/install/install-claude-code.sh` (modify)
- `scripts/util/settings-merge.sh` (create)
- `tests/fixtures/m025-p01/gsd-baseline/settings.json` (create)
- `tests/fixtures/m025-p01/expected-post-install.json` (create)
- `tests/fixtures/m025-p01/expected-post-uninstall.sha256` (create)
- `scripts/verify/m025-p01-hook-schema.sh` (create)
- `scripts/verify/m025-p01-merge-preservation.sh` (create)
- `scripts/verify/m025-p01-coexistence.sh` (create)
- `scripts/verify/m025-p01-uninstall-reversibility.sh` (create)
- `scripts/verify/m025-p01-idempotency.sh` (create)
- `scripts/verify/m025-p01-runtime-scope-guard.sh` (create)
- `scripts/verify/m025-p01-bash32-compat.sh` (create)
- `scripts/verify/m025-p01-docs.sh` (create)
- `scripts/verify/m025-p01-knowledge-entries.sh` (create)
- `scripts/verify/m025-p01-recent-changes.sh` (create)
- `scripts/verify/m025-p01-phase-suite.sh` (create)
- `references/installation.md` (modify)
- `references/hooks.md` (modify)
- `CHANGELOG.md` (modify)
- `knowledge/lessons/MEM0##.md` (create)
- `knowledge/patterns/MEM0##.md` (create)
- `KNOWLEDGE-INDEX.md` (modify — rebuild)
- `CLAUDE.md` (modify — Recent Changes region + Project Status + Forward Roadmap)
- `AGENTS.md` (modify — Recent Changes region)
