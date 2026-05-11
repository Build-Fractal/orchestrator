# Project Rename Plan: `spec-kit-orchestrator` → `orchestrator`

**Status**: Reference plan, evergreen. Consumed by M035 P01.5 (Namespace + Project Rename) when M035 enters spec-authoring.
**Captured**: 2026-04-30 during operator session immediately after PR #6 merge / PR #3 close.
**Companion**: Finding E + phase row P01.5 in `.orchestrator/proposals/M035-packaging-distribution.md`.

This document is the deterministic, non-AI runbook for executing the project rename. Every step is mechanical. Every command is reproducible. The plan is structured as a sequence of independently revertable commits, each scoped to one surface, each with its own verification gate.

The companion namespace rename (`speckit.orchestrator.*` → `orchestrator:<command>` cohort) co-ships with this plan because the two share the same audit pass and any partial rename of either is corrupting.

---

## 1. Why a runbook, not a global `sed`

The string `spec-kit-orchestrator` (and its variants) appears in many forms with mutually incompatible replacement rules:

- **Operational identifiers** — `Skill(speckit.orchestrator.plan-phase)` invocations in dispatched-agent prompts. These MUST be renamed atomically with the registered skill names; partial rename breaks dispatch silently.
- **Documentation prose** — "spec-kit orchestrator" / "Spec-Kit Orchestrator" / `spec-kit-orchestrator`. Different cases, different handling.
- **Hard-coded paths** — `~/Sites/spec-kit-orchestrator` baked into operator-environment scripts and shell-function recipes. Specific replacement rule.
- **Historical references** — `CHANGELOG.md` entries, archived milestone summaries (`.orchestrator/milestones/M0XX/M0XX-SUMMARY.md`), commit-message quotes embedded in docs. These MUST survive the rename to preserve audit-trail integrity.
- **External strings** — GitHub repo URL, npm package metadata, homebrew tap name. Resolved at the publishing surface, not in source.

A single global `sed` would silently miscategorize at least three of those surfaces. The runbook splits the work into one commit per surface so each is independently verifiable and revertable.

---

## 2. Open decisions — resolve BEFORE starting

The rename cannot start until these are decided. Record decisions in `.orchestrator/DECISIONS.md` with a `D0XX` ID before opening the rename branch.

| Decision | Options | Recommendation | Notes |
|---|---|---|---|
| **D-RN-1**: npm package name | `@orchestrator/cli` / `@build-fractal/orchestrator` / unscoped `orchestrator` (likely taken) / `orchestrator-cli` | Resolve at M035 P00 via `npm view <name>` collision check; default `@build-fractal/orchestrator` if collision | Determines repo basename + binary name. Bound to M035 Open Question 1. |
| **D-RN-2**: GitHub repo basename | Match npm name verbatim / use `orchestrator` regardless of npm scope | Match: keeps URL surface coherent | If npm scope is `@build-fractal/orchestrator`, repo stays `Build-Fractal/orchestrator` (npm scope is package metadata, not URL path). |
| **D-RN-3**: Command-cohort prefix | `orchestrator:<cmd>` (already in CLAUDE.md) / `orc:<cmd>` (terser) / `o:<cmd>` (terse-extreme) | `orchestrator:<cmd>` — already canonical in `CLAUDE.md` and `commands/*.md` | Per-line judgment in `commands/*.md` files where `speckit.orchestrator.*` and `orchestrator:*` already coexist. |
| **D-RN-4**: Homebrew tap | `build-fractal/orchestrator` / `build-fractal/tap` (multi-formula) | `build-fractal/orchestrator` (single-formula tap) | Defer until M035 P03 if formula authoring slips. |
| **D-RN-5**: Local clone path | `~/Sites/orchestrator` / `~/Sites/build-fractal-orchestrator` / `~/Code/orchestrator` | `~/Sites/orchestrator` — minimal disturbance | Operator-personal, low blast radius beyond local toolchain. |
| **D-RN-6**: Memory-dir migration | Migrate `~/.claude/projects/-Users-<user>-Sites-spec-kit-orchestrator/` / accept memory loss | Migrate (see § 9) | Renaming the path triggers a new Claude project key; without migration, accumulated memory entries become orphaned. |
| **D-RN-7**: Pre-rename version-tag preservation | Tag `v0.9.X-final-spec-kit-name` immediately before rename / no special tag | Tag — preserves a clean cutover marker for future archaeology | One-line `git tag` operation; trivial. |

