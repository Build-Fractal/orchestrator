# M035 P01.5 -- Operator Off-Tree Runbook

The in-tree rename (T01..T07) ships via the rename branch. After the
branch merges to main, three off-tree steps complete the project
rename. They are NOT autonomous-executable -- the auto-loop's lock is
held only until T08 closes; the steps below run AFTER that close.

## Step 1 -- GitHub remote rename (D-RN-2)

- In the GitHub web UI, navigate to
  https://github.com/Build-Fractal/spec-kit-orchestrator/settings.
- Rename the repository to `orchestrator`. The new URL becomes
  `https://github.com/Build-Fractal/orchestrator`.
- GitHub auto-redirects the old URL; existing clones continue to
  fetch/push correctly via the redirect.
- **Reversibility**: rename back via the same Settings page.
- **Recommended timing**: after the rename branch merges to main.

## Step 2 -- Local working-dir rename (D-RN-5)

```bash
cd ~/Sites
mv spec-kit-orchestrator orchestrator
cd orchestrator
git remote set-url origin git@github.com:Build-Fractal/orchestrator.git
git remote -v
git pull --ff-only
```

- **Reversibility**: `mv orchestrator spec-kit-orchestrator` and
  re-run `git remote set-url origin
  git@github.com:Build-Fractal/spec-kit-orchestrator.git`.
- **Recommended timing**: immediately after Step 1.

## Step 3 -- Claude memory project-key migration (D-RN-6)

```bash
mv ~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator \
   ~/.claude/projects/-Users-brettkellgren-Sites-orchestrator
```

- Without this rename, Claude memory entries become orphaned because
  Claude's project key is derived from the working-dir path.
- **Reversibility**: `mv` the directory back to its old basename.
- **Recommended timing**: after Step 2 (so the new working-dir path
  resolves before Claude looks it up).

## Verification After Off-Tree Steps

- `git remote -v` shows
  `origin git@github.com:Build-Fractal/orchestrator.git`.
- `ls ~/.claude/projects/` lists
  `-Users-brettkellgren-Sites-orchestrator` and NOT the old key.
- Re-opening the Claude session in the renamed working-dir resolves
  the new project key.

## Pre-Rename Tag (D-RN-7) Reversibility

The pre-rename tag `v0.9.X-final-spec-kit-name` is in local refs (T01
step 5). To remove it:

```bash
git tag -d v0.9.X-final-spec-kit-name
```

Or to publish to remote:

```bash
git push origin v0.9.X-final-spec-kit-name
```

The tag is operator-personal until pushed; it does not affect any
automated pipeline.
