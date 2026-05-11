# Friendly-tester recruitment kit — 30 minutes, one-page brief

Thanks for helping. This kit is for a **single 30-minute walkthrough** of a developer tool called orchestrator. You're being asked because you have **not** seen this repo before — that's the entire point. Maintainers can't see the friction that hits new users.

You don't need to install anything. You don't need to know what orchestrator does. Read this page once, then run the four commands below in order.

## Are you eligible?

You're eligible if **all three** are true:

- [ ] You have not committed code, reviewed a PR, or authored a proposal in this repo.
- [ ] You have not read any spec under `specs/030-project-onboarding-experience/`.
- [ ] Nobody on the team has walked you through the four "init branches" (greenfield-empty / greenfield-with-materials / existing-codebase / migrating).

If any of those is false, you're too close — recruit someone else. (You can still help observe; your notes just won't count toward the milestone gate.)

Good fits: a friend at another company who codes, a designer who ships code, a technical writer, a PM with a 5–15-year dev background, a teammate from a sibling team. Avoid: anyone on this project's regular reviewer rotation.

## What you'll do

Run these four commands in order from inside a checkout of the orchestrator repo (the maintainer who handed you this kit has it cloned at a path they'll tell you — replace `<repo>` with that path).

```bash
cd <repo>

# Branch 1 of 4: greenfield-empty
mkdir /tmp/m033-tester-ge
bash scripts/lifecycle/start.sh --project-dir /tmp/m033-tester-ge

# Branch 2 of 4: greenfield-with-materials
cp -R tests/fixtures/m033-pbj-materials-fixture /tmp/m033-tester-gwm
bash scripts/lifecycle/start.sh --project-dir /tmp/m033-tester-gwm

# Branch 3 of 4: existing-codebase
# Point at a real codebase you have on disk — your own side project,
# a forked OSS repo, a recent client repo. Anything with .git/ and
# either a src/ directory or 10+ source files at the root works.
bash scripts/lifecycle/start.sh --project-dir ~/path/to/any/repo/you/have

# Branch 4 of 4: migrating
mkdir -p /tmp/m033-tester-mig/.specify
bash scripts/lifecycle/start.sh --project-dir /tmp/m033-tester-mig
```

Each command should print one of `branch: greenfield-empty`, `branch: greenfield-with-materials`, `branch: existing-codebase`, or `branch: migrating` followed by some kind of next-step message.

**Budget**: ~7 minutes per branch. Total ~30 minutes including notes.

## What to watch for

After each command, write down anything that fits one of these three buckets:

- **You got stuck.** You couldn't tell what to do next without asking someone or reading source code.
- **You re-read.** You read a line of output more than once because the first read didn't land.
- **You bounced.** You wanted to close the terminal, or you asked yourself "is this for me?"

For each observation, mark it either:

- **blocker** — you literally could not proceed without external help.
- **warning** — annoying but recoverable; you got past it on your own.

There is no wrong answer. The maintainers don't want a polite report — they want the moments where the welcome flow under-delivered.

## How to file your report

The maintainer will hand you (or open for you) the file `tests/m033-acceptance/friendly-tester-pass/report-template.md`. Copy it to:

```
tests/m033-acceptance/friendly-tester-pass/reports/<today's date>.md
```

Fill in:

1. The **frontmatter scalars** at the top: `report_date`, `friction_blockers` (count of blocker-tagged observations across all four branches), `friction_warnings` (count of warning-tagged observations), `eligible_testers` (1 if you alone, more if multiple of you walked together).
2. The **tester attestations list** — add a `- tester_id: "T1"` entry with `not_familiar_with_orchestrator: "yes"`. If multiple testers, add T2, T3, etc.
3. The **four "Branch:" sections** — list your blockers and warnings in their respective subsections. Use `(none)` if you found nothing in a category.
4. The **Aggregate** section at the bottom — same counters as the frontmatter, for human readability.

Examples of well-shaped passing and failing reports are at `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md` and `report-fail.md`.

## What happens after

The maintainer runs:

```bash
bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh \
  tests/m033-acceptance/friendly-tester-pass/reports/<today>.md
```

That script exits 0 if `friction_blockers: 0` AND you're listed as an eligible tester. Any blockers you found go into the project's queue as paper-cuts to fix; warnings get triaged as deferred follow-ups.

Done. Thank you.