---

## 3. Canonical mapping table

This is the source of truth for all replacements. Categorize every match in the inventory (§ 4) against this table.

| # | Surface | Old form | New form | Replacement scope |
|---|---|---|---|---|
| C1 | Lowercase hyphenated path/repo basename | `spec-kit-orchestrator` | `orchestrator` | `git ls-files`-tracked content + filenames |
| C2 | Title-case prose | `Spec-Kit Orchestrator` | `Orchestrator` | `*.md` only |
| C3 | Lowercase spaced prose | `spec-kit orchestrator` / `spec kit orchestrator` | `orchestrator` | `*.md` only |
| C4 | Spec-kit single-word reference | `spec-kit` (when standalone, referring to this project) | `orchestrator` | Per-line judgment — many `spec-kit` references are about the **upstream** spec-kit framework, which the orchestrator originally migrated FROM. Those legitimate references stay. |
| C5 | Command-cohort namespace | `speckit.orchestrator.<cmd>` | `orchestrator:<cmd>` | Operational identifiers only — historical/migration documentation in `commands/migrate.md` AD-15 + `templates/instruction-schema.md` legacy-schema docs reframed as legacy references, not deleted |
| C6 | Local path string | `~/Sites/spec-kit-orchestrator` / `/Sites/spec-kit-orchestrator` | `~/Sites/orchestrator` / `/Sites/orchestrator` | Operator-environment scripts + shell-function recipes in `references/installation.md` |
| C7 | npm scope token | (none yet) | resolved per D-RN-1 | `package.json` (when authored in M035 P02) + curl-pipe-bash install URLs |
| C8 | GitHub remote URL | `Build-Fractal/spec-kit-orchestrator` | `Build-Fractal/orchestrator` (per D-RN-2) | Remote-only (handled in § 9), no in-repo string changes — GitHub provides automatic redirect |
| C9 | Spec directory basename | `specs/001-speckit-orchestrator/` | `specs/001-orchestrator/` | `git mv` + content references to that path |
| C10 | Project key in Claude memory | `-Users-<user>-Sites-spec-kit-orchestrator` | `-Users-<user>-Sites-orchestrator` | `~/.claude/projects/` directory rename (per D-RN-6) |

**Critical:** C4 is where the most damage happens. Run grep with eyeballs, not sed. If you can't tell from context whether a `spec-kit` reference is about the upstream framework or about this orchestrator project, leave it and flag for review.

---

## 4. Pre-rename inventory protocol

Freeze a snapshot of every match BEFORE editing anything. Iterate from the saved file, not from grep output. This makes progress measurable and bisectable.

```bash
# Inventory: in-tree string matches
git grep -nIiE 'spec[ _-]?kit[ _-]?orchestrator|speckit\.orchestrator|spec-kit' \
  > /tmp/rename-inventory.txt

# Inventory: filenames containing the string
git ls-files | grep -iE 'spec[ _-]?kit' > /tmp/rename-filenames.txt

# Inventory: count by file (audit dashboard)
awk -F: '{print $1}' /tmp/rename-inventory.txt | sort | uniq -c | sort -rn \
  > /tmp/rename-by-file.txt
```

Read `/tmp/rename-by-file.txt`. The top-N files are where most of the work concentrates. Read each line in `/tmp/rename-inventory.txt`. **Annotate each line in a new file `/tmp/rename-classified.txt`** with one of these tags:

- `[C1]` through `[C10]` — straightforward rule application per § 3
- `[HIST]` — historical reference, must survive (CHANGELOG, archived milestone summaries, commit-message quotes)
- `[UPSTREAM]` — refers to upstream spec-kit framework, must survive
- `[REVIEW]` — context unclear; needs human read of surrounding lines

The `[REVIEW]` lines are the long-tail risk — they're where global `sed` would silently corrupt. Resolve every `[REVIEW]` before starting Phase 5.

---

## 5. Mechanical execution — one commit per surface

Branch: `rename/spec-kit-orchestrator-to-orchestrator`. Each commit is one surface. Each commit has its own verification step. If any verification fails, that commit is revertable in isolation.

### Commit setup

```bash
git checkout -b rename/spec-kit-orchestrator-to-orchestrator

# Pre-rename version tag (per D-RN-7)
git tag v0.9.X-final-spec-kit-name
git push origin v0.9.X-final-spec-kit-name
```

### Commit 1 — Filenames (`git mv` only)

```bash
# Concrete moves identified by the inventory
git mv specs/001-speckit-orchestrator specs/001-orchestrator

# Verification: tree clean, no stray files left behind
git status
git ls-files | grep -iE 'spec[ _-]?kit' > /tmp/rename-filenames-after.txt
diff /tmp/rename-filenames.txt /tmp/rename-filenames-after.txt
```

Commit message shape: `rename(filenames): spec-kit-orchestrator -> orchestrator (specs/ basename)`.

### Commit 2 — Operator-environment paths (C6)

The operator's local clone is at `~/Sites/spec-kit-orchestrator`. Several scripts and recipes hard-code that path:

```bash
# BSD sed (macOS) — note the empty '' after -i
git ls-files -z | xargs -0 sed -i '' \
  -e 's|~/Sites/spec-kit-orchestrator|~/Sites/orchestrator|g' \
  -e 's|/Sites/spec-kit-orchestrator|/Sites/orchestrator|g'

# Verification: zero residual matches for the path pattern
git grep -nE '~?/Sites/spec-kit-orchestrator'
```

Expect zero output. Commit: `rename(paths): ~/Sites/spec-kit-orchestrator -> ~/Sites/orchestrator`.

> **GNU sed** uses `sed -i 's/.../.../'` (no empty `''`). The runbook assumes BSD/macOS; adjust for Linux CI.

### Commit 3 — Lowercase hyphenated string (C1) in `*.md` / `*.yml` / `*.yaml`

```bash
git ls-files -z '*.md' '*.yml' '*.yaml' | xargs -0 sed -i '' \
  's/spec-kit-orchestrator/orchestrator/g'

# Verification: the only remaining matches are intentional
git grep -nE 'spec-kit-orchestrator' | tee /tmp/rename-c1-residue.txt
```

Manual review: every line in `/tmp/rename-c1-residue.txt` should be in CHANGELOG, archived milestone summary, or git URL/identifier (handled in Commit 8). If anything else appears, that's a `[REVIEW]` you missed in § 4.

Commit: `rename(prose): spec-kit-orchestrator -> orchestrator (lowercase hyphenated)`.

### Commit 4 — Title-case + spaced prose (C2 + C3)

```bash
git ls-files -z '*.md' | xargs -0 sed -i '' \
  -e 's/Spec-Kit Orchestrator/Orchestrator/g' \
  -e 's/spec-kit orchestrator/orchestrator/g' \
  -e 's/spec kit orchestrator/orchestrator/g'

# Verification: review remaining title-case matches
git grep -nE 'Spec-Kit|SpecKit|Spec Kit'
```

Title-case "Spec-Kit" (without "Orchestrator") may legitimately reference upstream spec-kit. Per-line judgment.

Commit: `rename(prose): title-case + spaced "Spec-Kit Orchestrator" -> "Orchestrator"`.

### Commit 5 — Namespace cohort (C5) — the hard one

This is the M035 P01.5 work. **Do not `sed` this commit.** 71 occurrences across 15 files; some are operational identifiers (rename), some are historical/migration docs (preserve as legacy reference).

Process:
1. Open `/tmp/rename-classified.txt`. Filter to `[C5]` and `[REVIEW]` entries.
2. For each file (15 total), open in editor. Walk top-to-bottom.
3. For each `speckit.orchestrator.*` occurrence:
   - **Operational** (e.g. `Skill(speckit.orchestrator.plan-phase)` invocation, `Run \`speckit.orchestrator.status\`` in user-facing instructions): replace with `orchestrator:<cmd>` shape.
   - **Historical/migration** (e.g. `commands/migrate.md` AD-15 paragraph documenting the deferred rename, `templates/instruction-schema.md` legacy schema): rewrite the surrounding sentence to frame as legacy. Example:
     - Before: *"This command is registered in `extension.yml` as `speckit.orchestrator.migrate`."*
     - After: *"This command was historically registered as `speckit.orchestrator.migrate` (pre-M035 cohort name); it is now `orchestrator:migrate`."*
4. After edits, sweep for residual:
   ```bash
   git grep -nE 'speckit\.orchestrator'
   ```
5. Every remaining hit must be in an `[HIST]`-class file (CHANGELOG, archived milestone summary). If any appear in a `commands/*.md` or `templates/*.md` operational surface, fix them.

Commit: `rename(namespace): speckit.orchestrator.<cmd> -> orchestrator:<cmd> cohort (M035 P01.5)`.

### Commit 6 — Spec directory content references (C9)

After Commit 1's `git mv`, content references to `specs/001-speckit-orchestrator/` need updating:

```bash
git ls-files -z | xargs -0 sed -i '' \
  's|specs/001-speckit-orchestrator|specs/001-orchestrator|g'

# Verification
git grep -nE 'specs/001-speckit-orchestrator'
```

Expect zero. Commit: `rename(spec-dir): specs/001-speckit-orchestrator -> specs/001-orchestrator`.

### Commit 7 — Package metadata + manifest names (C7 prep)

Touch `packaging/`, any pre-existing `package.json`, `manifest.yml`, `homebrew-formula.rb`, etc. Apply C1–C5 rules. The npm scope decision (D-RN-1) lands here as a string change, even though the actual `npm publish` is M035 P02.

```bash
# If package.json exists at this point
sed -i '' 's/"name": "spec-kit-orchestrator"/"name": "<resolved per D-RN-1>"/' package.json

# Manifest files
git ls-files -z 'packaging/**/*.yml' 'packaging/**/*.yaml' \
  | xargs -0 sed -i '' 's/spec-kit-orchestrator/orchestrator/g'
```

Commit: `rename(packaging): manifest + package metadata`.

### Commit 8 — README + top-level docs

`README.md`, `CHANGELOG.md` (header line only — entries stay), `CLAUDE.md`, top of `references/README.md`. These are the operator-facing surfaces; treat them as a separate commit so the README diff is reviewable in isolation.

```bash
# Manual edit pass — open each file, walk top-to-bottom
# CHANGELOG.md: only the header / current-version section; archived
# version entries STAY (they document history).
```

Commit: `rename(readme): top-level docs renamed; CHANGELOG history preserved`.

### Commit 9 — Apply to remaining matches

By this point, `git grep -i 'spec.\?kit'` should return only:
- `[HIST]` — archived milestone summaries, CHANGELOG entries
- `[UPSTREAM]` — references to upstream spec-kit framework

Sweep for any stragglers and resolve. If any residual `spec-kit-orchestrator` matches don't fit a category, flag them and discuss before committing.

Commit: `rename(stragglers): final residue cleanup` (or skip if empty).

---

## 6. Allowlist for historical references

Some matches MUST survive. Build `.rename-allowlist.txt` at repo root before running the final verification (§ 7):

```text
# Historical references that must survive the rename.
# Format: path:linenumber:reason
# Used by `scripts/verify/rename-residue-check.sh`.

CHANGELOG.md:*:version-history-entries-pre-rename
.orchestrator/milestones/M0*/M0*-SUMMARY.md:*:archived-milestone-summary
.orchestrator/milestones/M0*/M0*-BODY.txt:*:archived-milestone-body
.orchestrator/proposals/papercut-sweep-pre-M030.md:*:operator-session-history-document
references/RENAME-PLAN.md:*:this-document-self-references-old-name
docs/migrating-from-spec-kit.md:*:migration-doc-references-upstream-spec-kit
commands/migrate.md:*:legacy-cohort-name-documentation
templates/instruction-schema.md:*:legacy-schema-documentation
.orchestrator/DECISIONS.md:*:historical-decision-records
```

The allowlist file IS the verification contract. Final verification runs:

```bash
git grep -niE 'spec[ _-]?kit[ _-]?orchestrator|speckit\.orchestrator' \
  | grep -vFf .rename-allowlist.txt \
  > /tmp/rename-residue.txt

[ -s /tmp/rename-residue.txt ] && echo "FAIL: unexpected residue" || echo "PASS"
```

Empty residue file = pass. Anything in it = a `[REVIEW]` was missed.

---

## 7. Verification gates

Before the rename PR opens, all four gates must pass.

### Gate 1: Inventory diff

```bash
git grep -nIiE 'spec[ _-]?kit[ _-]?orchestrator|speckit\.orchestrator|spec-kit' \
  > /tmp/rename-inventory-after.txt
diff /tmp/rename-inventory.txt /tmp/rename-inventory-after.txt > /tmp/rename-diff.txt
wc -l /tmp/rename-diff.txt
```

Confirms quantitative progress. Read the diff — every removed line should be intentional.

### Gate 2: Allowlist residue check

Per § 6. Empty residue file.

### Gate 3: Test suite

```bash
bash tests/run-all.sh  # or whichever entry point; check tests/ structure
```

Specifically watch for:
- `tests/fixtures/m021-prompt-corpus.txt` — does any corpus entry reference the old namespace? If so, they're empirical fixtures that would need updating in lockstep.
- `scripts/verify/m028/install-roundtrip.sh` — pinned SHA may invalidate after the rename touches install scripts; recompute and update.
- `tests/run-prompt-corpus-replay.sh` — should still emit `WOULD_PROMPT=0/27`.

### Gate 4: Install round-trip

```bash
bash packaging/install/install-claude-code.sh \
  --project-dir tests/fixtures/downstream-project \
  --dry-run
```

Confirms the installer still produces a valid downstream layout. Then:

```bash
bash scripts/verify/m028/install-roundtrip.sh
```

Confirms idempotency + reversibility unchanged.

---

## 8. PR + merge

```bash
gh pr create --title "rename: spec-kit-orchestrator -> orchestrator (M035 P01.5)" \
  --body "$(cat <<'EOF'
## Summary

Mechanical rename of the project from `spec-kit-orchestrator` to `orchestrator` per
M035 P01.5 (Namespace + Project Rename). Companion namespace rename
(`speckit.orchestrator.*` -> `orchestrator:<cmd>` cohort) co-shipped.

Decisions: see `.orchestrator/DECISIONS.md` D-RN-1 through D-RN-7.
Methodology: `references/RENAME-PLAN.md`.

## Verification

- [x] Gate 1 — inventory diff (see /tmp/rename-diff.txt)
- [x] Gate 2 — allowlist residue check (empty)
- [x] Gate 3 — test suite passing
- [x] Gate 4 — install round-trip clean

## Surfaces touched

One commit per surface — see commit log for granular diff. PR is reviewable
commit-by-commit; revertable per-commit if any surface fails post-merge audit.

EOF
)"
```

> **Commit message constraint** (per CLAUDE.md): use `git commit -F <file>` for multi-line messages. Inline `$(cat <<EOF...)` HEREDOC is rejected by the active AP-008 shape-guard.

Merge with `--merge` (not `--squash`) to preserve the per-surface commit granularity, mirroring the paper-cut sweep precedent.

---

## 9. External surface migration (do AFTER merge)

These steps modify the GitHub remote and operator's local environment. Order matters; each step depends on the previous.

### Step 9.1 — Rename the GitHub repo

```bash
gh repo rename orchestrator --repo Build-Fractal/spec-kit-orchestrator
```

GitHub creates an automatic redirect from `Build-Fractal/spec-kit-orchestrator` to `Build-Fractal/orchestrator`. Existing clones, links, and CI configurations continue to work. **But:** proactively update any CI configs in *other* repos (lakeledger, pbj-central, bbt-companion, etc.) that hard-code the old URL.

### Step 9.2 — Rename the local clone + update remote

```bash
cd ~/Sites
mv spec-kit-orchestrator orchestrator
cd orchestrator
git remote set-url origin git@github.com:Build-Fractal/orchestrator.git
git remote -v  # verify both fetch + push URLs updated
git pull --ff-only  # confirm remote reachable
```

### Step 9.3 — Update operator shell-function recipes

The pre-M035 `~/.zshrc` (or equivalent) likely contains:

```bash
orchestrator-update() {
  ( cd "$HOME/Sites/spec-kit-orchestrator" && git pull --ff-only ) || return
  bash "$HOME/Sites/spec-kit-orchestrator/packaging/install/install-claude-code.sh" --force
}
```

Update to:

```bash
orchestrator-update() {
  ( cd "$HOME/Sites/orchestrator" && git pull --ff-only ) || return
  bash "$HOME/Sites/orchestrator/packaging/install/install-claude-code.sh" --force
}
```

If the function is documented in `references/installation.md`, the doc-side update was handled in Commit 8.

### Step 9.4 — Migrate the Claude memory directory (per D-RN-6)

```bash
mv ~/.claude/projects/-Users-<user>-Sites-spec-kit-orchestrator \
   ~/.claude/projects/-Users-<user>-Sites-orchestrator
```

Inside the migrated directory, `MEMORY.md` and individual memory files reference the project by its OLD path encoding internally? Sweep them:

```bash
cd ~/.claude/projects/-Users-<user>-Sites-orchestrator
git grep -niE 'spec-kit-orchestrator' . 2>/dev/null  # if it's a git repo
# or for non-git:
grep -rniE 'spec-kit-orchestrator' . 2>/dev/null
```

Hand-edit any matches. The memory entries are operator-personal; no test gate.

### Step 9.5 — Update IDE / editor workspace files

VS Code workspace files, JetBrains project files, etc. that hard-code the old path. Search:

```bash
cd ~
grep -rniE '/Sites/spec-kit-orchestrator' \
  ~/.config ~/Library/Application\ Support 2>/dev/null \
  | head -50
```

Hand-edit each. Operator-personal; low blast radius.

### Step 9.6 — Notify other consumer projects

Repos that consume the orchestrator (lakeledger, pbj-central, bbt-companion) carry copies of the runtime under their own `.orchestrator/` (per M035 Finding A's pinned-snapshot model). They are unaffected by the rename until the next install. Document this in the rename PR description so consumer-project maintainers know to:

1. Pull latest orchestrator from the renamed remote.
2. Re-run `bash packaging/install/install-claude-code.sh --force` against their consumer project.

The `--force` re-install picks up the renamed identifiers. Until they re-install, the consumer project keeps the legacy names internally — non-breaking, but staleness will surface in `orchestrator:status` once M035 P01's drift detection is live.

---

## 10. Rollback procedure

If post-merge audit surfaces a regression, surfaces are revertable per-commit because the rename was authored as one-commit-per-surface.

### Partial rollback (one surface broken)

```bash
git revert <commit-sha-of-broken-surface>
git push
```

The remaining surfaces stay renamed. The broken surface returns to old name; document in CHANGELOG.

### Full rollback (rename withdrawn)

```bash
# Revert the merge commit (creates a new commit that inverts the merge)
git revert -m 1 <merge-commit-sha>
git push

# Rename the GitHub repo back
gh repo rename spec-kit-orchestrator --repo Build-Fractal/orchestrator

# Local clone
cd ~/Sites
mv orchestrator spec-kit-orchestrator
cd spec-kit-orchestrator
git remote set-url origin git@github.com:Build-Fractal/spec-kit-orchestrator.git
```

GitHub redirects survive both directions. The pre-rename version tag (`v0.9.X-final-spec-kit-name` per D-RN-7) is the cutover marker if archaeology is needed later.

---

## 11. Special considerations

### 11.1 BSD vs GNU `sed`

This runbook assumes macOS BSD `sed` (`sed -i ''` with empty backup-extension argument). Linux/CI uses GNU `sed` (`sed -i` with no `''`). If the rename is executed in CI:

```bash
# Cross-platform-portable form
if sed --version 2>/dev/null | grep -q GNU; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi
sed "${SED_INPLACE[@]}" 's/old/new/g' file.md
```

### 11.2 AP-009 hook compliance

The `pre-bash-shape-guard.sh` hook (active in this repo) rejects compound chains > 2 stages. Multi-pipeline `sed | xargs | grep` invocations may trigger AP-009. Two safe forms:

- **Single-stage chains** — break compound pipelines into intermediate files.
- **Helper script** — wrap the rename pass in `scripts/util/rename-pass.sh` (one-off helper, gitignored or committed). Helper-function bodies are NOT scanned by AP-009 in production (per the M028/P02/T05 helper-function carve-out).

### 11.3 `xargs -0` portability

BSD `xargs` and GNU `xargs` differ in `-0` flag handling. Both support `-0` in modern versions. If rename is automated in CI on minimal containers, verify `xargs --version` first.

### 11.4 Pre-existing test fixtures

`tests/fixtures/downstream-project/.claude/settings.json` is a **literal fixture** — its contents are intentionally byte-frozen as a CON-10 contract anchor. If the rename touches the fixture file, downstream-fixture-replay tests will FAIL until the fixture is regenerated.

Procedure for fixture regeneration: re-run installer against fresh `mktemp -d` HOME, copy resulting `.claude/settings.json` into `tests/fixtures/downstream-project/`, replace literal HOME path with the literal placeholder bytes the verifier expects (see `scripts/verify/m028/finding-A-verifier.sh` for the placeholder convention).

### 11.5 Constitution amendment

The Standalone Constitution Amendment (per CLAUDE.md "Forward Roadmap" section) is independent of this rename. If it merges before the rename, the amendment introduces Principle XVI (Distribution Surface Integrity) which formalizes what M035 P01.5 verifies: at-launch the package name + repo name + namespace + binary name must align. The rename plan satisfies Principle XVI by construction.

### 11.6 Worktree state

If active worktrees exist (`.worktrees/M0XX/`) at rename time, the rename touches files inside them. Either:
- Land all in-flight worktree work first, OR
- Pause active worktrees and execute the rename on a quiescent tree.

Recommended: rename during the quiet period between M035 P01 close and P02 open (no active milestone work).

---

## 12. Post-rename hygiene

After the rename merges + external surfaces migrate:

1. **Update `CLAUDE.md`** to reflect the new project identity throughout. The current `CLAUDE.md:1` says "spec-kit-orchestrator" — that gets renamed in Commit 8 above.
2. **Append a `DECISIONS.md` entry** (D-RN-FINAL or whatever ID) recording the rename event, decision sequence, and any deviations from this plan.
3. **Refresh `.orchestrator/KNOWLEDGE.md`** with one milestone-tagged entry recording the rename pattern: "Mechanical project rename via per-surface commit decomposition + allowlist verification — reusable for future cohort renames."
4. **Update `orchestrator-update` shell function** in operator's `~/.zshrc` (per § 9.3).
5. **Audit `references/RUNTIME-ASSUMPTIONS.md`** for any rows referencing the old path; rewrite.
6. **Tag the post-rename version** (`v0.9.X-orchestrator-rename`) as a paired bookend to the pre-rename tag from D-RN-7.

---

## 13. Cross-references

- `.orchestrator/proposals/M035-packaging-distribution.md` — Finding E + phase row P01.5 (the milestone this plan serves)
- `.orchestrator/proposals/papercut-sweep-pre-M030.md` — operator session 2026-04-30 surfacing the rename ask
- `commands/migrate.md` — AD-15 paragraph documenting the namespace deferral (canonical "legacy reference" form after Commit 5)
- `references/installation.md` — `## Upgrading` section + shell-function recipe (touched in Commit 2)
- `tests/fixtures/downstream-project/` — CON-10 contract anchor; regeneration procedure in § 11.4
- `scripts/verify/m028/install-roundtrip.sh` — pinned-SHA gate; SHA recomputation needed if the rename touches install scripts

---

## 14. Source material

- 2026-04-30 operator session: roadmap-fit assessment after PR #6 merge / PR #3 close; rename ask surfaced as separate-but-related concern to the speckit.orchestrator.* namespace purge.
- PR #3 conversus blind-arbiter ruling (RISK-02 / RISK-03) — original surface for the namespace purge component.
- M035 brief Open Question 1 — bound the rename to npm scope decision.
- CLAUDE.md "Forward Roadmap" — establishes M035 as last pre-launch milestone, where this rename naturally lives.
